import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pet_sns/store.dart';
import 'package:pet_sns/supabase_auth_service.dart';
import 'package:pet_sns/supabase_pet_repository.dart';
import 'package:pet_sns/supabase_memory_repository.dart';
import 'package:pet_sns/supabase_photo_repository.dart';

const pixel =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Wl6S8sAAAAASUVORK5CYII=';

class FaultTransport extends http.BaseClient {
  final inner = http.Client();
  int uploads = 0;
  int? failUpload;
  bool failRemove = false;
  bool loseCommit = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;
    if (path.contains('/object/memory-photos/') && request.method == 'POST') {
      uploads++;
      if (uploads == failUpload) {
        return http.StreamedResponse(
          Stream.value(utf8.encode('{"message":"simulated interruption"}')),
          503,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }
    }
    if (path.endsWith('/object/memory-photos') &&
        request.method == 'DELETE' &&
        failRemove) {
      return http.StreamedResponse(
        Stream.value(
          utf8.encode('{"message":"simulated cleanup interruption"}'),
        ),
        503,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    }
    final response = await inner.send(request);
    if (path.endsWith('/finish_memory_photos') &&
        loseCommit &&
        response.statusCode < 300) {
      loseCommit = false;
      await response.stream.drain<void>();
      throw http.ClientException('simulated lost completion response');
    }
    return response;
  }

  @override
  void close() => inner.close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'real private photos, Storage isolation, Day 0, cleanup and pet FK',
    () async {
      final credentials =
          jsonDecode(File('config/supabase.test.local.json').readAsStringSync())
              as Map<String, dynamic>;
      final overrides = HttpOverrides.current;
      HttpOverrides.global = null;
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final local = PetStore(prefs);
      await local.load();
      await local.testLogin();
      local.dispose();
      final before = prefs.getString(PetStore.key);
      final clients = <SupabaseClient>[];
      final auths = <SupabaseAuthService>[];
      final stores = <PetStore>[];
      final createdPets = <String>[];
      final createdProfiles = <String>[];
      var assertions = 0;
      void check(bool value, String label) {
        expect(value, isTrue, reason: label);
        assertions++;
      }

      Future<void> denied(Future<dynamic> call, String label) async {
        await expectLater(
          call,
          throwsA(anyOf(isA<PostgrestException>(), isA<StorageException>())),
          reason: label,
        );
        assertions++;
      }

      final faults = FaultTransport();
      SupabaseClient client({http.Client? transport}) {
        final c = SupabaseClient(
          const String.fromEnvironment('SUPABASE_URL'),
          const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: transport,
        );
        clients.add(c);
        return c;
      }

      Future<PetStore> start(SupabaseClient c, String suffix) async {
        await c.auth.signInWithPassword(
          email: credentials['PET_SNS_TEST_EMAIL_$suffix'],
          password: credentials['PET_SNS_TEST_PASSWORD_$suffix'],
        );
        final owner = c.auth.currentUser!.id;
        if (await c
                .from('profiles')
                .select('id')
                .eq('id', owner)
                .maybeSingle() ==
            null) {
          createdProfiles.add(owner);
        }
        final auth = SupabaseAuthService(c);
        auths.add(auth);
        await auth.restore();
        final s = PetStore(
          prefs,
          auth: auth,
          petRepository: SupabasePetRepository(c),
          memoryRepository: SupabaseMemoryRepository(c),
          photoRepository: SupabasePhotoRepository(c),
        );
        stores.add(s);
        await s.load();
        return s;
      }

      final a = client(), b = client(), anon = client();
      try {
        final sa = await start(a, 'A'), sb = await start(b, 'B');
        check(
          sa.rows('pets').isEmpty &&
              sb.rows('pets').isEmpty &&
              (await a.from('memory_photos').select('id')).isEmpty,
          'dedicated fixtures must start empty',
        );
        await sa.saveOwned('pets', {'name': 'photo fixture A', 'breed': ''});
        final pet = sa.rows('pets').single['id'] as String;
        createdPets.add(pet);
        await sb.saveOwned('pets', {'name': 'photo fixture B', 'breed': ''});
        final petB = sb.rows('pets').single['id'] as String;
        createdPets.add(petB);
        await sa.setMemoryOrigin('firstPhoto', DateTime(2000), petId: pet);
        final probe = await a
            .from('memory_photos')
            .insert({'pet_id': pet, 'record_date': '2000-01-01'})
            .select()
            .single();
        await a.storage
            .from(SupabasePhotoRepository.bucket)
            .uploadBinary(
              probe['object_path'],
              base64Decode(pixel),
              fileOptions: const FileOptions(
                contentType: 'image/png',
                upsert: false,
              ),
            );
        await a.rpc(
          'finish_memory_photos',
          params: {
            'p_ids': [probe['id']],
          },
        );
        check(
          (await a
                  .from('memory_photos')
                  .select('state')
                  .eq('id', probe['id'])
                  .single())['state'] ==
              'ready',
          'direct reservation-upload-completion works',
        );
        await sa.photoRepository!.delete(sa.user!, probe['id']);
        final faulty = await start(client(transport: faults), 'A');
        faults.failUpload = 2;
        faults.failRemove = true;
        await expectLater(
          faulty.saveMemoryPhotos('1999-01-01', [
            'data:image/png;base64,$pixel',
            'data:image/png;base64,$pixel',
          ], petId: pet),
          throwsException,
        );
        assertions++;
        check(
          faulty.rows('memories').isEmpty &&
              faulty.photoCleanupPending &&
              (await a.from('memory_photos').select()).every(
                (p) => p['state'] == 'deleting',
              ),
          'real failed batch hides all rows and retains recoverable cleanup',
        );
        faults.failRemove = false;
        await faulty.retryPhotoCleanup();
        check(
          (await a.from('memory_photos').select()).isEmpty &&
              (await a.storage
                      .from(SupabasePhotoRepository.bucket)
                      .list(path: sa.user!))
                  .isEmpty,
          'real retry removes uploaded file and all batch reservations',
        );
        faults.failUpload = null;
        await faulty.saveMemoryPhotos('1999-01-01', [
          'data:image/png;base64,$pixel',
        ], petId: pet);
        final original = faulty.rows('memories').single;
        faults.failUpload = faults.uploads + 1;
        await expectLater(
          faulty.saveMemoryPhotos(
            '1998-01-01',
            ['data:image/png;base64,$pixel'],
            petId: pet,
            existingId: original['id'],
          ),
          throwsException,
        );
        assertions++;
        check(
          faulty.rows('memories').single['id'] == original['id'] &&
              (await faulty.photoRepository!.download(
                faulty.user!,
                original['photo'],
              )).isNotEmpty,
          'real replacement interruption preserves original file',
        );
        faults.failUpload = null;
        faults.loseCommit = true;
        await faulty.saveMemoryPhotos(
          '1998-01-01',
          ['data:image/png;base64,$pixel'],
          petId: pet,
          existingId: original['id'],
        );
        check(
          faulty.rows('memories').single['id'] != original['id'] &&
              (await a.from('memory_photos').select()).length == 1,
          'lost real commit response keeps exactly one completed replacement',
        );
        await faulty.deleteOwned(
          'memories',
          faulty.rows('memories').single['id'],
        );
        await sa.setMemoryOrigin('firstPhoto', DateTime(2000), petId: pet);
        final stale = await start(client(), 'A');
        await sa.saveMemoryPhotos('1999-01-01', [
          'data:image/png;base64,$pixel',
          'data:image/png;base64,$pixel',
        ], petId: pet);
        check(sa.rows('memories').length == 2, 'app uploads two ready photos');
        check(
          sa.memoryOriginFor(pet) == DateTime(1999),
          'server completion updates Day 0',
        );
        final photo = sa.rows('memories').first;
        final id = photo['id'] as String;
        final path = (photo['photo'] as String).substring(
          privatePhotoPrefix.length,
        );
        check(
          (await sa.photoRepository!.download(
                sa.user!,
                photo['photo'],
              )).toString() ==
              base64Decode(pixel).toString(),
          'authenticated app download matches bytes',
        );
        final independent = await start(client(), 'A');
        check(
          independent.rows('memories').length == 2 &&
              independent.memoryOriginFor(pet) == DateTime(1999),
          'independent store reads photos and Day 0',
        );
        await expectLater(stale.deleteOwned('pets', pet), throwsException);
        assertions++;
        check(
          stale.rows('pets').length == 1,
          'stale deletion denied by server FK',
        );
        check(
          (await b.from('memory_photos').select()).isEmpty,
          'B cannot read A metadata',
        );
        check(
          (await b
                  .from('memory_photos')
                  .update({'state': 'deleting'})
                  .eq('id', id)
                  .select())
              .isEmpty,
          'B cannot update A metadata',
        );
        check(
          (await b.from('memory_photos').delete().eq('id', id).select())
              .isEmpty,
          'B cannot delete A metadata',
        );
        await denied(
          b.rpc(
            'finish_memory_photos',
            params: {
              'p_ids': [id],
            },
          ),
          'B cannot finalize A photo',
        );
        await denied(
          b.storage.from(SupabasePhotoRepository.bucket).download(path),
          'B cannot download A file',
        );
        await denied(
          b.storage
              .from(SupabasePhotoRepository.bucket)
              .createSignedUrl(path, 60),
          'B cannot sign A file',
        );
        await b.storage.from(SupabasePhotoRepository.bucket).remove([path]);
        check(
          (await a.storage.from(SupabasePhotoRepository.bucket).download(path))
              .isNotEmpty,
          'B removal leaves A file intact',
        );
        await denied(
          anon.from('memory_photos').select(),
          'signed-out metadata denied',
        );
        await denied(
          anon.storage.from(SupabasePhotoRepository.bucket).download(path),
          'signed-out file denied',
        );
        final publicResponse = await http.get(
          Uri.parse(
            anon.storage
                .from(SupabasePhotoRepository.bucket)
                .getPublicUrl(path),
          ),
        );
        check(
          publicResponse.statusCode != 200,
          'public URL cannot serve private photo',
        );
        await denied(
          anon.storage
              .from(SupabasePhotoRepository.bucket)
              .uploadBinary(
                path,
                base64Decode(pixel),
                fileOptions: const FileOptions(contentType: 'image/png'),
              ),
          'signed-out upload denied',
        );
        await denied(
          a.storage
              .from(SupabasePhotoRepository.bucket)
              .download(path.replaceFirst(sa.user!, sb.user!)),
          'wrong owner path denied',
        );
        await denied(
          b.from('memory_photos').insert({
            'pet_id': pet,
            'record_date': '1999-01-01',
          }),
          'cannot attach B photo to A pet',
        );
        await denied(
          a.from('memory_photos').update({'owner_id': sb.user}).eq('id', id),
          'owner change denied',
        );
        await denied(
          a.from('memory_photos').update({'object_path': 'spoof'}).eq('id', id),
          'path change denied',
        );
        await denied(
          a.storage
              .from(SupabasePhotoRepository.bucket)
              .uploadBinary(
                path,
                base64Decode(pixel),
                fileOptions: const FileOptions(
                  contentType: 'image/png',
                  upsert: true,
                ),
              ),
          'ready file overwrite denied',
        );
        await denied(
          a.from('memory_photos').delete().eq('id', id),
          'ready metadata deletion denied',
        );
        await a.storage.from(SupabasePhotoRepository.bucket).remove([path]);
        check(
          (await a.storage.from(SupabasePhotoRepository.bucket).download(path))
              .isNotEmpty,
          'owner must mark ready file for deletion before removal',
        );
        await denied(
          a
              .from('pets')
              .update({
                'memory_origin_type': 'firstMeeting',
                'memory_origin_date': '2000-01-01',
              })
              .eq('id', pet),
          'direct Day 0 after photo denied',
        );
        await sa.saveMemoryPhotos(
          '1998-01-01',
          [photo['photo']],
          existingId: id,
          petId: pet,
        );
        check(
          sa.rows('memories').firstWhere((p) => p['id'] == id)['date'] ==
                  '1998-01-01' &&
              sa.memoryOriginFor(pet) == DateTime(1998),
          'date-only edit preserves ID and updates origin',
        );
        await sa.saveMemoryPhotos(
          '1997-01-01',
          ['data:image/png;base64,$pixel'],
          existingId: id,
          petId: pet,
        );
        check(
          sa.rows('memories').length == 2 &&
              !sa.rows('memories').any((p) => p['id'] == id),
          'replacement leaves exactly two ready photos',
        );
        await denied(
          a.storage
              .from(SupabasePhotoRepository.bucket)
              .download(
                path,
                cacheNonce: 'deleted-${DateTime.now().microsecondsSinceEpoch}',
              ),
          'replacement cleans old file',
        );
        check(
          (await a.from('memory_photos').select()).every(
            (p) => p['state'] == 'ready',
          ),
          'replacement has no pending cleanup',
        );
        await Future.wait([
          independent.saveMemoryPhotos('1996-01-01', [
            'data:image/png;base64,$pixel',
          ], petId: pet),
          stale.saveMemoryPhotos('1995-01-01', [
            'data:image/png;base64,$pixel',
          ], petId: pet),
        ]);
        await sa.retryPhotoCleanup();
        check(
          sa.rows('memories').length == 4 &&
              sa.memoryOriginFor(pet) == DateTime(1995),
          'concurrent clients keep earliest photo as Day 0',
        );
        await sa.setMemoryOrigin('firstMeeting', DateTime(1994), petId: pet);
        await denied(
          a.from('memory_photos').insert({
            'pet_id': pet,
            'record_date': '1993-01-01',
          }),
          'first-meeting boundary on direct insert',
        );
        await denied(
          a.from('memory_photos').insert({
            'pet_id': pet,
            'record_date': '1989-12-31',
          }),
          'pre-1990 rejected',
        );
        await denied(
          a.from('memory_photos').insert({
            'pet_id': pet,
            'record_date': dayKey(
              korea(DateTime.now()).add(const Duration(days: 1)),
            ),
          }),
          'future KST date rejected',
        );
        final reservation = await a
            .from('memory_photos')
            .insert({'pet_id': pet, 'record_date': '1994-01-01'})
            .select()
            .single();
        final reservedId = reservation['id'],
            reservedPath = reservation['object_path'] as String;
        await denied(
          a.rpc(
            'finish_memory_photos',
            params: {
              'p_ids': [reservedId],
            },
          ),
          'fileless completion rejected',
        );
        await denied(
          a.storage
              .from(SupabasePhotoRepository.bucket)
              .uploadBinary(
                reservedPath,
                Uint8List(3145729),
                fileOptions: const FileOptions(contentType: 'image/png'),
              ),
          'bucket rejects more than 3 MiB',
        );
        await denied(
          a.storage
              .from(SupabasePhotoRepository.bucket)
              .uploadBinary(
                reservedPath,
                Uint8List.fromList([1]),
                fileOptions: const FileOptions(contentType: 'text/plain'),
              ),
          'bucket rejects disallowed MIME',
        );
        await a
            .from('memory_photos')
            .update({'state': 'deleting'})
            .eq('id', reservedId);
        await denied(
          a.storage
              .from(SupabasePhotoRepository.bucket)
              .uploadBinary(
                reservedPath,
                base64Decode(pixel),
                fileOptions: const FileOptions(contentType: 'image/png'),
              ),
          'late upload after cancellation rejected',
        );
        check(
          await sa.photoRepository!.cleanup(sa.user!),
          'cancelled reservation cleanup succeeds',
        );
        check(
          await a
                  .from('memory_photos')
                  .select('id')
                  .eq('id', reservedId)
                  .maybeSingle() ==
              null,
          'cancelled reservation removed',
        );
        await sa.saveMemoryDay('1997-01-01', '사진과 별개', '보존', true, petId: pet);
        for (final p in List<Map<String, dynamic>>.of(sa.rows('memories'))) {
          await sa.deleteOwned('memories', p['id']);
        }
        check(
          sa.rows('memories').isEmpty &&
              (await a.from('memory_photos').select()).isEmpty,
          'photo delete removes all metadata',
        );
        check(
          sa.memoryOriginFor(pet) == DateTime(1994),
          'photo deletion does not advance Day 0',
        );
        check(
          sa.rows('memoryDays').single['title'] == '사진과 별개',
          'photo delete preserves journal',
        );
        await expectLater(sa.deleteOwned('pets', pet), throwsException);
        assertions++;
        await sa.deleteMemoryDay('1997-01-01', petId: pet);
        await sa.deleteOwned('pets', pet);
        createdPets.remove(pet);
        check(
          sa.rows('pets').isEmpty,
          'clearing all linked records permits pet deletion',
        );
        check(
          prefs.getString(PetStore.key) == before,
          'legacy local JSON preserved byte-for-byte',
        );
        // ignore: avoid_print
        print(
          'PASS: $assertions assertions; real private Storage, A/B isolation, app CRUD, Day 0, cleanup, FK and local preservation.',
        );
      } finally {
        for (final c in [a, b]) {
          final owner = c.auth.currentUser?.id;
          if (owner == null) continue;
          for (final pet in createdPets) {
            await c
                .from('memory_photos')
                .update({'state': 'deleting'})
                .eq('owner_id', owner)
                .eq('pet_id', pet);
            await SupabasePhotoRepository(c).cleanup(owner);
            await c
                .from('memory_days')
                .delete()
                .eq('owner_id', owner)
                .eq('pet_id', pet);
            await c.from('pets').delete().eq('id', pet).eq('owner_id', owner);
          }
          if (createdProfiles.contains(owner)) {
            await c.from('profiles').delete().eq('id', owner);
          }
        }
        for (final s in stores) {
          s.dispose();
        }
        for (final s in auths) {
          s.dispose();
        }
        for (final c in clients) {
          await c.dispose();
        }
        faults.close();
        HttpOverrides.global = overrides;
      }
    },
    skip: Platform.environment['PET_SNS_RUN_PHOTO_LIVE'] != '1',
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
