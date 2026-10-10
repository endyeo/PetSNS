import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pet_sns/main.dart';
import 'package:pet_sns/store.dart';
import 'package:pet_sns/supabase_auth_service.dart';

Map<String, dynamic> _user(String id) => {
  'id': id,
  'aud': 'authenticated',
  'role': 'authenticated',
  'email': '$id@example.com',
  'created_at': '2026-10-10T00:00:00Z',
  'app_metadata': {},
  'user_metadata': {'name': '보호자 $id'},
};

Map<String, dynamic> _session(String id, {bool expired = false}) {
  final expiry =
      DateTime.now().millisecondsSinceEpoch ~/ 1000 + (expired ? -3600 : 3600);
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return {
    'access_token':
        '${encode({'alg': 'HS256', 'typ': 'JWT'})}.${encode({'sub': id, 'exp': expiry})}.fixture',
    'refresh_token': 'fixture-refresh-$id',
    'token_type': 'bearer',
    'expires_in': expired ? -3600 : 3600,
    'expires_at': expiry,
    'user': _user(id),
  };
}

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {
    'content-type': 'application/json',
    'x-supabase-api-version': '2024-01-01',
  },
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  late String before;
  late SupabaseClient client;
  late SupabaseAuthService auth;
  late PetStore store;
  Future<http.Response> Function(http.Request)? handler;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    final local = PetStore(prefs);
    await local.load();
    await local.login('a@example.com', 'local-password', name: '기존 계정');
    await local.saveOwned('pets', {'name': '기존 반려동물'});
    before = prefs.getString(PetStore.key)!;
    local.dispose();
    handler = null;
    client = SupabaseClient(
      'https://fixture.supabase.co',
      'sb_publishable_fixture',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        if (handler != null) return handler!(request);
        if (request.url.path.endsWith('/token')) return _json(_session('a'));
        if (request.url.path.endsWith('/user')) return _json(_user('a'));
        return http.Response('', 204);
      }),
    );
    auth = SupabaseAuthService(client);
    store = PetStore(prefs, auth: auth);
    await store.load();
  });
  tearDown(() async {
    store.dispose();
    auth.dispose();
    await client.dispose();
  });

  test(
    'online identity ignores local session and preserves local records',
    () async {
      expect(store.user, isNull);
      expect(store.rows('pets').single['name'], '기존 반려동물');
      await store.login(' A@EXAMPLE.COM ', 'remote-password');
      expect(store.user, 'a');
      expect(store.account!['name'], '보호자 a');
      expect(
        store.rows('pets').where((p) => p['owner'] == store.user),
        isEmpty,
      );
      expect(prefs.getString(PetStore.key), before);
      await store.logout();
      expect(store.user, isNull);
      expect(client.auth.currentSession, isNull);
      expect(prefs.getString(PetStore.key), before);
    },
  );

  test(
    'wrong server password cannot fall back to matching local credentials',
    () async {
      handler = (request) async => _json({
        'code': 'invalid_credentials',
        'msg': 'sensitive server details fixture',
      }, 400);
      await expectLater(
        store.login('a@example.com', 'local-password'),
        throwsA(
          predicate(
            (e) =>
                e.toString().contains('이메일 또는 비밀번호') &&
                !e.toString().contains('sensitive'),
          ),
        ),
      );
      expect(store.user, isNull);
      expect(prefs.getString(PetStore.key), before);
      await expectLater(Future.sync(store.testLogin), throwsException);
      await expectLater(
        store.login('new@example.com', 'password123', name: '이름'),
        throwsException,
      );
    },
  );

  test(
    'cached session requires server verification and invalid token is cleared',
    () async {
      // This is the same cache bootstrap used by Supabase Flutter at startup.
      // ignore: invalid_use_of_internal_member
      await client.auth.setInitialSession(jsonEncode(_session('a')));
      await Future<void>.delayed(Duration.zero);
      expect(store.user, isNull);
      await auth.restore();
      expect(store.user, 'a');
      handler = (request) async => request.url.path.endsWith('/user')
          ? _json({'code': 'bad_jwt', 'msg': 'invalid'}, 401)
          : http.Response('', 204);
      await auth.restore();
      expect(store.user, isNull);
      expect(client.auth.currentSession, isNull);
      expect(prefs.getString(PetStore.key), before);
    },
  );

  test('restore failure blocks access and retry keeps saved data', () async {
    // ignore: invalid_use_of_internal_member
    await client.auth.setInitialSession(jsonEncode(_session('a')));
    handler = (request) async =>
        throw http.ClientException('sensitive request details');
    await expectLater(
      auth.restore(),
      throwsA(
        predicate(
          (e) =>
              e.toString().contains('연결 상태') &&
              !e.toString().contains('sensitive'),
        ),
      ),
    );
    expect(store.user, isNull);
    expect(client.auth.currentSession, isNotNull);
    handler = null;
    await auth.restore();
    expect(store.user, 'a');
    expect(prefs.getString(PetStore.key), before);
  });

  test(
    'expired cache refreshes before verification and logout affects only this session',
    () async {
      final requests = <http.Request>[];
      handler = (request) async {
        requests.add(request);
        if (request.url.path.endsWith('/token')) return _json(_session('a'));
        if (request.url.path.endsWith('/user')) return _json(_user('a'));
        return http.Response('', 204);
      };
      // ignore: invalid_use_of_internal_member
      await client.auth.setInitialSession(
        jsonEncode(_session('a', expired: true)),
      );
      await auth.restore();
      expect(store.user, 'a');
      expect(requests.first.url.queryParameters['grant_type'], 'refresh_token');
      expect(requests.any((r) => r.url.path.endsWith('/user')), isTrue);
      await store.logout();
      expect(requests.last.url.queryParameters['scope'], 'local');
      expect(store.user, isNull);
    },
  );

  testWidgets(
    'online login has no demo/signup bypass and blocks repeated submissions',
    (tester) async {
      final pending = Completer<http.Response>();
      var calls = 0;
      handler = (request) async {
        calls++;
        return pending.future;
      };
      await tester.pumpWidget(MaterialApp(home: Login(store: store)));
      expect(find.text('테스트로 이용하기'), findsNothing);
      expect(find.text('처음 오셨나요? 회원가입'), findsNothing);
      await tester.enterText(find.byType(TextField).at(0), 'A@EXAMPLE.COM');
      await tester.enterText(find.byType(TextField).at(1), 'remote-password');
      await tester.tap(find.widgetWithText(FilledButton, '로그인'));
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await expectLater(
        store.login('a@example.com', 'remote-password'),
        throwsException,
      );
      expect(calls, 1);
      pending.complete(_json(_session('a')));
      await tester.pumpAndSettle();
      expect(store.user, 'a');
      expect(prefs.getString(PetStore.key), before);
    },
  );

  testWidgets('missing online configuration fails closed with retry', (
    tester,
  ) async {
    supabaseConnection = null;
    await tester.pumpWidget(const PetApp(useSupabase: true));
    await tester.pumpAndSettle();
    expect(find.byType(Login), findsNothing);
    expect(find.text('다시 시도'), findsOneWidget);
    expect(find.textContaining('로그인 서비스를 시작하지 못했습니다'), findsOneWidget);
    expect(prefs.getString(PetStore.key), before);
  });
}
