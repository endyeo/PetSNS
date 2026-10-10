import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pet_sns/store.dart';
import 'package:pet_sns/supabase_auth_service.dart';
import 'package:pet_sns/supabase_connection.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final enabled = Platform.environment['PET_SNS_RUN_AUTH_LIVE'] == '1';
  test(
    'real login, refresh, SDK restart, logout and A/B isolation preserve local data',
    () async {
      final credentials =
          jsonDecode(File('config/supabase.test.local.json').readAsStringSync())
              as Map<String, dynamic>;
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final local = PetStore(prefs);
      await local.load();
      await local.testLogin();
      final before = prefs.getString(PetStore.key);
      local.dispose();
      final overrides = HttpOverrides.current;
      HttpOverrides.global = null;
      SupabaseAuthService? auth;
      PetStore? store;
      var initialized = false;
      var assertions = 0;
      void check(bool condition, String label) {
        expect(condition, isTrue, reason: label);
        assertions++;
      }

      const url = String.fromEnvironment('SUPABASE_URL');
      final sessionKey =
          'sb-${Uri.parse(url).host.split('.').first}-auth-token';
      Future<void> waitForStorage(bool exists) async {
        for (var attempt = 0; attempt < 100; attempt++) {
          if (prefs.containsKey(sessionKey) == exists) return;
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
        fail('SDK session persistence did not finish');
      }

      Future<void> start() async {
        final result = await initializeSupabase();
        initialized = result.initialized;
        check(
          result.initialized && result.connected,
          'real project initialization',
        );
        auth = SupabaseAuthService(Supabase.instance.client);
        await auth!.restore();
        store = PetStore(prefs, auth: auth);
        await store!.load();
      }

      Future<void> restart() async {
        store?.dispose();
        store = null;
        auth?.dispose();
        auth = null;
        await Supabase.instance.dispose();
        initialized = false;
        await start();
      }

      try {
        await start();
        check(
          store!.user == null,
          'local test session cannot authorize online account',
        );
        check(
          prefs.getString(PetStore.key) == before,
          'startup preserves original local data',
        );
        await expectLater(
          store!.login(
            credentials['PET_SNS_TEST_EMAIL_A'] as String,
            'intentionally-wrong-test-password',
          ),
          throwsException,
        );
        check(store!.user == null, 'wrong password rejected');
        await store!.login(
          credentials['PET_SNS_TEST_EMAIL_A'] as String,
          credentials['PET_SNS_TEST_PASSWORD_A'] as String,
        );
        final idA = store!.user;
        check(
          idA != null && idA == Supabase.instance.client.auth.currentUser!.id,
          'A uses real Auth identity',
        );
        check(
          store!.rows('pets').where((p) => p['owner'] == store!.user).isEmpty,
          'A cannot adopt local demo pets',
        );
        check(
          prefs.getString(PetStore.key) == before,
          'login does not rewrite local storage',
        );
        await waitForStorage(true);
        check(
          prefs.containsKey(sessionKey),
          'SDK session persisted separately',
        );
        final refreshed = await Supabase.instance.client.auth.refreshSession();
        check(
          refreshed.session != null && refreshed.user!.id == idA,
          'real refresh token accepted',
        );
        await restart();
        check(
          store!.user == idA,
          'session restored after SDK restart and server verification',
        );
        check(
          prefs.getString(PetStore.key) == before,
          'restart preserves local data',
        );
        await store!.logout();
        check(
          store!.user == null &&
              Supabase.instance.client.auth.currentSession == null,
          'logout clears current session',
        );
        await waitForStorage(false);
        check(
          !prefs.containsKey(sessionKey),
          'logout removes persisted SDK session',
        );
        await restart();
        check(store!.user == null, 'logout survives restart');
        await store!.login(
          credentials['PET_SNS_TEST_EMAIL_B'] as String,
          credentials['PET_SNS_TEST_PASSWORD_B'] as String,
        );
        check(
          store!.user != null && store!.user != idA,
          'B gets a distinct real identity',
        );
        check(
          store!.rows('pets').where((p) => p['owner'] == store!.user).isEmpty,
          'B cannot adopt local demo pets',
        );
        await store!.logout();
        await waitForStorage(false);
        check(
          prefs.getString(PetStore.key) == before,
          'all original local records and local session preserved',
        );
      } finally {
        try {
          if (initialized) {
            await Supabase.instance.client.auth.signOut(
              scope: SignOutScope.local,
            );
          }
        } finally {
          store?.dispose();
          auth?.dispose();
          if (initialized) await Supabase.instance.dispose();
          HttpOverrides.global = overrides;
        }
      }
      // ignore: avoid_print
      print(
        '[PetSNS Auth live] PASS: $assertions assertions; two real users, refresh, SDK restart, logout, local records preserved.',
      );
    },
    skip: enabled
        ? false
        : 'Requires PET_SNS_RUN_AUTH_LIVE=1 and dedicated A/B accounts.',
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
