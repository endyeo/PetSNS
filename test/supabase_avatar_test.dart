import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pet_sns/main.dart';
import 'package:pet_sns/store.dart';
import 'package:pet_sns/supabase_auth_service.dart';
import 'package:pet_sns/supabase_avatar_repository.dart';
import 'package:pet_sns/supabase_pet_repository.dart';
import 'package:pet_sns/supabase_photo_repository.dart';
import 'package:pet_sns/widgets/private_photo_scope.dart';
import 'supabase_memory_test.dart' as fixture;
import 'supabase_photo_test.dart' show pixel, source;
import 'performance_test.dart' show host;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SupabaseClient client;
  late SupabaseAuthService auth;
  late PetStore store;
  late List<Map<String, dynamic>> pets, avatars;
  late List<http.Request> requests;
  late SharedPreferences prefs;
  late String before;
  Completer<void>? uploadGate;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    final demo = PetStore(prefs);
    await demo.load();
    await demo.testLogin();
    demo.dispose();
    before = prefs.getString(PetStore.key)!;
    pets = [];
    avatars = [];
    requests = [];
    uploadGate = null;
    client = SupabaseClient(
      'https://fixture.supabase.co',
      'sb_publishable_fixture',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((r) async {
        Future<http.Response> handle() async {
          requests.add(r);
          final path = r.url.path;
          if (path.endsWith('/token')) {
            return fixture.response(fixture.session('owner-a'));
          }
          if (path.endsWith('/logout')) return http.Response('', 204);
          if (path.endsWith('/profiles')) {
            return fixture.response({'id': 'owner-a', 'name': 'fixture'});
          }
          if (path.endsWith('/rpc/claim_avatar_cleanup')) {
            return http.Response('', 204);
          }
          if (path.endsWith('/rpc/save_pet_with_avatar')) {
            final body = jsonDecode(r.body), id = body['p_pet_id'];
            if (body['p_create'] == true) {
              pets.add({
                'id': id,
                'owner_id': 'owner-a',
                'name': '',
                'breed': '',
                'birthday': null,
                'photo': null,
                'avatar_id': null,
                'memory_origin_type': null,
                'memory_origin_date': null,
              });
            }
            final row = pets.singleWhere((p) => p['id'] == id);
            row.addAll(Map<String, dynamic>.from(body['p_values']));
            row['avatar_id'] = body['p_avatar'];
            for (final a in avatars) {
              a['state'] = a['id'] == row['avatar_id'] ? 'ready' : 'deleting';
            }
            return fixture.response(row);
          }
          if (path.endsWith('/pets')) {
            if (r.method == 'PATCH') {
              final row = pets.singleWhere(
                (p) => 'eq.${p['id']}' == r.url.queryParameters['id'],
              );
              row.addAll(jsonDecode(r.body));
              return fixture.response(row);
            }
            return fixture.response(pets);
          }
          if (path.endsWith('/pet_avatars')) {
            if (r.method == 'POST') {
              final id = jsonDecode(r.body)['id'];
              avatars.add({
                'id': id,
                'owner_id': 'owner-a',
                'object_path': 'owner-a/$id',
                'state': 'pending',
              });
              return http.Response('', 201);
            }
            bool matches(Map<String, dynamic> a) => ['id', 'state'].every(
              (k) =>
                  r.url.queryParameters[k] == null ||
                  r.url.queryParameters[k] == 'eq.${a[k]}',
            );
            if (r.method == 'PATCH') {
              for (final a in avatars.where(matches)) {
                a.addAll(jsonDecode(r.body));
              }
              return http.Response('', 204);
            }
            if (r.method == 'DELETE') {
              avatars.removeWhere(matches);
              return http.Response('', 204);
            }
            return fixture.response(avatars.where(matches).toList());
          }
          if (path.endsWith('/object/pet-avatars') && r.method == 'DELETE') {
            return fixture.response([]);
          }
          if (path.contains('/object/pet-avatars/')) {
            if (r.method == 'POST') {
              if (uploadGate != null) await uploadGate!.future;
              return fixture.response({'Key': path});
            }
            return http.Response.bytes(base64Decode(pixel), 200);
          }
          throw StateError('unexpected fixture route: $path');
        }

        final response = await handle();
        return http.Response.bytes(
          response.bodyBytes,
          response.statusCode,
          headers: response.headers,
          request: r,
        );
      }),
    );
    auth = SupabaseAuthService(client);
    await auth.login('fixture@example.com', 'fixture-pass');
    store = PetStore(
      prefs,
      auth: auth,
      petRepository: SupabasePetRepository(client),
      avatarRepository: SupabaseAvatarRepository(client),
    );
    await store.load();
  });
  tearDown(() async {
    store.dispose();
    auth.dispose();
    await client.dispose();
  });
  test(
    'overlapping profile upload rejected and local JSON untouched',
    () async {
      uploadGate = Completer<void>();
      final first = store.saveOwned('pets', {'name': 'pet', 'photo': source});
      while (!requests.any(
        (r) =>
            r.url.path.contains('/object/pet-avatars/') && r.method == 'POST',
      )) {
        await Future<void>.delayed(Duration.zero);
      }
      await expectLater(
        store.saveOwned('pets', {'name': 'duplicate', 'photo': source}),
        throwsException,
      );
      expect(pets, isEmpty);
      uploadGate!.complete();
      await first;
      expect(pets, hasLength(1));
      expect(
        store.rows('pets').single['photo'],
        startsWith(privateAvatarPrefix),
      );
      expect(prefs.getString(PetStore.key), before);
    },
  );
  test(
    'logout during upload prevents profile commit and stale cache update',
    () async {
      uploadGate = Completer<void>();
      final first = store.saveOwned('pets', {'name': 'late', 'photo': source});
      final rejected = expectLater(first, throwsException);
      while (!requests.any(
        (r) =>
            r.url.path.contains('/object/pet-avatars/') && r.method == 'POST',
      )) {
        await Future<void>.delayed(Duration.zero);
      }
      await store.logout();
      uploadGate!.complete();
      await rejected;
      expect(pets, isEmpty);
      expect(store.rows('pets'), isEmpty);
      expect(
        requests.any((r) => r.url.path.endsWith('/save_pet_with_avatar')),
        isFalse,
      );
      expect(prefs.getString(PetStore.key), before);
    },
  );
  testWidgets(
    'private avatar uses separate bucket and clears image on owner change',
    (tester) async {
      Widget view(String? owner) => MaterialApp(
        home: PrivatePhotoScope(
          repository: SupabasePhotoRepository(client),
          owner: owner,
          child: const PetPhoto(
            source: 'petsns-avatar:owner-a/image',
            height: 80,
            width: 80,
          ),
        ),
      );
      await tester.pumpWidget(view('owner-a'));
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      expect(
        requests.any((r) => r.url.path.contains('/object/pet-avatars/')),
        isTrue,
      );
      await tester.pumpWidget(view('owner-b'));
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNothing);
    },
  );
  testWidgets('online profile picker cancel save and photo-only removal', (
    tester,
  ) async {
    final directory = Directory.systemTemp.createTempSync(
      'petsns-avatar-test-',
    );
    final file = File('${directory.path}/photo.png')
      ..writeAsBytesSync(base64Decode(pixel));
    addTearDown(() => directory.deleteSync(recursive: true));
    const channel = MethodChannel('plugins.flutter.io/image_picker');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      expect(call.method, 'pickImage');
      return file.path;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    await tester.pumpWidget(
      host(
        PrivatePhotoScope(
          repository: SupabasePhotoRepository(client),
          owner: 'owner-a',
          child: Home(store: store),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('반려동물').last);
    await tester.pumpAndSettle();
    Future<void> pick() async {
      await tester.runAsync(() async {
        await tester.tap(find.text('사진 선택'));
        for (var i = 0; i < 100; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          await tester.pump();
          if (find.text('사진만 제거').evaluate().isNotEmpty) break;
        }
      });
      await tester.pumpAndSettle();
      expect(find.text('사진만 제거'), findsOneWidget);
    }

    await tester.tap(find.text('반려동물 등록'));
    await tester.pumpAndSettle();
    await pick();
    await tester.tap(find.text('닫기'));
    await tester.pumpAndSettle();
    expect(pets, isEmpty);
    expect(avatars, isEmpty);
    await tester.tap(find.text('반려동물 등록'));
    await tester.pumpAndSettle();
    await pick();
    await tester.enterText(find.byType(TextField).first, '새 가족');
    uploadGate = Completer<void>();
    await tester.tap(find.text('저장'));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField).first).enabled,
      isFalse,
    );
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '닫기'))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '저장'))
          .onPressed,
      isNull,
    );
    uploadGate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(store.rows('pets').single['photo'], startsWith(privateAvatarPrefix));
    await tester.tap(find.byTooltip('프로필 수정'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('사진만 제거'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(store.rows('pets').single['name'], '새 가족');
    expect(store.rows('pets').single['photo'], isNull);
    expect(avatars, isEmpty);
    expect(prefs.getString(PetStore.key), before);
  });
}
