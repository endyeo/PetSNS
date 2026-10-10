import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pet_sns/store.dart';
import 'package:pet_sns/supabase_auth_service.dart';
import 'package:pet_sns/supabase_pet_repository.dart';
import 'package:pet_sns/supabase_memory_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'real journals, cross-client reads, RLS, concurrent upsert and restrictive FK',
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
      final clients = <SupabaseClient>[];
      final auths = <SupabaseAuthService>[];
      final stores = <PetStore>[];
      final createdPets = <String>[];
      final createdProfiles = <String>[];
      var assertions = 0;
      void check(bool condition, String label) {
        expect(condition, isTrue, reason: label);
        assertions++;
      }

      Future<void> denied(
        Future<dynamic> request,
        String label, {
        String? code,
      }) async {
        await expectLater(
          request,
          throwsA(
            predicate(
              (e) =>
                  e is PostgrestException && (code == null || e.code == code),
            ),
          ),
          reason: label,
        );
        assertions++;
      }

      SupabaseClient newClient() {
        final client = SupabaseClient(
          const String.fromEnvironment('SUPABASE_URL'),
          const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        );
        clients.add(client);
        return client;
      }

      Future<PetStore> start(SupabaseClient client, String suffix) async {
        await client.auth.signInWithPassword(
          email: credentials['PET_SNS_TEST_EMAIL_$suffix'],
          password: credentials['PET_SNS_TEST_PASSWORD_$suffix'],
        );
        final owner = client.auth.currentUser!.id;
        final profile = await client
            .from('profiles')
            .select('id')
            .eq('id', owner)
            .maybeSingle();
        if (profile == null) createdProfiles.add(owner);
        final auth = SupabaseAuthService(client);
        auths.add(auth);
        await auth.restore();
        final store = PetStore(
          prefs,
          auth: auth,
          petRepository: SupabasePetRepository(client),
          memoryRepository: SupabaseMemoryRepository(client),
        );
        stores.add(store);
        await store.load();
        return store;
      }

      final a = newClient();
      final b = newClient();
      try {
        final storeA = await start(a, 'A');
        final storeB = await start(b, 'B');
        check(
          storeA.user != storeB.user &&
              storeA.user != null &&
              storeB.user != null,
          'distinct ordinary users',
        );
        check(
          storeA.rows('pets').isEmpty &&
              storeB.rows('pets').isEmpty &&
              storeA.rows('memoryDays').isEmpty &&
              storeB.rows('memoryDays').isEmpty,
          'dedicated fixtures initially empty',
        );
        for (final name in ['일기 검증 동물 1', '일기 검증 동물 2']) {
          await storeA.saveOwned('pets', {'name': name});
          final id =
              storeA.rows('pets').firstWhere((pet) => pet['name'] == name)['id']
                  as String;
          createdPets.add(id);
        }
        final pet = createdPets[0];
        final other = createdPets[1];
        final a2 = newClient();
        final storeA2 = await start(a2, 'A');
        check(
          storeA2.rows('memoryDays').isEmpty,
          'second client loaded before journal creation',
        );
        await storeA.saveMemoryDay(
          '1990-01-01',
          ' 初日 ',
          ' 메모 ',
          true,
          petId: pet,
        );
        await storeA.saveMemoryDay(
          '1990-01-01',
          '수정 제목',
          '수정 메모',
          false,
          petId: pet,
        );
        var rows = await a2.from('memory_days').select().eq('pet_id', pet);
        check(rows.length == 1, 'repeated app save keeps one row');
        check(
          rows.single['title'] == '수정 제목' &&
              rows.single['note'] == '수정 메모' &&
              rows.single['anniversary'] == false,
          'independent client reads edited fields',
        );
        check(
          rows.single['owner_id'] == storeA.user,
          'owner set by server Auth',
        );
        await storeA.saveMemoryDay('1990-01-01', '', '', false, petId: other);
        final longNote = List.filled(10000, '가').join();
        await storeA.saveMemoryDay(
          '1990-01-02',
          '긴 기록',
          longNote,
          true,
          petId: pet,
        );
        check(
          (await SupabaseMemoryRepository(a2).list(storeA.user!)).length == 3,
          'pets and dates separated',
        );
        check(
          (await a2.from('memory_days').select().eq('pet_id', other))
                  .single['title'] ==
              '',
          'empty photo-free journal accepted',
        );
        check(
          (await a2
                      .from('memory_days')
                      .select()
                      .eq('pet_id', pet)
                      .eq('record_date', '1990-01-02'))
                  .single['note'] ==
              longNote,
          'long text preserved without a new limit',
        );
        await Future.wait([
          SupabaseMemoryRepository(
            a,
          ).save(pet, '1990-01-01', '동시 A', '', false),
          SupabaseMemoryRepository(
            a2,
          ).save(pet, '1990-01-01', '동시 A2', '', true),
        ]);
        rows = await a
            .from('memory_days')
            .select()
            .eq('pet_id', pet)
            .eq('record_date', '1990-01-01');
        check(
          rows.length == 1 && ['동시 A', '동시 A2'].contains(rows.single['title']),
          'concurrent saves yield one row',
        );
        check(
          rows.single['anniversary'] == (rows.single['title'] == '동시 A2'),
          'concurrent fields committed together',
        );
        final reload = newClient();
        final restored = await start(reload, 'A');
        check(
          restored.rows('memoryDays').length == 3,
          'new app store reads all server journals',
        );
        check(
          restored.memoryDay('1990-01-02', petId: pet)['note'] == longNote,
          'new app store preserves journal text',
        );
        check(
          (await SupabaseMemoryRepository(b).list(storeB.user!)).isEmpty,
          'B cannot read A journals',
        );
        check(
          (await b
                  .from('memory_days')
                  .update({'title': '금지'})
                  .eq('pet_id', pet)
                  .select())
              .isEmpty,
          'B direct update affects zero rows',
        );
        check(
          (await b.from('memory_days').delete().eq('pet_id', pet).select())
              .isEmpty,
          'B direct delete affects zero rows',
        );
        await denied(
          b.rpc(
            'save_memory_day',
            params: {
              'p_pet_id': pet,
              'p_date': '1990-01-01',
              'p_title': '금지',
              'p_note': '',
              'p_anniversary': false,
            },
          ),
          'B RPC cannot overwrite A journal',
        );
        await denied(
          b.rpc(
            'save_memory_day',
            params: {
              'p_pet_id': pet,
              'p_date': '1990-01-03',
              'p_title': '금지',
              'p_note': '',
              'p_anniversary': false,
            },
          ),
          'B cannot attach a new journal to A pet',
          code: '23503',
        );
        await denied(
          b.from('memory_days').insert({
            'pet_id': pet,
            'owner_id': storeA.user,
            'record_date': '1990-01-03',
          }),
          'B cannot spoof A ownership',
          code: '42501',
        );
        await denied(
          a
              .from('memory_days')
              .update({'owner_id': storeB.user})
              .eq('pet_id', pet),
          'journal owner immutable',
          code: '42501',
        );
        await denied(
          a.from('memory_days').update({'pet_id': other}).eq('pet_id', pet),
          'journal pet immutable',
          code: '42501',
        );
        await denied(
          a
              .from('memory_days')
              .update({'record_date': '1990-01-03'})
              .eq('pet_id', pet),
          'journal date immutable',
          code: '42501',
        );
        for (final date in [
          '1989-12-31',
          dayKey(korea(DateTime.now()).add(const Duration(days: 1))),
        ]) {
          await denied(
            a.rpc(
              'save_memory_day',
              params: {
                'p_pet_id': pet,
                'p_date': date,
                'p_title': '',
                'p_note': '',
                'p_anniversary': false,
              },
            ),
            'server rejects date $date',
            code: '23514',
          );
        }
        await denied(
          a.rpc(
            'save_memory_day',
            params: {
              'p_pet_id': pet,
              'p_date': '2026-02-30',
              'p_title': '',
              'p_note': '',
              'p_anniversary': false,
            },
          ),
          'server rejects invalid date',
          code: '22008',
        );
        final signedOut = newClient();
        await denied(
          signedOut.from('memory_days').select(),
          'signed-out reads denied',
        );
        await denied(
          signedOut.rpc(
            'save_memory_day',
            params: {
              'p_pet_id': pet,
              'p_date': '1990-01-01',
              'p_title': '',
              'p_note': '',
              'p_anniversary': false,
            },
          ),
          'signed-out writes denied',
        );
        await expectLater(
          storeA2.deleteOwned('pets', pet),
          throwsA(predicate((e) => e.toString().contains('연결된 기록'))),
        );
        assertions++;
        check(
          storeA2.rows('pets').any((row) => row['id'] == pet),
          'stale client cannot delete pet with new server journal',
        );
        await denied(
          a2.from('pets').delete().eq('id', pet),
          'direct pet deletion blocked by FK',
          code: '23503',
        );
        await storeA.deleteMemoryDay('1990-01-01', petId: pet);
        check(
          (await a2
                  .from('memory_days')
                  .select()
                  .eq('pet_id', pet)
                  .eq('record_date', '1990-01-01'))
              .isEmpty,
          'journal deletion visible across clients',
        );
        check(
          (await a2.from('memory_days').select().eq('pet_id', pet)).length == 1,
          'other date survives journal deletion',
        );
        await storeA.deleteMemoryDay('1990-01-02', petId: pet);
        await storeA.deleteOwned('pets', pet);
        createdPets.remove(pet);
        check(
          (await a2.from('pets').select().eq('id', pet)).isEmpty,
          'pet deletion succeeds after journals removed',
        );
        check(
          (await a2.from('memory_days').select().eq('pet_id', other)).length ==
              1,
          'other pet journal survives',
        );
        await storeA.logout();
        check(
          storeA.user == null && storeA.rows('memoryDays').isEmpty,
          'logout clears journal cache',
        );
        check(
          prefs.getString(PetStore.key) == before,
          'original local JSON unchanged',
        );
      } finally {
        try {
          final cleanup = clients
              .where(
                (c) =>
                    c.auth.currentUser?.email ==
                    credentials['PET_SNS_TEST_EMAIL_A'],
              )
              .firstOrNull;
          if (cleanup != null) {
            for (final id in createdPets) {
              await cleanup.from('memory_days').delete().eq('pet_id', id);
              await cleanup.from('pets').delete().eq('id', id);
            }
          }
          for (final id in createdProfiles) {
            final active = clients.firstWhere(
              (c) => c.auth.currentUser?.id == id,
            );
            if ((await active.from('pets').select('id')).isEmpty) {
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
        '[PetSNS journals live] PASS: $assertions assertions; app CRUD, independent clients, RLS, concurrent upsert, pet deletion FK, cleanup, local preservation.',
      );
    },
    skip: Platform.environment['PET_SNS_RUN_MEMORY_LIVE'] == '1'
        ? false
        : 'Requires PET_SNS_RUN_MEMORY_LIVE=1 and dedicated A/B accounts.',
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
