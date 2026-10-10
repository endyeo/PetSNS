import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pet_sns/supabase_connection.dart';

// Opt in with dedicated accounts that have no existing public.profiles row.
// Credentials stay in process environment or an ignored test-only local file.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const url = String.fromEnvironment('SUPABASE_URL');
  const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  final environment = Platform.environment;
  final enabled = environment['PET_SNS_RUN_DB_LIVE'] == '1';

  test(
    'live profiles/pets CRUD and isolation with two ordinary Auth sessions',
    () async {
      final credentialFile = File('config/supabase.test.local.json');
      final localCredentials = credentialFile.existsSync()
          ? jsonDecode(credentialFile.readAsStringSync())
                as Map<String, dynamic>
          : <String, dynamic>{};
      final project = validateSupabaseConfig(url, key);
      final originalOverrides = HttpOverrides.current;
      HttpOverrides.global = null;
      final clients = <_Actor>[];
      final createdProfiles = <_Actor>[];
      final createdPets = <(_Actor, String)>[];
      var assertions = 0;
      void check(bool condition, String label) {
        expect(condition, isTrue, reason: label);
        assertions++;
      }

      try {
        for (final account in ['A', 'B']) {
          final actor = _Actor(project, key);
          clients.add(actor);
          await actor.login(
            environment['PET_SNS_TEST_EMAIL_$account'] ??
                localCredentials['PET_SNS_TEST_EMAIL_$account'] as String?,
            environment['PET_SNS_TEST_PASSWORD_$account'] ??
                localCredentials['PET_SNS_TEST_PASSWORD_$account'] as String?,
          );
        }
        final a = clients[0];
        final b = clients[1];
        check(a.userId != b.userId, 'A and B must be distinct Auth users');
        for (final actor in [a, b]) {
          final response = await actor.request(
            'GET',
            'profiles',
            id: actor.userId,
          );
          check(response.statusCode == 200, 'profiles table must be deployed');
          check(
            _rows(response).isEmpty,
            'Use accounts with no existing profile; do not overwrite existing data',
          );
        }

        for (final entry in [(a, '보호자 A'), (b, '보호자 B')]) {
          final (actor, name) = entry;
          createdProfiles.add(actor);
          final response = await actor.request(
            'POST',
            'profiles',
            body: {'id': actor.userId, 'name': name},
          );
          check(
            response.statusCode == 201 && _rows(response).length == 1,
            'own profile creation',
          );
          final read = await actor.request('GET', 'profiles', id: actor.userId);
          check(
            read.statusCode == 200 && _rows(read).single['name'] == name,
            'own profile reread',
          );
        }

        final suffix =
            '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(0x7fffffff)}';
        final petA = 'petsns-verification-a-$suffix';
        final petB = 'petsns-verification-b-$suffix';
        for (final entry in [(a, petA, '모카'), (b, petB, '루나')]) {
          final (actor, id, name) = entry;
          createdPets.add((actor, id));
          final response = await actor.request(
            'POST',
            'pets',
            body: {
              'id': id,
              'name': name,
              'breed': '테스트 품종',
              'birthday': '2022-04-12',
              'memory_origin_type': 'firstMeeting',
              'memory_origin_date': '2022-05-01',
            },
          );
          check(
            response.statusCode == 201 &&
                _rows(response).single['owner_id'] == actor.userId,
            'own pet creation and default owner',
          );
          final profileUpdate = await actor.request(
            'PATCH',
            'profiles',
            id: actor.userId,
            body: {'name': '수정한 보호자'},
          );
          check(
            profileUpdate.statusCode == 200 && _rows(profileUpdate).length == 1,
            'own profile update',
          );
          final petUpdate = await actor.request(
            'PATCH',
            'pets',
            id: id,
            body: {'name': '수정한 반려동물'},
          );
          check(
            petUpdate.statusCode == 200 && _rows(petUpdate).length == 1,
            'own pet update',
          );
          final profileRead = await actor.request(
            'GET',
            'profiles',
            id: actor.userId,
          );
          check(
            profileRead.statusCode == 200 &&
                _rows(profileRead).single['name'] == '수정한 보호자',
            'updated profile reread',
          );
          final petRead = await actor.request('GET', 'pets', id: id);
          final pet = _rows(petRead).single;
          check(
            petRead.statusCode == 200 &&
                pet['name'] == '수정한 반려동물' &&
                pet['breed'] == '테스트 품종' &&
                pet['birthday'] == '2022-04-12' &&
                pet['memory_origin_type'] == 'firstMeeting' &&
                pet['memory_origin_date'] == '2022-05-01',
            'updated pet reread preserves other fields',
          );
          final parentDelete = await actor.request(
            'DELETE',
            'profiles',
            id: actor.userId,
          );
          check(
            parentDelete.statusCode == 409 &&
                _errorCode(parentDelete) == '23503',
            'profile deletion restricted while pet remains',
          );
        }

        for (final entry in [(a, b, petB), (b, a, petA)]) {
          final (attacker, owner, petId) = entry;
          for (final target in [('profiles', owner.userId), ('pets', petId)]) {
            final (table, id) = target;
            final read = await attacker.request('GET', table, id: id);
            check(
              read.statusCode == 200 && _rows(read).isEmpty,
              'cross-account read hides row',
            );
            for (final method in ['PATCH', 'DELETE']) {
              final response = await attacker.request(
                method,
                table,
                id: id,
                body: method == 'PATCH' ? {'name': 'unauthorized'} : null,
              );
              check(
                response.statusCode == 200 && _rows(response).isEmpty,
                'cross-account write affects zero rows',
              );
            }
            final original = await owner.request('GET', table, id: id);
            check(
              original.statusCode == 200 &&
                  _rows(original).length == 1 &&
                  _rows(original).single['name'] ==
                      (table == 'pets' ? '수정한 반려동물' : '수정한 보호자'),
              'owner row unchanged after denied writes',
            );
          }
          for (final table in ['profiles', 'pets']) {
            if (table == 'pets') createdPets.add((owner, 'spoof-$petId'));
            final response = await attacker.request(
              'POST',
              table,
              body: table == 'profiles'
                  ? {'id': owner.userId, 'name': 'unauthorized'}
                  : {
                      'id': 'spoof-$petId',
                      'owner_id': owner.userId,
                      'name': 'unauthorized',
                    },
            );
            check(
              response.statusCode == 403 && _errorCode(response) == '42501',
              'cross-account creation rejected by RLS',
            );
          }
          for (final entry in [
            ('profiles', attacker.userId, {'id': owner.userId}),
            ('pets', attacker == a ? petA : petB, {'owner_id': owner.userId}),
            ('pets', attacker == a ? petA : petB, {'id': 'changed-$petId'}),
          ]) {
            if (entry.$1 == 'pets') {
              // Also track the possible result of a broken ownership/ID rule.
              createdPets.add((owner, entry.$2));
              createdPets.add((attacker, 'changed-$petId'));
            }
            final response = await attacker.request(
              'PATCH',
              entry.$1,
              id: entry.$2,
              body: entry.$3,
            );
            check(
              response.statusCode == 403 && _errorCode(response) == '42501',
              'client IDs and owner are immutable',
            );
          }
        }

        for (final invalid in [
          {'name': null},
          {'name': ''},
          {'name': 'x' * 61},
          {'name': '테스트', 'breed': 'x' * 81},
          {'name': '테스트', 'birthday': '1989-12-31'},
          {'name': '테스트', 'memory_origin_type': 'firstMeeting'},
          {'name': '테스트', 'memory_origin_date': '2022-05-01'},
          {
            'name': '테스트',
            'memory_origin_type': 'other',
            'memory_origin_date': '2022-05-01',
          },
        ]) {
          // Reuse a known fixture ID; any unexpected successful write stays tracked.
          final response = await a.request(
            'POST',
            'pets',
            body: {'id': petA, ...invalid},
          );
          check(
            response.statusCode == 400 &&
                ['23502', '23514'].contains(_errorCode(response)),
            'invalid pet data rejected',
          );
        }
        for (final name in [null, '', 'x' * 31]) {
          final response = await a.request(
            'PATCH',
            'profiles',
            id: a.userId,
            body: {'name': name},
          );
          check(
            response.statusCode == 400 &&
                ['23502', '23514'].contains(_errorCode(response)),
            'invalid profile name rejected',
          );
        }

        final anonymous = _Actor(project, key);
        clients.add(anonymous);
        for (final target in [('profiles', a.userId), ('pets', petA)]) {
          final (table, id) = target;
          for (final method in ['GET', 'POST', 'PATCH', 'DELETE']) {
            final response = await anonymous.request(
              method,
              table,
              id: method == 'POST' ? null : id,
              body: method == 'POST'
                  ? {'id': id, 'name': 'unauthorized'}
                  : method == 'PATCH'
                  ? {'name': 'unauthorized'}
                  : null,
            );
            check(
              response.statusCode == 401 && _errorCode(response) == '42501',
              'signed-out CRUD rejected',
            );
          }
        }
        for (final entry in [(a, petA), (b, petB)]) {
          final (actor, id) = entry;
          final read = await actor.request('GET', 'pets', id: id);
          check(
            read.statusCode == 200 && _rows(read).single['name'] == '수정한 반려동물',
            'denied writes preserve original pets',
          );
          final deleted = await actor.request('DELETE', 'pets', id: id);
          check(
            deleted.statusCode == 200 && _rows(deleted).length == 1,
            'own pet deletion',
          );
          final after = await actor.request('GET', 'pets', id: id);
          check(
            after.statusCode == 200 && _rows(after).isEmpty,
            'deleted pet absent on reread',
          );
          final profileDelete = await actor.request(
            'DELETE',
            'profiles',
            id: actor.userId,
          );
          check(
            profileDelete.statusCode == 200 && _rows(profileDelete).length == 1,
            'own profile deletion after pet removal',
          );
          final profileAfter = await actor.request(
            'GET',
            'profiles',
            id: actor.userId,
          );
          check(
            profileAfter.statusCode == 200 && _rows(profileAfter).isEmpty,
            'deleted profile absent on reread',
          );
        }
      } finally {
        // Only remove this run's tracked fixtures. Never delete Auth users.
        var cleanupFailed = false;
        for (final entry in createdPets.reversed) {
          try {
            final response = await entry.$1.request(
              'DELETE',
              'pets',
              id: entry.$2,
            );
            cleanupFailed |= response.statusCode != 200;
          } catch (_) {
            cleanupFailed = true;
          }
        }
        for (final actor in createdProfiles.reversed) {
          try {
            final response = await actor.request(
              'DELETE',
              'profiles',
              id: actor.userId,
            );
            cleanupFailed |= response.statusCode != 200;
          } catch (_) {
            cleanupFailed = true;
          }
        }
        for (final client in clients) {
          client.close();
        }
        HttpOverrides.global = originalOverrides;
        expect(
          cleanupFailed,
          isFalse,
          reason:
              'Fixture cleanup failed; inspect dedicated development accounts before rerunning',
        );
      }
      // ignore: avoid_print
      print(
        '[PetSNS DB live] PASS: $assertions API assertions with two Auth sessions; fixture cleanup completed.',
      );
    },
    skip: enabled
        ? false
        : 'Requires PET_SNS_RUN_DB_LIVE=1 and dedicated A/B credentials.',
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

List<Map<String, dynamic>> _rows(http.Response response) =>
    (jsonDecode(response.body) as List).cast<Map<String, dynamic>>();
String? _errorCode(http.Response response) =>
    (jsonDecode(response.body) as Map<String, dynamic>)['code'] as String?;

class _Actor {
  _Actor(this.project, this.key);
  final Uri project;
  final String key;
  final http.Client _client = http.Client();
  String? _token;
  String userId = '';

  Future<void> login(String? email, String? password) async {
    if (email == null ||
        email.isEmpty ||
        password == null ||
        password.isEmpty) {
      throw StateError(
        'Missing dedicated A/B credentials in environment or local test config.',
      );
    }
    final response = await _client
        .post(
          project.resolve('/auth/v1/token?grant_type=password'),
          headers: {'apikey': key, 'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': password}),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw StateError('Test Auth login failed (HTTP ${response.statusCode}).');
    }
    final session = jsonDecode(response.body) as Map<String, dynamic>;
    _token = session['access_token'] as String;
    userId = (session['user'] as Map<String, dynamic>)['id'] as String;
  }

  Future<http.Response> request(
    String method,
    String table, {
    String? id,
    Map<String, dynamic>? body,
  }) async {
    final uri = project
        .resolve('/rest/v1/$table')
        .replace(
          queryParameters: {'select': '*', if (id != null) 'id': 'eq.$id'},
        );
    final request = http.Request(method, uri)
      ..headers.addAll({
        'apikey': key,
        if (_token != null) 'Authorization': 'Bearer $_token',
        'Content-Type': 'application/json',
        'Prefer': 'return=representation',
      });
    if (body != null) request.body = jsonEncode(body);
    return (() async => http.Response.fromStream(
      await _client.send(request),
    ))().timeout(const Duration(seconds: 15));
  }

  void close() => _client.close();
}
