-- Run only in a separate development/verification database, after migration.
-- Fixtures and helper functions are rolled back, including after any failure.
begin;

create function pg_temp.assert_true(ok boolean, label text) returns text
language plpgsql security invoker as $$
begin
  if ok is distinct from true then raise exception 'FAIL: %', label; end if;
  return 'PASS: ' || label;
end;
$$;
create function pg_temp.expect_error(statement text, code text, label text)
returns text language plpgsql security invoker as $$
begin
  begin
    execute statement;
  exception when others then
    if sqlstate = code then return 'PASS: ' || label; end if;
    raise exception 'FAIL: %, expected %, received %', label, code, sqlstate;
  end;
  raise exception 'FAIL: %, statement unexpectedly succeeded', label;
end;
$$;

select pg_temp.assert_true(
  not has_function_privilege('anon', 'public.rls_auto_enable()', 'EXECUTE')
  and not has_function_privilege('authenticated', 'public.rls_auto_enable()', 'EXECUTE'),
  'clients cannot execute the privileged DDL helper');
select pg_temp.assert_true(
  exists(select 1 from pg_event_trigger where evtname = 'ensure_rls' and evtenabled = 'O'),
  'RLS DDL event trigger remains enabled');
select pg_temp.assert_true(
  (select count(*) = 2 from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname in ('profiles', 'pets') and c.relrowsecurity),
  'RLS enabled on both tables');
select pg_temp.assert_true(
  (select count(*) = 8 from pg_policies where schemaname = 'public'
    and tablename in ('profiles', 'pets')),
  'four operation policies per table');
select pg_temp.assert_true(
  not has_table_privilege('anon', 'public.profiles', 'SELECT')
  and not has_table_privilege('anon', 'public.pets', 'SELECT'),
  'anon has no read grants');
select pg_temp.assert_true(
  not has_column_privilege('authenticated', 'public.profiles', 'id', 'UPDATE')
  and not has_column_privilege('authenticated', 'public.pets', 'id', 'UPDATE')
  and not has_column_privilege('authenticated', 'public.pets', 'owner_id', 'UPDATE'),
  'IDs and ownership are immutable for clients');
select pg_temp.assert_true(
  exists(select 1 from pg_indexes where schemaname = 'public'
    and tablename = 'pets' and indexname = 'pets_owner_id_idx'),
  'owner lookup index exists');
select pg_temp.assert_true(
  (select count(*) = 2 from pg_constraint where contype = 'f'
    and confdeltype = 'r' and conrelid in ('public.profiles'::regclass, 'public.pets'::regclass)
    and confrelid in ('auth.users'::regclass,'public.profiles'::regclass)),
  'both parent foreign keys restrict deletion');

-- Fresh Auth fixture IDs prevent touching existing accounts.
select set_config('test.account_a', gen_random_uuid()::text, true);
select set_config('test.account_b', gen_random_uuid()::text, true);
select set_config('test.pet_a', gen_random_uuid()::text, true);
select set_config('test.pet_b', gen_random_uuid()::text, true);
insert into auth.users(id) values
  (current_setting('test.account_a')::uuid), (current_setting('test.account_b')::uuid);
select pg_temp.expect_error(
  $$insert into public.profiles(id,name) values(gen_random_uuid(),'Missing Auth')$$,
  '23503', 'profile requires an existing Auth user');
select pg_temp.expect_error(
  $$insert into public.pets(owner_id,name) values(gen_random_uuid(),'Missing profile')$$,
  '23503', 'pet requires an existing profile');

set local role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.account_a'), true);
select set_config('request.jwt.claims', json_build_object('sub', current_setting('test.account_a'), 'role', 'authenticated')::text, true);
select pg_temp.assert_true(current_user = 'authenticated', 'A uses ordinary role');
insert into public.profiles(id,name) values(auth.uid(),'보호자 A');
insert into public.pets(id,name,breed,birthday,memory_origin_type,memory_origin_date)
  values(current_setting('test.pet_a'),'모카','골든 리트리버','2022-04-12','firstMeeting','2022-05-01');
select pg_temp.assert_true((select count(*) = 1 from public.profiles), 'A reads own profile');
select pg_temp.assert_true((select owner_id = auth.uid() from public.pets
  where id = current_setting('test.pet_a')), 'pet owner defaults to A');
update public.profiles set name = '보호자 A 수정' where id = auth.uid();
select pg_temp.assert_true((select name = '보호자 A 수정' from public.profiles
  where id = auth.uid()), 'A updates own profile');
update public.pets set name = '모카 수정' where id = current_setting('test.pet_a');
select pg_temp.assert_true((select name = '모카 수정' and breed = '골든 리트리버'
  and birthday = date '2022-04-12' and memory_origin_type = 'firstMeeting'
  and memory_origin_date = date '2022-05-01' from public.pets
  where id = current_setting('test.pet_a')), 'A update preserves birthday and Day 0');
select pg_temp.expect_error(
  $$delete from public.profiles where id = auth.uid()$$,
  '23503', 'profile deletion blocked while pet remains');
