import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pet_sns/store.dart';
import 'package:pet_sns/supabase_auth_service.dart';
import 'package:pet_sns/supabase_pet_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'real app pet CRUD, independent clients, A/B RLS and local preservation',
    () async {
      final credentials =
          jsonDecode(File('config/supabase.test.local.json').readAsStringSync())
              as Map<String, dynamic>;
      const url = String.fromEnvironment('SUPABASE_URL');
      const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final local = PetStore(prefs);
      await local.load();
      await local.testLogin();
      final before = prefs.getString(PetStore.key);
      local.dispose();
      final overrides = HttpOverrides.current;
      HttpOverrides.global = null;
      final clients = <SupabaseClient>[];
      final auths = <SupabaseAuthService>[];
      final stores = <PetStore>[];
      final created = <String>[];
      final createdProfiles = <SupabaseClient>[];
      var assertions = 0;
      void check(bool condition, String label) {
        expect(condition, isTrue, reason: label);
        assertions++;
      }

      SupabaseClient newClient() {
        final client = SupabaseClient(
          url,
          key,
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        );
        clients.add(client);
        return client;
      }

      Future<PetStore> start(SupabaseClient client, String suffix) async {
        final auth = SupabaseAuthService(client);
        auths.add(auth);
        final store = PetStore(
          prefs,
          auth: auth,
          petRepository: SupabasePetRepository(client),
        );
        stores.add(store);
        await store.load();
        await auth.login(
          credentials['PET_SNS_TEST_EMAIL_$suffix'],
          credentials['PET_SNS_TEST_PASSWORD_$suffix'],
        );
        final profile = await client
            .from('profiles')
            .select('id')
            .eq('id', auth.account!['id'])
            .maybeSingle();
        if (profile == null) createdProfiles.add(client);
        await store.login(
          credentials['PET_SNS_TEST_EMAIL_$suffix'],
          credentials['PET_SNS_TEST_PASSWORD_$suffix'],
        );
        return store;
      }

      final a = newClient();
      final b = newClient();
      try {
        final storeA = await start(a, 'A');
        final storeB = await start(b, 'B');
        check(
          storeA.user != null &&
              storeB.user != null &&
              storeA.user != storeB.user,
          'two distinct ordinary Auth users',
        );
        check(
          storeA.rows('pets').isEmpty && storeB.rows('pets').isEmpty,
          'dedicated accounts have no preexisting pets',
        );
        check(
          prefs.getString(PetStore.key) == before,
          'local records preserved after loading',
        );
        await storeA.saveOwned('pets', {
          'name': 'DB 연결 검증 동물',
          'breed': '테스트',
          'birthday': '2022-04-12',
        });
        final petId = storeA.rows('pets').single['id'] as String;
        created.add(petId);
        check(
          storeA.rows('pets').single['owner'] == storeA.user,
          'server supplies owner',
        );
        await storeA.setMemoryOrigin(
          'firstMeeting',
          DateTime(2022, 5, 1),
          petId: petId,
        );
        await storeA.saveOwned('pets', {'id': petId, 'name': 'DB 연결 수정 확인'});
        final a2 = newClient();
        final storeA2 = await start(a2, 'A');
        check(
          storeA2.rows('pets').single['id'] == petId,
          'independent app instance reads the same ID',
        );
        check(
          storeA2.rows('pets').single['name'] == 'DB 연결 수정 확인',
          'independent instance reads updated name',
        );
        check(
          storeA2.rows('pets').single['birthday'] == '2022-04-12',
          'birthday preserved',
        );
        check(
          storeA2.rows('pets').single['memoryOriginDate'] == '2022-05-01',
          'Day 0 preserved',
        );
        check(
          storeA2.rows('pets').single['memoryOriginType'] == 'firstMeeting',
          'Day 0 type preserved',
        );
        check(storeB.rows('pets').isEmpty, 'B app cannot see A pet');
        check(
          (await b.from('pets').select().eq('id', petId)).isEmpty,
          'B direct read returns zero rows',
        );
        check(
          (await b.from('pets').update({'name': '금지'}).eq('id', petId).select())
              .isEmpty,
          'B direct update affects zero rows',
        );
        check(
          (await b.from('pets').delete().eq('id', petId).select()).isEmpty,
          'B direct delete affects zero rows',
        );
        await expectLater(
          b.from('pets').insert({'name': '금지', 'owner_id': storeA.user}),
          throwsA(isA<PostgrestException>()),
        );
        assertions++;
        await expectLater(
          a.from('profiles').delete().eq('id', storeA.user!),
          throwsA(
            predicate((e) => e is PostgrestException && e.code == '23503'),
          ),
        );
        assertions++;
        await expectLater(
          storeA.saveMemoryDay('2022-05-01', '금지', '', false),
          throwsException,
        );
        assertions++;
        check(
          prefs.getString(PetStore.key) == before,
          'blocked child writes preserve original JSON',
        );
        final signedOut = newClient();
        await expectLater(
          signedOut.from('pets').select(),
          throwsA(isA<PostgrestException>()),
        );
        assertions++;
        await storeA2.deleteOwned('pets', petId);
        created.remove(petId);
        check(
          (await SupabasePetRepository(a).list(storeA.user!)).isEmpty,
          'deletion visible to independent client',
        );
        await storeA.logout();
        check(
          storeA.user == null && storeA.rows('pets').isEmpty,
          'logout clears server pet cache',
        );
        check(
          prefs.getString(PetStore.key) == before,
          'all local records preserved byte for byte',
        );
      } finally {
        // Only this run's fixtures are eligible for cleanup. Auth users remain.
        try {
          final cleanup = clients
              .where(
                (c) =>
                    c.auth.currentUser?.email ==
                    credentials['PET_SNS_TEST_EMAIL_A'],
              )
              .firstOrNull;
          if (cleanup != null) {
            for (final id in created) {
              await cleanup.from('pets').delete().eq('id', id);
            }
          }
          for (final client in createdProfiles) {
            // A may already be signed out; another A session can clean its profile.
            final owner = client.auth.currentUser?.id;
            final active = owner == null
                ? clients.firstWhere(
                    (c) =>
                        c.auth.currentUser?.email ==
                        credentials['PET_SNS_TEST_EMAIL_A'],
                  )
                : client;
            final id = active.auth.currentUser!.id;
            if ((await active.from('pets').select('id').eq('owner_id', id))
                .isEmpty) {
              await active.from('profiles').delete().eq('id', id);
            }
          }
        } finally {
          for (final store in stores) {
            store.dispose();
          }
          for (final auth in auths) {
            auth.dispose();
          }
          for (final client in clients) {
            try {
              await client.auth.signOut(scope: SignOutScope.local);
            } finally {
              await client.dispose();
            }
          }
          HttpOverrides.global = overrides;
        }
      }
      // ignore: avoid_print
      print(
        '[PetSNS pets live] PASS: $assertions assertions; real app CRUD, two users, independent clients, RLS, cleanup, local preservation.',
      );
    },
    skip: Platform.environment['PET_SNS_RUN_PETS_LIVE'] == '1'
        ? false
        : 'Requires dedicated A/B accounts and PET_SNS_RUN_PETS_LIVE=1.',
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
