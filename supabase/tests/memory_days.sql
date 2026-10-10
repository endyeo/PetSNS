begin;
create function pg_temp.assert_true(ok boolean, label text) returns text
language plpgsql security invoker as $$
begin
  if ok is distinct from true then raise exception 'FAIL: %', label; end if;
  return 'PASS: ' || label;
end;
$$;
create function pg_temp.expect_error(statement text, code text, label text) returns text
language plpgsql security invoker as $$
begin
  begin execute statement;
  exception when others then
    if sqlstate = code then return 'PASS: ' || label; end if;
    raise exception 'FAIL: %, expected %, received %', label, code, sqlstate;
  end;
  raise exception 'FAIL: %, request succeeded', label;
end;
$$;
select pg_temp.assert_true(
  (select relrowsecurity from pg_class where oid='public.memory_days'::regclass), 'journal RLS enabled');
select pg_temp.assert_true(
  not has_table_privilege('anon', 'public.memory_days', 'SELECT'), 'anon cannot read journals');
select pg_temp.assert_true(
  not has_function_privilege('anon', 'public.save_memory_day(text,date,text,text,boolean)', 'EXECUTE'), 'anon cannot save journals');
select pg_temp.assert_true(
  (select not prosecdef from pg_proc where oid='public.save_memory_day(text,date,text,text,boolean)'::regprocedure), 'save RPC uses caller permissions');
insert into auth.users (id) values ('31000000-0000-0000-0000-000000000001'), ('31000000-0000-0000-0000-000000000002');
insert into public.profiles (id,name) values ('31000000-0000-0000-0000-000000000001','A'), ('31000000-0000-0000-0000-000000000002','B');
insert into public.pets (id,owner_id,name) values
  ('journal-a','31000000-0000-0000-0000-000000000001','A pet'),
  ('journal-a2','31000000-0000-0000-0000-000000000001','A pet 2'),
  ('journal-b','31000000-0000-0000-0000-000000000002','B pet');
set local role authenticated;
select set_config('request.jwt.claim.sub','31000000-0000-0000-0000-000000000001',true);
select public.save_memory_day('journal-a','1990-01-01',' 初日 ',' 長い記録 ',true);
select public.save_memory_day('journal-a','1990-01-01','수정','기록',false);
select pg_temp.assert_true(
  (select count(*)=1 from public.memory_days), 'repeated save produces one journal');
select pg_temp.assert_true(
  (select title='수정' and note='기록' and not anniversary from public.memory_days), 'save updates all mutable fields');
select public.save_memory_day('journal-a2','1990-01-01','','',false);
select public.save_memory_day('journal-a','1990-01-02','긴 글',repeat('가',10000),true);
select pg_temp.assert_true((select count(*)=3 from public.memory_days), 'pets and dates remain separate; empty and long journals allowed');
select pg_temp.expect_error($q$select public.save_memory_day('journal-a','1989-12-31','','',false)$q$,'23514','pre-1990 date rejected');
select pg_temp.expect_error($q$select public.save_memory_day('journal-a',(now() at time zone 'Asia/Seoul')::date+1,'','',false)$q$,'23514','future KST date rejected');
select pg_temp.expect_error($q$select public.save_memory_day('journal-a','2026-02-30','','',false)$q$,'22008','invalid calendar date rejected');
select pg_temp.expect_error($q$select public.save_memory_day('journal-a','1990-01-03',null,'',false)$q$,'23502','null title rejected');
select pg_temp.expect_error($q$select public.save_memory_day('journal-b','1990-01-01','cross owner','',false)$q$,'23503','RPC cannot attach journal to B pet');
select pg_temp.expect_error($q$update public.memory_days set owner_id='31000000-0000-0000-0000-000000000002'$q$,'42501','owner immutable');
select pg_temp.expect_error($q$update public.memory_days set pet_id='journal-a2'$q$,'42501','pet immutable');
select pg_temp.expect_error($q$update public.memory_days set record_date='1990-01-04'$q$,'42501','date immutable');
select pg_temp.expect_error($q$delete from public.pets where id='journal-a'$q$,'23503','pet deletion blocked by journal FK');
select set_config('request.jwt.claim.sub','31000000-0000-0000-0000-000000000002',true);
select pg_temp.assert_true((select count(*)=0 from public.memory_days), 'B cannot read A journals');
update public.memory_days set title='B overwrite';
delete from public.memory_days;
select pg_temp.expect_error($q$insert into public.memory_days(pet_id,owner_id,record_date) values ('journal-a','31000000-0000-0000-0000-000000000001','1990-01-03')$q$,'42501','B cannot spoof A owner');
select pg_temp.expect_error($q$select public.save_memory_day('journal-a','1990-01-01','B overwrite','',false)$q$,'42501','B RPC cannot overwrite A journal');
select public.save_memory_day('journal-b','1990-01-01','B record','',false);
select pg_temp.assert_true((select count(*)=1 from public.memory_days), 'B can save own journal');
select set_config('request.jwt.claim.sub','31000000-0000-0000-0000-000000000001',true);
select pg_temp.assert_true((select count(*)=3 from public.memory_days), 'B update/delete left A records intact');
delete from public.memory_days where pet_id='journal-a';
delete from public.pets where id='journal-a';
select pg_temp.assert_true((select count(*)=1 from public.pets where id='journal-a2'), 'deleting journals permits pet deletion without affecting another pet');
set local role anon;
select pg_temp.expect_error('select * from public.memory_days','42501','signed-out SELECT denied');
select pg_temp.expect_error($q$select public.save_memory_day('journal-b','1990-01-01','','',false)$q$,'42501','signed-out RPC denied');
reset role;
rollback;