select pg_temp.expect_error(
  $$update public.pets set owner_id = current_setting('test.account_b')::uuid where id = current_setting('test.pet_a')$$,
  '42501', 'A cannot transfer ownership');
select pg_temp.expect_error(
  $$update public.pets set id = 'changed' where id = current_setting('test.pet_a')$$,
  '42501', 'A cannot change pet ID');
select pg_temp.expect_error(
  $$update public.profiles set id = current_setting('test.account_b')::uuid where id = auth.uid()$$,
  '42501', 'A cannot change profile ID');
select pg_temp.expect_error(
  $$insert into public.profiles(id,name) values(current_setting('test.account_b')::uuid,'Spoofed')$$,
  '42501', 'A cannot create B profile');
select pg_temp.expect_error(
  $$insert into public.pets(owner_id,name) values(current_setting('test.account_b')::uuid,'Spoofed')$$,
  '42501', 'A cannot create a pet for B');
select pg_temp.expect_error($$insert into public.pets(name) values(null)$$,
  '23502', 'pet name required');
select pg_temp.expect_error($$insert into public.pets(name) values('   ')$$,
  '23514', 'blank pet name rejected');
select pg_temp.expect_error($$insert into public.pets(name) values(repeat('x',61))$$,
  '23514', 'pet name over 60 rejected');
select pg_temp.expect_error($$insert into public.pets(name,breed) values('테스트',repeat('x',81))$$,
  '23514', 'breed over 80 rejected');
select pg_temp.expect_error($$update public.profiles set name = repeat('x',31) where id = auth.uid()$$,
  '23514', 'profile name over 30 rejected');
select pg_temp.expect_error($$update public.profiles set name = null where id = auth.uid()$$,
  '23502', 'profile name required');
select pg_temp.expect_error($$update public.profiles set name = '' where id = auth.uid()$$,
  '23514', 'blank profile name rejected');
select pg_temp.expect_error($$insert into public.pets(id,name) values('','테스트')$$,
  '23514', 'empty pet ID rejected');
select pg_temp.expect_error($$insert into public.pets(name,birthday) values('테스트','1989-12-31')$$,
  '23514', 'birthday below 1990 rejected');
select pg_temp.expect_error($$insert into public.pets(name,memory_origin_type) values('테스트','firstMeeting')$$,
  '23514', 'Day 0 type without date rejected');
select pg_temp.expect_error($$insert into public.pets(name,memory_origin_date) values('테스트','2022-05-01')$$,
  '23514', 'Day 0 date without type rejected');
select pg_temp.expect_error($$insert into public.pets(name,memory_origin_type,memory_origin_date) values('테스트','other','2022-05-01')$$,
  '23514', 'invalid Day 0 type rejected');
select pg_temp.expect_error($$insert into public.pets(name,memory_origin_type,memory_origin_date) values('테스트','firstPhoto','1989-12-31')$$,
  '23514', 'Day 0 below 1990 rejected');
select pg_temp.assert_true((select count(*) = 1 from public.pets), 'rejected A writes leave no extra rows');
update public.profiles set name = repeat('x',30) where id = auth.uid();
select pg_temp.assert_true((select char_length(name) = 30 from public.profiles where id = auth.uid()),
  'profile accepts exact 30 character boundary');
update public.profiles set name = '보호자 A 수정' where id = auth.uid();
select set_config('test.legacy_pet', floor(extract(epoch from clock_timestamp()) * 1000000)::bigint::text || '-123', true);
insert into public.pets(id,name,breed,birthday,memory_origin_type,memory_origin_date)
  values(current_setting('test.legacy_pet'),repeat('x',60),repeat('x',80),'1990-01-01','firstPhoto','1990-01-01');
select pg_temp.assert_true((select char_length(name) = 60 and char_length(breed) = 80
  and birthday = date '1990-01-01' and memory_origin_type = 'firstPhoto'
  and memory_origin_date = date '1990-01-01' from public.pets where id = current_setting('test.legacy_pet')),
  'legacy text ID and exact pet field boundaries accepted');
delete from public.pets where id = current_setting('test.legacy_pet');

select set_config('request.jwt.claim.sub', current_setting('test.account_b'), true);
select set_config('request.jwt.claims', json_build_object('sub', current_setting('test.account_b'), 'role', 'authenticated')::text, true);
insert into public.profiles(id,name) values(auth.uid(),'보호자 B');
insert into public.pets(id,name) values(current_setting('test.pet_b'),'루나');
select pg_temp.assert_true((select count(*) = 1 from public.profiles), 'B reads only own profile');
select pg_temp.assert_true((select count(*) = 1 from public.pets), 'B reads only own pet');
select pg_temp.assert_true(not exists(select 1 from public.profiles
  where id = current_setting('test.account_a')::uuid), 'B cannot read A profile by ID');
select pg_temp.assert_true(not exists(select 1 from public.pets
  where id = current_setting('test.pet_a')), 'B cannot read A pet by ID');
with changed as (update public.profiles set name = 'stolen'
  where id = current_setting('test.account_a')::uuid returning id)
