import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pet_sns/supabase_connection.dart';

void main() {
  const url = 'https://example.supabase.co';
  const key = 'sb_publishable_test';
  final project = Uri.parse(url);

  test('accepts HTTPS project origins and publishable keys', () {
    expect(validateSupabaseConfig(url, key), project);
    expect(validateSupabaseConfig('$url/', key).origin, url);
  });

  test('rejects missing settings and unsafe URLs', () {
    for (final badUrl in [
      '',
      'not a URL',
      'http://example.supabase.co',
      '$url/auth/v1',
      '$url?key=private',
      '$url#private',
      'https://user:private@example.supabase.co',
    ]) {
      expect(() => validateSupabaseConfig(badUrl, key), throwsFormatException);
    }
    expect(() => validateSupabaseConfig(url, ''), throwsFormatException);
  });

  test('rejects privileged keys, JWTs, passwords, and malformed keys', () {
    for (final badKey in [
      'sb_secret_private',
      'eyJhbGciOiJIUzI1NiJ9.service_role.signature',
      'database-password',
      'sb_publishable_',
      'sb_publishable_bad key',
    ]) {
      expect(() => validateSupabaseConfig(url, badKey), throwsFormatException);
    }
  });

  test('missing configuration does not initialize the SDK', () async {
    final result = await initializeSupabase(url: '', publishableKey: key);
    expect(result.initialized, isFalse);
    expect(result.connected, isFalse);
    expect(result.message, contains('SUPABASE_URL is missing'));
  });

  test('connection requires a read-only settings response', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url, project.resolve('/auth/v1/settings'));
      expect(request.headers['apikey'], key);
      expect(request.headers.containsKey('authorization'), isFalse);
      expect(request.followRedirects, isFalse);
      expect(request.body, isEmpty);
      return http.Response('{"external":{},"disable_signup":false}', 200);
    });
    addTearDown(client.close);
    final result = await checkSupabaseConnection(project, key, client: client);
    expect(result.connected, isTrue);
  });

  test(
    'HTTP failures and redirects never count as connected or leak bodies',
    () async {
      for (final status in [301, 401, 403, 404, 429, 500, 503]) {
        final client = MockClient((_) async => http.Response(key, status));
        final result = await checkSupabaseConnection(
          project,
          key,
          client: client,
        );
        client.close();
        expect(result.initialized, isTrue);
        expect(result.connected, isFalse);
        expect(result.message, contains('HTTP $status'));
        expect(result.message, isNot(contains(key)));
      }
    },
  );

  test('HTTP 200 with an unrelated or malformed body is rejected', () async {
    for (final body in ['<html>OK</html>', '{}', '[]']) {
      final client = MockClient((_) async => http.Response(body, 200));
      final result = await checkSupabaseConnection(
        project,
        key,
        client: client,
      );
      client.close();
      expect(result.connected, isFalse);
      expect(result.message, contains('unexpected Auth settings response'));
    }
  });

  test(
    'connection rechecks reject privileged keys before sending requests',
    () async {
      final client = MockClient((_) async {
        fail('Invalid credentials must never be sent.');
      });
      addTearDown(client.close);
      final result = await checkSupabaseConnection(
        project,
        'sb_secret_private',
        client: client,
      );
      expect(result.connected, isFalse);
      expect(result.message, contains('Configuration error'));
      expect(result.message, isNot(contains('sb_secret_private')));
    },
  );

  test('network exceptions are sanitized', () async {
    final client = MockClient((_) async => throw http.ClientException(key));
    addTearDown(client.close);
    final result = await checkSupabaseConnection(project, key, client: client);
    expect(result.connected, isFalse);
    expect(result.message, contains('ClientException'));
    expect(result.message, isNot(contains(key)));
  });

  test('a stalled request times out', () async {
    final client = MockClient((_) => Completer<http.Response>().future);
    addTearDown(client.close);
    final result = await checkSupabaseConnection(
      project,
      key,
      client: client,
      timeout: const Duration(milliseconds: 10),
    );
    expect(result.connected, isFalse);
    expect(result.message, contains('timed out'));
  });
}
