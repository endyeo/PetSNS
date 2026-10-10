import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pet_sns/store.dart';
import 'package:pet_sns/supabase_auth_service.dart';
import 'package:pet_sns/supabase_pet_repository.dart';
import 'package:pet_sns/supabase_connection.dart';

Map<String, dynamic> session(String id) {
  final expiry = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return {
    'access_token':
        '${encode({'alg': 'HS256'})}.${encode({'sub': id, 'exp': expiry})}.fixture',
    'refresh_token': 'fixture-$id',
    'token_type': 'bearer',
    'expires_in': 3600,
    'user': {
      'id': id,
      'aud': 'authenticated',
      'role': 'authenticated',
      'email': '$id@example.com',
      'created_at': '2026-10-10T00:00:00Z',
      'app_metadata': {},
      'user_metadata': {'name': '보호자'},
    },
  };
}

http.Response response(Object? body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {
    'content-type': 'application/json',
    'x-supabase-api-version': '2024-01-01',
  },
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('only unconfigured local debug builds may use demo authentication', () {
    for (final host in ['localhost', '127.0.0.1', '[::1]']) {
      expect(
        requiresSupabase(
          debug: true,
          web: true,
          origin: Uri.parse('http://$host:8080'),
          hasSettings: false,
        ),
        isFalse,
      );
    }
    expect(
      requiresSupabase(
        debug: true,
        web: true,
        origin: Uri.parse('https://pets.example.com'),
        hasSettings: false,
      ),
      isTrue,
    );
    expect(
      requiresSupabase(
        debug: false,
        web: true,
        origin: Uri.parse('http://localhost'),
        hasSettings: false,
      ),
      isTrue,
    );
    expect(
      requiresSupabase(
        debug: true,
        web: false,
        origin: Uri.base,
        hasSettings: true,
      ),
      isTrue,
    );
    expect(
      requiresSupabase(
        debug: false,
        web: false,
        origin: Uri.base,
        hasSettings: false,
      ),
      isTrue,
    );
  });
  late SharedPreferences prefs;
  late SupabaseClient client;
  late SupabaseAuthService auth;
  late SupabasePetRepository repository;
  late PetStore store;
  late String before;
  late List<Map<String, dynamic>> pets;
  late List<http.Request> requests;
  Future<http.Response> Function(http.Request)? override;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    final local = PetStore(prefs);
    await local.load();
    await local.testLogin();
    before = prefs.getString(PetStore.key)!;
    local.dispose();
    requests = [];
    pets = [];
    override = null;
    client = SupabaseClient(
      'https://fixture.supabase.co',
      'sb_publishable_fixture',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        Future<http.Response> handle() async {
          requests.add(request);
          if (override != null) {
            final result = await override!(request);
            if (result.statusCode != 299) return result;
          }
          if (request.url.path.endsWith('/token')) {
            final email = jsonDecode(request.body)['email'] as String;
            return response(session(email.split('@').first));
          }
          if (request.url.path.endsWith('/logout')) {
            return http.Response('', 204);
          }
          if (request.url.path.endsWith('/profiles')) {
            return response({
              'id': client.auth.currentUser!.id,
              'name': '서버 보호자',
            });
          }
          if (request.url.path.endsWith('/pets')) {
            final owner = client.auth.currentUser!.id;
            if (request.method == 'POST') {
              pets.add({
                'id': 'pet-${pets.length}',
                'breed': '',
                'birthday': null,
                'photo': null,
                'memory_origin_type': null,
                'memory_origin_date': null,
                ...jsonDecode(request.body) as Map<String, dynamic>,
              });
              return response(pets.last);
            }
            final target = request.url.queryParameters['id']?.substring(3);
            final matches = pets
                .where(
                  (p) =>
                      p['owner_id'] == owner &&
                      (target == null || p['id'] == target),
                )
                .toList();
            if (request.method == 'PATCH') {
              if (matches.isEmpty) {
                return response({
                  'code': 'PGRST116',
                  'message': 'private details',
                }, 406);
              }
              matches.single.addAll(jsonDecode(request.body));
              return response(matches.single);
            }
            if (request.method == 'DELETE') pets.removeWhere(matches.contains);
            return response(matches);
          }
          throw StateError('Unexpected endpoint');
        }

        final result = await handle();
        return http.Response.bytes(
          result.bodyBytes,
          result.statusCode,
          headers: result.headers,
          request: request,
        );
      }),
    );
    auth = SupabaseAuthService(client);
    repository = SupabasePetRepository(client);
    store = PetStore(prefs, auth: auth, petRepository: repository);
    await store.load();
  });
  tearDown(() async {
    store.dispose();
    auth.dispose();
    await client.dispose();
  });

  test(
    'server CRUD and Day 0 preserve local JSON and unrelated remote fields',
    () async {
      expect(store.rows('pets'), isEmpty);
      await store.login('a@example.com', 'password-a');
      expect(store.account!['name'], '서버 보호자');
      await store.saveOwned('pets', {
        'name': ' 모카 ',
        'breed': '강아지',
        'birthday': '2022-01-02',
      });
      final id = store.rows('pets').single['id'] as String;
      await store.setMemoryOrigin(
        'firstMeeting',
        DateTime(2022, 2, 3),
        petId: id,
      );
      pets.single['memory_origin_date'] = '2022-02-04';
      await store.saveOwned('pets', {'id': id, 'name': '모카 수정'});
      expect(store.rows('pets').single['memoryOriginDate'], '2022-02-04');
      expect(store.rows('pets').single['birthday'], '2022-01-02');
      final patch = jsonDecode(requests.last.body) as Map;
      expect(patch.keys, ['name']);
      expect(patch.containsKey('owner_id'), isFalse);
      expect(prefs.getString(PetStore.key), before);
      await store.deleteOwned('pets', id);
      expect(store.rows('pets'), isEmpty);
      expect(pets, isEmpty);
      expect(prefs.getString(PetStore.key), before);
    },
  );

  test(
    'DB load failure blocks account and retry obtains server pets',
    () async {
      override = (request) async => request.url.path.endsWith('/pets')
          ? response({'message': 'sensitive server text'}, 503)
          : response({}, 299);
      await expectLater(
        store.login('a@example.com', 'password-a'),
        throwsException,
      );
      expect(store.user, isNull);
      expect(store.rows('pets'), isEmpty);
      expect(store.busy, isFalse);
      override = null;
      await store.login('a@example.com', 'password-a');
      expect(store.user, 'a');
      expect(prefs.getString(PetStore.key), before);
    },
  );

  test('failed save preserves cache and sanitizes server error', () async {
    await store.login('a@example.com', 'password-a');
    await store.saveOwned('pets', {'name': '모카'});
    override = (request) async => request.method == 'PATCH'
        ? response({'code': '23514', 'message': 'sensitive server text'}, 400)
        : response({}, 299);
    await expectLater(
      store.saveOwned('pets', {'id': 'pet-0', 'name': '수정'}),
      throwsA(predicate((e) => !e.toString().contains('sensitive'))),
    );
    expect(store.rows('pets').single['name'], '모카');
    expect(store.busy, isFalse);
    expect(prefs.getString(PetStore.key), before);
  });

  test(
    'logout discards late response and another account sees no cached pets',
    () async {
      await store.login('a@example.com', 'password-a');
      final pending = Completer<http.Response>();
      override = (request) =>
          request.method == 'POST' && request.url.path.endsWith('/pets')
          ? pending.future
          : Future.value(response({}, 299));
      final saving = store.saveOwned('pets', {'name': '늦은 응답'});
      final rejected = expectLater(saving, throwsException);
      await Future<void>.delayed(Duration.zero);
      await expectLater(
        store.saveOwned('pets', {'name': '중복'}),
        throwsException,
      );
      await store.logout();
      pending.complete(
        response({'id': 'late', 'owner_id': 'a', 'name': '늦은 응답'}),
      );
      await rejected;
      expect(store.rows('pets'), isEmpty);
      override = null;
      await store.login('b@example.com', 'password-b');
      expect(store.user, 'b');
      expect(store.rows('pets'), isEmpty);
    },
  );

  test(
    'online child writes and deletion with references are blocked',
    () async {
      await store.login('a@example.com', 'password-a');
      await store.saveOwned('pets', {'name': '모카'});
      await expectLater(
        store.saveMemoryDay('2022-01-01', '일기', '', false),
        throwsException,
      );
      await expectLater(
        store.saveMemoryPhotos('2022-01-01', ['data:image/png;base64,AA==']),
        throwsException,
      );
      await expectLater(store.joinGroup('dog-walkers'), throwsException);
      expect(prefs.getString(PetStore.key), before);
      store.rows('memoryDays').add({
        'owner': 'a',
        'petId': 'pet-0',
        'date': '2022-01-01',
      });
      final count = requests.length;
      await expectLater(store.deleteOwned('pets', 'pet-0'), throwsException);
      await expectLater(
        store.saveOwned('pets', {'id': 'someone-else', 'name': '탈취'}),
        throwsException,
      );
      expect(requests.length, count);
      expect(store.rows('pets').single['name'], '모카');
    },
  );

  test('server FK delete rejection keeps the pet', () async {
    await store.login('a@example.com', 'password-a');
    await store.saveOwned('pets', {'name': '모카'});
    override = (request) async => request.method == 'DELETE'
        ? response({'code': '23503', 'message': 'foreign key details'}, 409)
        : response({}, 299);
    await expectLater(
      store.deleteOwned('pets', 'pet-0'),
      throwsA(predicate((e) => e.toString().contains('연결된 기록'))),
    );
    expect(store.rows('pets').single['name'], '모카');
  });

  test('profile creation handles a concurrent first login', () async {
    var reads = 0;
    override = (request) async {
      if (!request.url.path.endsWith('/profiles')) return response({}, 299);
      if (request.method == 'GET') {
        return response(reads++ == 0 ? null : {'id': 'a', 'name': '서버 보호자'});
      }
      return response({'code': '23505', 'message': 'duplicate profile'}, 409);
    };
    await store.login('a@example.com', 'password-a');
    expect(store.user, 'a');
    expect(reads, 2);
  });
}
