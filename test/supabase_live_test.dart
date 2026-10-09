import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pet_sns/store.dart';
import 'package:pet_sns/supabase_connection.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const configured =
      bool.hasEnvironment('SUPABASE_URL') &&
      bool.hasEnvironment('SUPABASE_PUBLISHABLE_KEY');

  test(
    'live initialization and project access preserve local records',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = PetStore(prefs);
      await store.load();
      await store.testLogin();
      final before = Map<String, Object>.fromEntries(
        prefs.getKeys().map((key) => MapEntry(key, prefs.get(key)!)),
      );
      final overrides = HttpOverrides.current;
      // This opt-in test needs real HTTP instead of Flutter's test HTTP override.
      HttpOverrides.global = null;
      try {
        final result = await initializeSupabase();
        expect(result.initialized, isTrue, reason: result.message);
        expect(result.connected, isTrue, reason: result.message);
        expect(Supabase.instance.isInitialized, isTrue);
        expect(Supabase.instance.client.auth.currentSession, isNull);
        expect(prefs.getKeys(), before.keys.toSet());
        for (final entry in before.entries) {
          expect(prefs.get(entry.key), entry.value);
        }
        final restored = PetStore(prefs);
        await restored.load();
        expect(restored.data, store.data);
        final rejected = await checkSupabaseConnection(
          Uri.parse(const String.fromEnvironment('SUPABASE_URL')),
          'sb_publishable_invalid_key_for_connection_test',
        );
        expect(rejected.connected, isFalse);
        expect(rejected.message, matches(r'HTTP (401|403)'));
        // ignore: avoid_print
        print(
          '[PetSNS live verification] ${result.message} Wrong key rejected.',
        );
      } finally {
        await Supabase.instance.dispose();
        HttpOverrides.global = overrides;
      }
    },
    skip: configured ? false : 'Requires external Supabase settings.',
  );
}
