import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pet_sns/main.dart';
import 'package:pet_sns/design_system.dart';
import 'package:pet_sns/store.dart';
import 'package:pet_sns/supabase_auth_service.dart';
import 'package:pet_sns/supabase_pet_repository.dart';
import 'package:pet_sns/supabase_memory_repository.dart';

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
      'user_metadata': {},
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
  late SharedPreferences prefs;
  late SupabaseClient client;
  late SupabaseAuthService auth;
  late PetStore store;
  late String before;
  late List<Map<String, dynamic>> days;
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
    days = [];
    requests = [];
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
          final path = request.url.path;
          if (path.endsWith('/token')) {
            return response(
              session(
                (jsonDecode(request.body)['email'] as String).split('@').first,
              ),
            );
          }
          if (path.endsWith('/logout')) return http.Response('', 204);
          final owner = client.auth.currentUser!.id;
          if (path.endsWith('/profiles')) {
            return response({'id': owner, 'name': '서버 보호자'});
          }
          if (path.endsWith('/pets')) {
            return response([
              for (final id in ['pet-1', 'pet-2'])
                {
                  'id': id,
                  'owner_id': owner,
                  'name': id,
                  'breed': '',
                  'birthday': null,
                  'photo': null,
                  'memory_origin_type': 'firstMeeting',
                  'memory_origin_date': '2022-01-01',
                },
            ]);
          }
          if (path.endsWith('/rpc/save_memory_day')) {
            final p = jsonDecode(request.body) as Map<String, dynamic>;
            final row = {
              'owner_id': owner,
              'pet_id': p['p_pet_id'],
              'record_date': p['p_date'],
              'title': p['p_title'],
              'note': p['p_note'],
              'anniversary': p['p_anniversary'],
            };
            days.removeWhere(
              (d) =>
                  d['owner_id'] == owner &&
                  d['pet_id'] == row['pet_id'] &&
                  d['record_date'] == row['record_date'],
            );
            days.add(row);
            return response(row);
          }
          if (path.endsWith('/memory_days')) {
            if (request.method == 'DELETE') {
              days.removeWhere(
                (d) =>
                    d['owner_id'] == owner &&
                    'eq.${d['pet_id']}' ==
                        request.url.queryParameters['pet_id'] &&
                    'eq.${d['record_date']}' ==
                        request.url.queryParameters['record_date'],
              );
              return http.Response('', 204);
            }
            return response(days.where((d) => d['owner_id'] == owner).toList());
          }
          throw StateError('Unexpected request');
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
    store = PetStore(
      prefs,
      auth: auth,
      petRepository: SupabasePetRepository(client),
      memoryRepository: SupabaseMemoryRepository(client),
      clock: () => DateTime.utc(2026, 10, 10, 0),
    );
    await store.load();
  });
  tearDown(() async {
    store.dispose();
    auth.dispose();
    await client.dispose();
  });

  test(
    'server journals update one row, separate pets/dates and preserve local JSON',
    () async {
      await store.login('a@example.com', 'password-a');
      await store.saveMemoryDay(
        '2022-01-01',
        ' 제목 ',
        ' 메모 ',
        true,
        petId: 'pet-1',
      );
      await store.saveMemoryDay(
        '2022-01-01',
        '수정',
        '긴 메모',
        false,
        petId: 'pet-1',
      );
      expect(days.length, 1);
      expect(store.memoryDay('2022-01-01', petId: 'pet-1')['title'], '수정');
      expect(
        store.memoryDay('2022-01-01', petId: 'pet-1')['anniversary'],
        isFalse,
      );
      await store.saveMemoryDay('1990-01-01', '', '', false, petId: 'pet-2');
      await store.saveMemoryDay(
        '2022-01-02',
        '다른 날짜',
        '',
        true,
        petId: 'pet-1',
      );
      expect(store.rows('memoryDays').length, 3);
      expect(prefs.getString(PetStore.key), before);
      await store.deleteMemoryDay('2022-01-01', petId: 'pet-1');
      expect(store.rows('memoryDays').length, 2);
      expect(days.length, 2);
      expect(store.memoryDay('2022-01-01', petId: 'pet-1')['title'], '');
      expect(prefs.getString(PetStore.key), before);
    },
  );

  test(
    'invalid calendar/future dates and unknown pets are rejected before API calls',
    () async {
      await store.login('a@example.com', 'password-a');
      final count = requests.length;
      for (final date in [
        '1989-12-31',
        '2026-10-11',
        '2026-02-30',
        'not-a-date',
        '2026-10-10T00:00:00',
      ]) {
        await expectLater(
          store.saveMemoryDay(date, '', '', false, petId: 'pet-1'),
          throwsException,
        );
      }
      await expectLater(
        store.saveMemoryDay('2022-01-01', '', '', false, petId: 'foreign-pet'),
        throwsException,
      );
      expect(requests.length, count);
      expect(store.busy, isFalse);
      expect(prefs.getString(PetStore.key), before);
    },
  );

  test(
    'journal load failure blocks home and retry loads server data',
    () async {
      override = (request) async => request.url.path.endsWith('/memory_days')
          ? response({'message': 'private server text'}, 400)
          : response({}, 299);
      await expectLater(
        store.login('a@example.com', 'password-a'),
        throwsException,
      );
      expect(store.user, isNull);
      expect(store.rows('pets'), isEmpty);
      expect(store.rows('memoryDays'), isEmpty);
      override = null;
      days.add({
        'owner_id': 'a',
        'pet_id': 'pet-1',
        'record_date': '2022-01-01',
        'title': '서버 기록',
        'note': '',
        'anniversary': false,
      });
      await store.login('a@example.com', 'password-a');
      expect(store.user, 'a');
      expect(store.memoryDay('2022-01-01', petId: 'pet-1')['title'], '서버 기록');
      expect(prefs.getString(PetStore.key), before);
    },
  );

  test(
    'failed save/delete preserve cache and remove sensitive server messages',
    () async {
      await store.login('a@example.com', 'password-a');
      await store.saveMemoryDay('2022-01-01', '원본', '', false, petId: 'pet-1');
      override = (request) async => request.method != 'GET'
          ? response({'code': '42501', 'message': 'private server text'}, 403)
          : response({}, 299);
      await expectLater(
        store.saveMemoryDay('2022-01-01', '실패', '', true, petId: 'pet-1'),
        throwsA(predicate((e) => !e.toString().contains('private'))),
      );
      await expectLater(
        store.deleteMemoryDay('2022-01-01', petId: 'pet-1'),
        throwsException,
      );
      expect(store.memoryDay('2022-01-01', petId: 'pet-1')['title'], '원본');
      expect(store.rows('memoryDays').length, 1);
      await expectLater(
        store.saveOwned('memories', {
          'petId': 'pet-1',
          'date': '2022-01-01',
          'title': '로컬 사진 글',
          'photo': 'data:image/png;base64,AA==',
        }),
        throwsException,
      );
      expect(store.memoryDay('2022-01-01', petId: 'pet-1')['title'], '원본');
      expect(store.busy, isFalse);
      expect(prefs.getString(PetStore.key), before);
    },
  );

  test(
    'logout discards pending journal response and rejects overlapping writes',
    () async {
      await store.login('a@example.com', 'password-a');
      final pending = Completer<http.Response>();
      override = (request) => request.url.path.endsWith('/rpc/save_memory_day')
          ? pending.future
          : Future.value(response({}, 299));
      final saving = store.saveMemoryDay(
        '2022-01-01',
        '늦은 응답',
        '',
        false,
        petId: 'pet-1',
      );
      final rejected = expectLater(saving, throwsException);
      await Future<void>.delayed(Duration.zero);
      await expectLater(
        store.saveMemoryDay('2022-01-01', '중복', '', false, petId: 'pet-1'),
        throwsException,
      );
      await store.logout();
      pending.complete(
        response({
          'owner_id': 'a',
          'pet_id': 'pet-1',
          'record_date': '2022-01-01',
          'title': '늦은 응답',
          'note': '',
          'anniversary': false,
        }),
      );
      await rejected;
      expect(store.rows('memoryDays'), isEmpty);
      override = null;
      await store.login('b@example.com', 'password-b');
      expect(store.rows('memoryDays'), isEmpty);
      expect(prefs.getString(PetStore.key), before);
    },
  );

  test('history beyond one API page is loaded without truncation', () async {
    var pages = 0;
    override = (request) async {
      if (!request.url.path.endsWith('/memory_days')) return response({}, 299);
      pages++;
      final offset = int.parse(request.url.queryParameters['offset'] ?? '0');
      expect(request.url.queryParameters['limit'], '500');
      return response([
        for (var i = offset; i < (offset == 0 ? 500 : 501); i++)
          {
            'owner_id': 'a',
            'pet_id': 'pet-1',
            'record_date': dayKey(DateTime(2000, 1, 1).add(Duration(days: i))),
            'title': '기록 $i',
            'note': '',
            'anniversary': false,
          },
      ]);
    };
    await store.login('a@example.com', 'password-a');
    expect(pages, 2);
    expect(store.rows('memoryDays').length, 501);
    expect(store.rows('memoryDays').last['title'], '기록 500');
  });

  testWidgets(
    'journal UI saves, cancel preserves and confirmed deletion clears only that day',
    (tester) async {
      await store.login('a@example.com', 'password-a');
      final date = dayKey(korea(store.clock()));
      await store.saveMemoryDay(date, '', '', false, petId: 'pet-1');
      await store.saveMemoryDay(
        '2022-01-01',
        '다른 날짜',
        '',
        false,
        petId: 'pet-1',
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: petTheme,
          home: Home(store: store),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('추억'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(TextButton, '하루 기록'));
      await tester.tap(find.widgetWithText(TextButton, '하루 기록'));
      await tester.pumpAndSettle();
      final dialog = find.byType(AlertDialog);
      await tester.enterText(
        find.descendant(of: dialog, matching: find.byType(TextField)).first,
        '화면 저장',
      );
      await tester.tap(find.widgetWithText(FilledButton, '저장'));
      await tester.pumpAndSettle();
      expect(store.memoryDay(date, petId: 'pet-1')['title'], '화면 저장');
      await tester.ensureVisible(find.widgetWithText(TextButton, '수정'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '수정'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('글 수정'));
      await tester.tap(find.text('글 수정'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '삭제'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '취소'));
      await tester.pumpAndSettle();
      expect(store.memoryDay(date, petId: 'pet-1')['title'], '화면 저장');
      await tester.tap(find.widgetWithText(TextButton, '삭제'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '삭제'));
      await tester.pumpAndSettle();
      expect(store.memoryDay(date, petId: 'pet-1')['title'], '');
      expect(store.memoryDay('2022-01-01', petId: 'pet-1')['title'], '다른 날짜');
      expect(prefs.getString(PetStore.key), before);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
