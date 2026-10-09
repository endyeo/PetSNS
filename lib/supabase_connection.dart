import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConnectionResult {
  const SupabaseConnectionResult({
    required this.initialized,
    required this.connected,
    required this.message,
  });

  final bool initialized;
  final bool connected;
  final String message;
}

Uri validateSupabaseConfig(String url, String publishableKey) {
  if (url.isEmpty) {
    throw const FormatException('SUPABASE_URL is missing.');
  }
  if (publishableKey.isEmpty) {
    throw const FormatException('SUPABASE_PUBLISHABLE_KEY is missing.');
  }
  final uri = Uri.tryParse(url);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      (uri.path.isNotEmpty && uri.path != '/') ||
      uri.hasQuery ||
      uri.hasFragment) {
    throw const FormatException(
      'SUPABASE_URL must be an HTTPS project origin without credentials, '
      'a path, query, or fragment.',
    );
  }
  // Accept only the requested client key type, never privileged keys or JWTs.
  if (!RegExp(r'^sb_publishable_[A-Za-z0-9_-]+$').hasMatch(publishableKey)) {
    throw const FormatException(
      'SUPABASE_PUBLISHABLE_KEY must be an sb_publishable_ key. '
      'Secret keys, service_role keys, and DB passwords are not allowed.',
    );
  }
  return uri;
}

Future<SupabaseConnectionResult> initializeSupabase({
  String url = const String.fromEnvironment('SUPABASE_URL'),
  String publishableKey = const String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  ),
}) async {
  Uri uri;
  try {
    uri = validateSupabaseConfig(url, publishableKey);
  } on FormatException catch (error) {
    return SupabaseConnectionResult(
      initialized: false,
      connected: false,
      message: 'Configuration error: ${error.message}',
    );
  }
  try {
    await Supabase.initialize(
      url: uri.origin,
      publishableKey: publishableKey,
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        persistSession: false,
        autoRefreshToken: false,
        detectSessionInUri: false,
      ),
    );
  } catch (error) {
    // SDK/network exceptions may contain request details. Do not log their text.
    return SupabaseConnectionResult(
      initialized: false,
      connected: false,
      message:
          'SDK initialization failed (${error.runtimeType}). '
          'Check configuration and platform setup.',
    );
  }
  return checkSupabaseConnection(uri, publishableKey);
}

Future<SupabaseConnectionResult> checkSupabaseConnection(
  Uri project,
  String publishableKey, {
  http.Client? client,
  Duration timeout = const Duration(seconds: 10),
}) async {
  try {
    validateSupabaseConfig(project.toString(), publishableKey);
  } on FormatException catch (error) {
    return SupabaseConnectionResult(
      initialized: true,
      connected: false,
      message: 'Configuration error: ${error.message}',
    );
  }
  final connection = client ?? http.Client();
  String message;
  try {
    // This checks the gateway's key validation without reading or writing rows.
    final request = http.Request('GET', project.resolve('/auth/v1/settings'))
      ..followRedirects = false
      ..headers['apikey'] = publishableKey;
    final response = await (() async {
      return http.Response.fromStream(await connection.send(request));
    })().timeout(timeout);
    if (response.statusCode == 200) {
      final settings = jsonDecode(response.body);
      if (settings is! Map ||
          settings['external'] is! Map ||
          settings['disable_signup'] is! bool) {
        throw const FormatException('Unexpected Auth settings response.');
      }
      return const SupabaseConnectionResult(
        initialized: true,
        connected: true,
        message:
            'Connected: SDK initialized; Auth settings GET returned HTTP 200.',
      );
    }
    final reason = switch (response.statusCode) {
      401 || 403 => 'Check the project URL and Publishable Key pairing.',
      404 => 'Check the project URL and Auth endpoint.',
      429 => 'Rate limited. Retry later.',
      >= 500 => 'Project service unavailable. Check project status.',
      _ => 'Unexpected response. Check the project URL and gateway.',
    };
    message = 'Connection check failed (HTTP ${response.statusCode}). $reason';
  } on TimeoutException {
    message = 'Connection check timed out. Check network and project status.';
  } on FormatException {
    message =
        'Connection check failed: unexpected Auth settings response. '
        'Check the project URL.';
  } catch (error) {
    message =
        'Connection check failed (${error.runtimeType}). '
        'Check network, DNS, TLS, and browser CORS.';
  } finally {
    if (client == null) connection.close();
  }
  return SupabaseConnectionResult(
    initialized: true,
    connected: false,
    message: message,
  );
}
