import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pet_sns/store.dart';
import 'package:pet_sns/supabase_auth_service.dart';
import 'package:pet_sns/supabase_pet_repository.dart';
import 'package:pet_sns/supabase_photo_repository.dart';
import 'package:pet_sns/widgets/pet_photo.dart';
import 'package:pet_sns/widgets/private_photo_scope.dart';
import 'supabase_memory_test.dart' as fixture;

const pixel =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Wl6S8sAAAAASUVORK5CYII=';
const source = 'data:image/png;base64,$pixel';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SupabaseClient client;
  late SupabaseAuthService auth;
  late PetStore store;
  late SharedPreferences prefs;
  late String before;
  late List<Map<String, dynamic>> photos;
  late Map<String, Uint8List> files;
  late List<http.Request> requests;
  var uploads = 0;
  int? failUpload;
  var failRemove = false, loseCommit = false;
  Completer<void>? uploadWait;
  Future<http.Response> Function(http.Request)? override;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    final local = PetStore(prefs);
    await local.load();
    await local.testLogin();
    local.dispose();
    before = prefs.getString(PetStore.key)!;
    photos = [];
    files = {};
    requests = [];
    uploads = 0;
    failUpload = null;
    failRemove = false;
    loseCommit = false;
    uploadWait = null;
    override = null;
    client = SupabaseClient(
      'https://fixture.supabase.co',
      'sb_publishable_fixture',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((r) async {
        Future<http.Response> handle() async {
          requests.add(r);
          if (override != null) {
            final result = await override!(r);
            if (result.statusCode != 299) return result;
          }
          final path = r.url.path;
          if (path.endsWith('/token')) {
            return fixture.response(fixture.session('owner-a'));
          }
          if (path.endsWith('/logout')) return http.Response('', 204);
          if (path.endsWith('/profiles')) {
            return fixture.response({'id': 'owner-a', 'name': 'fixture'});
          }
          if (path.endsWith('/pets')) {
            return fixture.response([
              {
                'id': 'pet-a',
                'owner_id': 'owner-a',
                'name': 'pet',
                'breed': '',
                'birthday': null,
                'photo': null,
                'memory_origin_type': 'firstPhoto',
                'memory_origin_date': '2000-01-01',
              },
            ]);
          }
          if (path.endsWith('/rpc/claim_memory_photo_cleanup')) {
            return http.Response('', 204);
          }
          if (path.endsWith('/rpc/finish_memory_photos')) {
            final body = jsonDecode(r.body);
            final ids = body['p_ids'] as List;
            for (final p in photos.where((p) => ids.contains(p['id']))) {
              p['state'] = 'ready';
            }
            for (final p in photos.where((p) => p['id'] == body['p_replace'])) {
              p['state'] = 'deleting';
            }
            if (loseCommit) {
              return fixture.response({
                'message': 'private server diagnostic',
              }, 500);
            }
            return http.Response('', 204);
          }
          if (path.endsWith('/memory_photos')) {
            final q = r.url.queryParameters;
            bool matches(Map<String, dynamic> p) =>
                (q['id'] == null ||
                    q['id'] == 'eq.${p['id']}' ||
                    (q['id']!.startsWith('in.') &&
                        q['id']!.contains(p['id']))) &&
                (q['state'] == null || q['state'] == 'eq.${p['state']}');
            if (r.method == 'POST') {
              final body = jsonDecode(r.body) as List;
              for (final item in body) {
                photos.add({
                  ...item,
                  'owner_id': 'owner-a',
                  'state': 'pending',
                  'object_path': 'owner-a/${item['id']}',
                });
              }
              return http.Response('', 201);
            }
            if (r.method == 'PATCH') {
              for (final p in photos.where(matches)) {
                p.addAll(Map<String, dynamic>.from(jsonDecode(r.body)));
              }
            }
            if (r.method == 'DELETE') {
              photos.removeWhere(matches);
              return http.Response('', 204);
            }
            final result = photos
                .where(matches)
                .map((p) => Map<String, dynamic>.from(p))
                .toList();
            return fixture.response(
              r.headers['accept']?.contains('object') == true
                  ? result.single
                  : result,
            );
          }
          if (path.endsWith('/object/memory-photos') && r.method == 'DELETE') {
            if (failRemove) {
              return fixture.response({
                'message': 'private cleanup diagnostic',
              }, 500);
            }
            for (final p in jsonDecode(r.body)['prefixes'] as List) {
              files.remove(p);
            }
            return fixture.response([]);
          }
          if (path.contains('/object/memory-photos/') && r.method == 'POST') {
            uploads++;
            if (uploadWait != null) await uploadWait!.future;
            if (uploads == failUpload) {
              return fixture.response({
                'message': 'private upload diagnostic',
              }, 500);
            }
            final object = path.split('/object/memory-photos/').last;
            files[object] = base64Decode(pixel);
            return fixture.response({'Key': 'memory-photos/$object'});
          }
          if (path.contains('/object/memory-photos/') && r.method == 'GET') {
            return http.Response.bytes(base64Decode(pixel), 200);
          }
          throw StateError('unexpected fixture route');
        }

        final result = await handle();
        return http.Response.bytes(
          result.bodyBytes,
          result.statusCode,
          headers: result.headers,
          request: r,
        );
      }),
    );
    auth = SupabaseAuthService(client);
    await auth.login('owner-a@example.com', 'fixture-pass');
    store = PetStore(
      prefs,
      auth: auth,
      petRepository: SupabasePetRepository(client),
      photoRepository: SupabasePhotoRepository(client),
      clock: () => DateTime.utc(2026, 10, 10),
    );
    await store.load();
  });
  tearDown(() async {
    store.dispose();
    auth.dispose();
    await client.dispose();
  });

  test(
    'upload, date-only edit, replacement and delete preserve local JSON',
    () async {
      await store.saveMemoryPhotos('1999-01-01', [
        source,
        source,
      ], petId: 'pet-a');
      expect(store.rows('memories'), hasLength(2));
      expect(files, hasLength(2));
      final row = store.rows('memories').first;
      final id = row['id'];
      await store.saveMemoryPhotos(
        '1998-01-01',
        [row['photo']],
        existingId: id,
        petId: 'pet-a',
      );
      expect(uploads, 2);
      expect(store.rows('memories').first['date'], '1998-01-01');
      await store.saveMemoryPhotos(
        '1997-01-01',
        [source],
        existingId: id,
        petId: 'pet-a',
      );
      expect(store.rows('memories'), hasLength(2));
      expect(files, hasLength(2));
      expect(photos.every((p) => p['state'] == 'ready'), isTrue);
      for (final p in List<Map<String, dynamic>>.of(store.rows('memories'))) {
        await store.deleteOwned('memories', p['id']);
      }
      expect(photos, isEmpty);
      expect(files, isEmpty);
      expect(prefs.getString(PetStore.key), before);
    },
  );
  test('validation rejects invalid input before requests', () async {
    final count = requests.length;
    for (final input in [
      '',
      'https://example.com/photo',
      'data:image/svg+xml;base64,AA==',
      'data:image/png;base64,invalid!',
      'data:image/png;base64,${base64Encode(Uint8List(3145729))}',
    ]) {
      await expectLater(
        store.saveMemoryPhotos('1999-01-01', [input], petId: 'pet-a'),
        throwsException,
      );
    }
    await expectLater(
      store.saveMemoryPhotos('2026-02-30', [source], petId: 'pet-a'),
      throwsException,
    );
    await expectLater(
      store.saveMemoryPhotos('2026-10-11', [source], petId: 'pet-a'),
      throwsException,
    );
    await expectLater(
      store.photoRepository!.save(store.user!, 'pet-a', '1999-01-01', []),
      throwsException,
    );
    expect(requests.length, count);
    expect(photos, isEmpty);
  });
  test(
    'batch upload failure rolls back files; failed cleanup is recoverable',
    () async {
      failUpload = 2;
      failRemove = true;
      await expectLater(
        store.saveMemoryPhotos('1999-01-01', [source, source], petId: 'pet-a'),
        throwsA(predicate((e) => !e.toString().contains('private'))),
      );
      expect(store.rows('memories'), isEmpty);
      expect(photos.every((p) => p['state'] == 'deleting'), isTrue);
      expect(files, hasLength(1));
      expect(store.photoCleanupPending, isTrue);
      failRemove = false;
      await store.retryPhotoCleanup();
      expect(photos, isEmpty);
      expect(files, isEmpty);
      expect(store.photoCleanupPending, isFalse);
    },
  );
  test(
    'replacement failure retains original and completed response loss retains new file',
    () async {
      await store.saveMemoryPhotos('1999-01-01', [source], petId: 'pet-a');
      final id = store.rows('memories').single['id'];
      failUpload = 2;
      await expectLater(
        store.saveMemoryPhotos(
          '1998-01-01',
          [source],
          existingId: id,
          petId: 'pet-a',
        ),
        throwsException,
      );
      expect(store.rows('memories').single['id'], id);
      expect(files, hasLength(1));
      failUpload = null;
      loseCommit = true;
      await store.saveMemoryPhotos(
        '1998-01-01',
        [source],
        existingId: id,
        petId: 'pet-a',
      );
      expect(store.rows('memories').single['id'], isNot(id));
      expect(files, hasLength(1));
      expect(photos.single['state'], 'ready');
    },
  );
  test(
    'commit settling while cancellation waits is recognized as success',
    () async {
      override = (r) async {
        if (r.url.path.endsWith('/finish_memory_photos')) {
          return fixture.response({'message': 'lost response'}, 500);
        }
        if (r.url.path.endsWith('/memory_photos') && r.method == 'PATCH') {
          for (final p in photos) {
            p['state'] = 'ready';
          }
          return fixture.response([]);
        }
        return http.Response('', 299);
      };
      await store.saveMemoryPhotos('1999-01-01', [source], petId: 'pet-a');
      expect(store.rows('memories'), hasLength(1));
      expect(files, hasLength(1));
      expect(photos.single['state'], 'ready');
    },
  );
  test(
    'delete failure hides gallery row, exposes cleanup retry and preserves parent',
    () async {
      await store.saveMemoryPhotos('1999-01-01', [source], petId: 'pet-a');
      final id = store.rows('memories').single['id'];
      failRemove = true;
      await expectLater(store.deleteOwned('memories', id), throwsException);
      expect(store.rows('memories'), isEmpty);
      expect(store.photoCleanupPending, isTrue);
      expect(photos.single['state'], 'deleting');
      failRemove = false;
      await store.retryPhotoCleanup();
      expect(files, isEmpty);
      expect(photos, isEmpty);
      expect(store.rows('pets'), hasLength(1));
    },
  );
  test(
    'logout and overlapping save discard late response and stop finalization',
    () async {
      uploadWait = Completer<void>();
      final saving = store.saveMemoryPhotos('1999-01-01', [
        source,
      ], petId: 'pet-a');
      final failure = expectLater(saving, throwsException);
      while (uploads == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      await expectLater(
        store.saveMemoryPhotos('1999-01-01', [source], petId: 'pet-a'),
        throwsException,
      );
      await auth.logout();
      uploadWait!.complete();
      await failure;
      expect(store.rows('memories'), isEmpty);
      expect(store.user, isNull);
      expect(
        requests.any((r) => r.url.path.endsWith('/finish_memory_photos')),
        isFalse,
      );
      expect(prefs.getString(PetStore.key), before);
    },
  );
  test('metadata pagination reads beyond 500 ready rows', () async {
    override = (r) async {
      if (!r.url.path.endsWith('/memory_photos')) return http.Response('', 299);
      final offset = int.tryParse(r.url.queryParameters['offset'] ?? '0') ?? 0;
      return fixture.response([
        for (var i = offset; i < 501 && i < offset + 500; i++)
          {
            'id': 'p-$i',
            'owner_id': 'owner-a',
            'pet_id': 'pet-a',
            'record_date': '1999-01-01',
            'object_path': 'owner-a/p-$i',
            'state': 'ready',
          },
      ]);
    };
    expect(await store.photoRepository!.list(store.user!), hasLength(501));
  });
  testWidgets(
    'private image loads and clears its displayed bytes on account change',
    (tester) async {
      Widget view(String? owner) => MaterialApp(
        home: PrivatePhotoScope(
          repository: store.photoRepository,
          owner: owner,
          child: const PetPhoto(
            source: 'petsns-photo:owner-a/p',
            height: 80,
            width: 80,
          ),
        ),
      );
      await tester.pumpWidget(view(store.user));
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      await tester.pumpWidget(view('owner-b'));
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNothing);
      expect(find.byTooltip('사진 다시 불러오기'), findsOneWidget);
    },
  );
  testWidgets(
    'private image retries and drops a download completed after logout',
    (tester) async {
      final gate = Completer<http.Response>();
      var downloads = 0;
      override = (r) async {
        if (r.url.path.contains('/object/memory-photos/') &&
            r.method == 'GET') {
          downloads++;
          if (downloads == 1) {
            return fixture.response({'message': 'failed'}, 500);
          }
          return gate.future;
        }
        return http.Response('', 299);
      };
      Widget view(String? owner) => MaterialApp(
        home: PrivatePhotoScope(
          repository: store.photoRepository,
          owner: owner,
          child: const PetPhoto(
            source: 'petsns-photo:owner-a/p',
            height: 80,
            width: 80,
          ),
        ),
      );
      await tester.pumpWidget(view(store.user));
      await tester.pumpAndSettle();
      expect(find.byTooltip('사진 다시 불러오기'), findsOneWidget);
      await tester.tap(find.byTooltip('사진 다시 불러오기'));
      await tester.pump();
      expect(downloads, 2);
      await tester.pumpWidget(view(null));
      gate.complete(http.Response.bytes(base64Decode(pixel), 200));
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );
}