select pg_temp.assert_true((select count(*) = 0 from changed), 'B update A profile affects zero rows');
with changed as (update public.pets set name = 'stolen'
  where id = current_setting('test.pet_a') returning id)
select pg_temp.assert_true((select count(*) = 0 from changed), 'B update A pet affects zero rows');
with changed as (delete from public.profiles
  where id = current_setting('test.account_a')::uuid returning id)
select pg_temp.assert_true((select count(*) = 0 from changed), 'B delete A profile affects zero rows');
with changed as (delete from public.pets where id = current_setting('test.pet_a') returning id)
select pg_temp.assert_true((select count(*) = 0 from changed), 'B delete A pet affects zero rows');
select pg_temp.expect_error(
  $$insert into public.pets(owner_id,name) values(current_setting('test.account_a')::uuid,'Spoofed')$$,
  '42501', 'B cannot create a pet for A');
select pg_temp.expect_error(
  $$insert into public.profiles(id,name) values(current_setting('test.account_a')::uuid,'Spoofed')$$,
  '42501', 'B cannot create A profile');
update public.profiles set name = '보호자 B 수정' where id = auth.uid();
update public.pets set name = '루나 수정' where id = current_setting('test.pet_b');
select pg_temp.assert_true((select name = '보호자 B 수정' from public.profiles where id = auth.uid())
  and (select name = '루나 수정' from public.pets where id = current_setting('test.pet_b')),
  'B updates own rows');

set local role anon;
select set_config('request.jwt.claim.sub', '', true);
select set_config('request.jwt.claims', '{}', true);
select pg_temp.assert_true(current_user = 'anon', 'signed-out uses anon role');
select pg_temp.expect_error($$select * from public.profiles$$, '42501', 'anon cannot read profiles');
select pg_temp.expect_error($$select * from public.pets$$, '42501', 'anon cannot read pets');
select pg_temp.expect_error($$insert into public.profiles(id,name) values(gen_random_uuid(),'anon')$$, '42501', 'anon cannot create profiles');
select pg_temp.expect_error($$insert into public.pets(name) values('anon')$$, '42501', 'anon cannot create pets');
select pg_temp.expect_error($$update public.profiles set name = 'anon'$$, '42501', 'anon cannot update profiles');
select pg_temp.expect_error($$update public.pets set name = 'anon'$$, '42501', 'anon cannot update pets');
select pg_temp.expect_error($$delete from public.profiles$$, '42501', 'anon cannot delete profiles');
select pg_temp.expect_error($$delete from public.pets$$, '42501', 'anon cannot delete pets');

set local role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.account_a'), true);
select set_config('request.jwt.claims', json_build_object('sub', current_setting('test.account_a'), 'role', 'authenticated')::text, true);
select pg_temp.assert_true((select name = '보호자 A 수정' from public.profiles where id = auth.uid())
  and (select name = '모카 수정' from public.pets where id = current_setting('test.pet_a')),
  'A original rows unchanged after B and anon attempts');
select pg_temp.assert_true(not exists(select 1 from public.profiles where id = current_setting('test.account_b')::uuid)
  and not exists(select 1 from public.pets where id = current_setting('test.pet_b')),
  'A cannot read B rows');
with changed as (update public.profiles set name = 'stolen' where id = current_setting('test.account_b')::uuid returning id)
select pg_temp.assert_true((select count(*) = 0 from changed), 'A cannot update B profile');
with changed as (delete from public.profiles where id = current_setting('test.account_b')::uuid returning id)
select pg_temp.assert_true((select count(*) = 0 from changed), 'A cannot delete B profile');
with changed as (update public.pets set name = 'stolen' where id = current_setting('test.pet_b') returning id)
select pg_temp.assert_true((select count(*) = 0 from changed), 'A cannot update B pet');
with changed as (delete from public.pets where id = current_setting('test.pet_b') returning id)
select pg_temp.assert_true((select count(*) = 0 from changed), 'A cannot delete B pet');
delete from public.pets where id = current_setting('test.pet_a');
select pg_temp.assert_true(not exists(select 1 from public.pets where id = current_setting('test.pet_a')),
  'A deletes own unreferenced pet');
delete from public.profiles where id = auth.uid();
select pg_temp.assert_true(not exists(select 1 from public.profiles where id = auth.uid()),
  'A deletes own profile after deleting pet');

select set_config('request.jwt.claim.sub', current_setting('test.account_b'), true);
select set_config('request.jwt.claims', json_build_object('sub', current_setting('test.account_b'), 'role', 'authenticated')::text, true);
select pg_temp.assert_true((select name = '루나 수정' from public.pets where id = current_setting('test.pet_b')),
  'B pet unchanged after A attempts');
reset role;
select pg_temp.expect_error(
  $$delete from auth.users where id = current_setting('test.account_b')::uuid$$,
  '23503', 'Auth user deletion blocked while profile remains');
set local role authenticated;
delete from public.pets where id = current_setting('test.pet_b');
delete from public.profiles where id = auth.uid();
select pg_temp.assert_true(not exists(select 1 from public.pets) and not exists(select 1 from public.profiles),
  'B deletes own pet and profile');
rollback;
