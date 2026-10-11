import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pet_sns/store.dart';
import 'package:pet_sns/supabase_auth_service.dart';
import 'package:pet_sns/supabase_avatar_repository.dart';
import 'package:pet_sns/supabase_pet_repository.dart';
import 'package:pet_sns/supabase_memory_repository.dart';
import 'package:pet_sns/supabase_photo_repository.dart';
import 'supabase_photo_test.dart' show pixel, source;

class AvatarFaults extends http.BaseClient {
  final inner = http.Client();
  bool failUpload = false,
      failCommit = false,
      loseCommit = false,
      failRemove = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;
    if ((failUpload &&
            path.contains('/object/pet-avatars/') &&
            request.method == 'POST') ||
        (failCommit && path.endsWith('/save_pet_with_avatar')) ||
        (failRemove &&
            path.endsWith('/object/pet-avatars') &&
            request.method == 'DELETE')) {
      return http.StreamedResponse(
        Stream.value(utf8.encode('{"message":"simulated interruption"}')),
        503,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    }
    final response = await inner.send(request);
    if (loseCommit &&
        path.endsWith('/save_pet_with_avatar') &&
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
    'real private avatars, atomic profiles, failure recovery and ownership',
    () async {
      final credentials = jsonDecode(
        File('config/supabase.test.local.json').readAsStringSync(),
      );
      final oldOverrides = HttpOverrides.current;
      HttpOverrides.global = null;
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final local = PetStore(prefs);
      await local.load();
      await local.testLogin();
      local.dispose();
      final before = prefs.getString(PetStore.key);
      final clients = <SupabaseClient>[],
          auths = <SupabaseAuthService>[],
          stores = <PetStore>[];
      final ownedPets = <String>{},
          createdProfiles = <String>{},
          reservations = <String>{};
      final faults = AvatarFaults();
      var assertions = 0;
      void check(bool value, String label) {
        expect(value, isTrue, reason: label);
        assertions++;
      }

      Future<void> denied(Future<dynamic> future, String label) async {
        await expectLater(
          future,
          throwsA(anyOf(isA<PostgrestException>(), isA<StorageException>())),
          reason: label,
        );
        assertions++;
      }

      Future<void> appDenied(Future<dynamic> future, String label) async {
        await expectLater(future, throwsException, reason: label);
        assertions++;
      }

      SupabaseClient client([http.Client? transport]) {
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
          avatarRepository: SupabaseAvatarRepository(c),
        );
        stores.add(s);
        await s.load();
        return s;
      }

      final a = client(),
          b = client(),
          anon = client(),
          faulty = client(faults);
      try {
        final sa = await start(a, 'A'),
            sb = await start(b, 'B'),
            sf = await start(faulty, 'A');
        check(
          sa.rows('pets').isEmpty &&
              sb.rows('pets').isEmpty &&
              (await a.from('pet_avatars').select()).isEmpty,
          'dedicated fixtures start empty',
        );
        faults.failUpload = true;
        await appDenied(
          sf.saveOwned('pets', {'name': 'failed new', 'photo': source}),
          'upload failure',
        );
        check(
          (await a.from('pets').select()).isEmpty &&
              (await a.from('pet_avatars').select()).isEmpty,
          'upload failure leaves neither empty pet nor reservation',
        );
        faults.failUpload = false;
        faults.failCommit = true;
        await appDenied(
          sf.saveOwned('pets', {'name': 'failed commit', 'photo': source}),
          'new profile commit failure',
        );
        check(
          (await a.from('pets').select()).isEmpty &&
              (await a.from('pet_avatars').select()).isEmpty,
          'commit failure removes staged file and leaves no pet',
        );
        faults.failCommit = false;
        faults.loseCommit = true;
        await sf.saveOwned('pets', {
          'name': 'avatar A',
          'breed': 'breed',
          'birthday': '2000-01-01',
          'photo': source,
        });
        final pet = sf.rows('pets').single['id'] as String;
        ownedPets.add(pet);
        final original = sf.rows('pets').single['photo'] as String;
        check(
          original.startsWith(privateAvatarPrefix) &&
              (await a.from('pets').select()).length == 1,
          'lost response recovered without duplicate pet',
        );
        check(
          (await a.from('pet_avatars').select()).single['state'] == 'ready',
          'committed photo remains ready',
        );
        final reloaded = await start(client(), 'A');
        check(
          reloaded.rows('pets').single['photo'] == original,
          'independent app instance restores committed avatar reference',
        );
        check(
          listEquals(
            await SupabasePhotoRepository(a).download(sa.user!, original),
            base64Decode(pixel),
          ),
          'independent client downloads avatar bytes',
        );
        final path = original.substring(privateAvatarPrefix.length),
            avatar = path.split('/').last;
        check(
          (await b.from('pet_avatars').select()).isEmpty,
          'B cannot see A metadata',
        );
        await denied(
          b.storage
              .from(SupabaseAvatarRepository.bucket)
              .download(path, cacheNonce: newPhotoId()),
          'B cannot download A avatar',
        );
        await denied(
          anon.from('pet_avatars').select(),
          'anonymous metadata denied',
        );
        await denied(
          anon.storage
              .from(SupabaseAvatarRepository.bucket)
              .download(path, cacheNonce: newPhotoId()),
          'anonymous file denied',
        );
        await denied(
          b.rpc(
            'save_pet_with_avatar',
            params: {
              'p_pet_id': 'forged',
              'p_create': true,
              'p_values': {'name': 'forged'},
              'p_avatar': avatar,
            },
          ),
          'B cannot attach A avatar',
        );
        await b
            .from('pet_avatars')
            .update({'state': 'deleting'})
            .eq('id', avatar);
        await b.from('pet_avatars').delete().eq('id', avatar);
        check(
          (await a
                  .from('pet_avatars')
                  .select()
                  .eq('id', avatar)
                  .single())['state'] ==
              'ready',
          'B mutations do not change A avatar',
        );
        await denied(
          a.from('pet_avatars').update({'state': 'deleting'}).eq('id', avatar),
          'active avatar cancellation denied',
        );
        await denied(
          a.from('pet_avatars').delete().eq('id', avatar),
          'active metadata deletion denied',
        );
        // Storage remove can return success with zero RLS-visible deletions.
        await a.storage.from(SupabaseAvatarRepository.bucket).remove([path]);
        check(
          listEquals(
            await SupabasePhotoRepository(a).download(sa.user!, original),
            base64Decode(pixel),
          ),
          'active file survives direct delete',
        );
        await denied(
          a.storage
              .from(SupabaseAvatarRepository.bucket)
              .uploadBinary(
                path,
                base64Decode(pixel),
                fileOptions: const FileOptions(
                  contentType: 'image/png',
                  upsert: true,
                ),
              ),
          'active file overwrite denied',
        );
        await sf.setMemoryOrigin('firstMeeting', DateTime(2000), petId: pet);
        await sf.saveOwned('pets', {'id': pet, 'name': 'field edit'});
        check(
          sf.rows('pets').single['photo'] == original &&
              sf.memoryOriginFor(pet) == DateTime(2000),
          'field edit preserves photo and Day 0',
        );
        faults.failUpload = true;
        await appDenied(
          sf.saveOwned('pets', {
            'id': pet,
            'name': 'rejected upload',
            'photo': source,
          }),
          'replacement upload failure',
        );
        faults.failUpload = false;
        faults.failCommit = true;
        await appDenied(
          sf.saveOwned('pets', {
            'id': pet,
            'name': 'rejected commit',
            'photo': source,
          }),
          'replacement commit failure',
        );
        faults.failCommit = false;
        check(
          (await a.from('pets').select().eq('id', pet).single())['name'] ==
                  'field edit' &&
              sf.rows('pets').single['photo'] == original &&
              sf.memoryOriginFor(pet) == DateTime(2000),
          'failed replacement preserves all previous fields',
        );
        faults.failRemove = true;
        await sf.saveOwned('pets', {
          'id': pet,
          'name': 'replaced',
          'photo': source,
        });
        final replacement = sf.rows('pets').single['photo'] as String;
        check(
          replacement != original && sf.avatarCleanupPending,
          'replacement commits despite old-file cleanup failure',
        );
        check(
          (await a.from('pet_avatars').select()).length == 2,
          'old cleanup reservation retained',
        );
        faults.failRemove = false;
        await sf.retryAvatarCleanup();
        check(
          !sf.avatarCleanupPending &&
              (await a.from('pet_avatars').select()).length == 1,
          'cleanup retry removes only old file',
        );
        await denied(
          a.storage
              .from(SupabaseAvatarRepository.bucket)
              .download(path, cacheNonce: newPhotoId()),
          'old file removed after retry',
        );
        await sf.saveMemoryDay(
          '2000-01-01',
          'journal',
          'keep',
          false,
          petId: pet,
        );
        await appDenied(
          sf.deleteOwned('pets', pet),
          'linked journal blocks pet deletion',
        );
        await denied(
          a.from('pets').delete().eq('id', pet),
          'direct API also blocks linked pet',
        );
        check(
          listEquals(
            await SupabasePhotoRepository(a).download(sa.user!, replacement),
            base64Decode(pixel),
          ),
          'blocked pet deletion preserves avatar',
        );
        await sf.saveOwned('pets', {'id': pet, 'photo': ''});
        check(
          sf.rows('pets').single['photo'] == null &&
              sf.rows('memoryDays').length == 1 &&
              sf.memoryOriginFor(pet) == DateTime(2000),
          'photo-only removal preserves pet journal and Day 0',
        );
        check(
          (await a.from('pet_avatars').select()).isEmpty,
          'photo removal cleans reservation',
        );
        await sf.saveOwned('pets', {'id': pet, 'photo': source});
        final finalPhoto = sf.rows('pets').single['photo'] as String;
        await sf.deleteMemoryDay('2000-01-01', petId: pet);
        await sf.deleteOwned('pets', pet);
        ownedPets.remove(pet);
        check(
          (await a.from('pet_avatars').select()).isEmpty,
          'successful pet deletion cleans avatar',
        );
        await denied(
          a.storage
              .from(SupabaseAvatarRepository.bucket)
              .download(
                finalPhoto.substring(privateAvatarPrefix.length),
                cacheNonce: newPhotoId(),
              ),
          'deleted pet file removed',
        );
        final reserve = newPhotoId();
        reservations.add(reserve);
        await a.from('pet_avatars').insert({'id': reserve});
        await denied(
          a.rpc(
            'save_pet_with_avatar',
            params: {
              'p_pet_id': 'missing-file',
              'p_create': true,
              'p_values': {'name': 'missing'},
              'p_avatar': reserve,
            },
          ),
          'missing file cannot finalize',
        );
        check(
          (await a.from('pets').select()).isEmpty,
          'missing file leaves no empty pet',
        );
        final reservedPath = '${sa.user}/$reserve';
        await denied(
          a.storage
              .from(SupabaseAvatarRepository.bucket)
              .uploadBinary(
                reservedPath,
                Uint8List(3145729),
                fileOptions: const FileOptions(contentType: 'image/png'),
              ),
          'server rejects size above 3MiB',
        );
        await denied(
          a.storage
              .from(SupabaseAvatarRepository.bucket)
              .uploadBinary(
                reservedPath,
                Uint8List.fromList([1]),
                fileOptions: const FileOptions(contentType: 'text/plain'),
              ),
          'server rejects disallowed MIME',
        );
        await a
            .from('pet_avatars')
            .update({'state': 'deleting'})
            .eq('id', reserve);
        await denied(
          a.storage
              .from(SupabaseAvatarRepository.bucket)
              .uploadBinary(
                reservedPath,
                base64Decode(pixel),
                fileOptions: const FileOptions(contentType: 'image/png'),
              ),
          'late upload after cancellation denied',
        );
        check(
          await sa.avatarRepository!.cleanup(sa.user!),
          'cancelled reservation cleaned',
        );
        reservations.remove(reserve);
        check(
          (await a.from('memory_photos').select()).isEmpty,
          'avatars do not create memory photos',
        );
        check(
          prefs.getString(PetStore.key) == before,
          'local JSON preserved byte for byte',
        );
        // ignore: avoid_print
        print(
          'PASS: $assertions assertions; real private avatars, atomic profiles, A/B isolation, fault recovery, cleanup and local preservation.',
        );
      } finally {
        faults.failUpload = false;
        faults.failCommit = false;
        faults.failRemove = false;
        for (final c in [a, b]) {
          final owner = c.auth.currentUser?.id;
          if (owner == null) continue;
          for (final id in ownedPets) {
            await c
                .from('memory_days')
                .delete()
                .eq('pet_id', id)
                .eq('owner_id', owner);
            await c.from('pets').delete().eq('id', id).eq('owner_id', owner);
          }
          for (final id in reservations) {
            await c
                .from('pet_avatars')
                .update({'state': 'deleting'})
                .eq('id', id)
                .eq('owner_id', owner);
          }
          await SupabaseAvatarRepository(c).cleanup(owner);
          if (createdProfiles.contains(owner)) {
            await c.from('profiles').delete().eq('id', owner);
          }
        }
        for (final s in stores) {
          s.dispose();
        }
        for (final auth in auths) {
          auth.dispose();
        }
        for (final c in clients) {
          await c.dispose();
        }
        faults.close();
        HttpOverrides.global = oldOverrides;
      }
    },
    skip: Platform.environment['PET_SNS_RUN_AVATAR_LIVE'] != '1',
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

bool listEquals(List<int> a, List<int> b) =>
    a.length == b.length &&
    Iterable<int>.generate(a.length).every((i) => a[i] == b[i]);
