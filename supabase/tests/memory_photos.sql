begin;
create function pg_temp.assert_true(ok boolean, label text) returns text language plpgsql as $$
begin if ok is distinct from true then raise exception 'FAIL: %',label; end if; return 'PASS: '||label; end; $$;
create function pg_temp.expect_error(statement text, code text, label text) returns text language plpgsql as $$
begin
  begin execute statement; exception when others then
    if sqlstate=code then return 'PASS: '||label; end if;
    raise exception 'FAIL: %, expected %, got %',label,code,sqlstate;
  end;
  raise exception 'FAIL: %, request succeeded',label;
end; $$;
select pg_temp.assert_true((select relrowsecurity from pg_class where oid='public.memory_photos'::regclass),'photo RLS enabled');
select pg_temp.assert_true((select not public and file_size_limit=3145728 and cardinality(allowed_mime_types)=4 from storage.buckets where id='memory-photos'),'private bucket and exact restrictions');
select pg_temp.assert_true(not has_table_privilege('anon','public.memory_photos','SELECT'),'anon cannot read metadata');
select pg_temp.assert_true(not has_function_privilege('anon','public.finish_memory_photos(uuid[],uuid)','EXECUTE'),'anon cannot finalize');
select pg_temp.assert_true(has_table_privilege('service_role','public.memory_photos','SELECT') and has_column_privilege('service_role','public.memory_photos','state','UPDATE') and not has_column_privilege('service_role','public.memory_photos','owner_id','UPDATE'),'Storage backend can read and lock only mutable state');
select pg_temp.assert_true((select bool_and(not prosecdef and proconfig @> array['search_path=""']) from pg_proc where proname in ('guard_memory_photo','guard_memory_file_upload','advance_photo_origin','guard_pet_photo_origin','finish_memory_photos','claim_memory_photo_cleanup')),'photo functions use caller and empty search path');
insert into auth.users values ('32000000-0000-0000-0000-000000000001'),('32000000-0000-0000-0000-000000000002');
insert into public.profiles(id,name) values ('32000000-0000-0000-0000-000000000001','A'),('32000000-0000-0000-0000-000000000002','B');
insert into public.pets(id,owner_id,name,memory_origin_type,memory_origin_date) values
('photo-a','32000000-0000-0000-0000-000000000001','A','firstPhoto','2000-01-01'),
('photo-b','32000000-0000-0000-0000-000000000002','B','firstMeeting','2000-01-01');
set local role authenticated;
select set_config('request.jwt.claim.sub','32000000-0000-0000-0000-000000000001',true);
insert into public.memory_photos(id,pet_id,record_date) values ('33000000-0000-0000-0000-000000000001','photo-a','1999-01-01');
select pg_temp.assert_true((select state='pending' and object_path=owner_id::text||'/'||id::text from public.memory_photos),'reservation generates owned immutable path');
select pg_temp.expect_error($q$select public.finish_memory_photos(array['33000000-0000-0000-0000-000000000001'::uuid])$q$,'23514','missing file cannot finalize');
select pg_temp.expect_error($q$delete from public.pets where id='photo-a'$q$,'23503','pending reservation restricts pet deletion');
select pg_temp.expect_error($q$insert into public.memory_photos(pet_id,record_date) values ('photo-b','2000-01-01')$q$,'23503','cannot attach to B pet');
select pg_temp.expect_error($q$update public.memory_photos set owner_id='32000000-0000-0000-0000-000000000002'$q$,'42501','metadata owner immutable');
insert into storage.objects(bucket_id,name) select 'memory-photos',object_path from public.memory_photos;
select public.finish_memory_photos(array['33000000-0000-0000-0000-000000000001'::uuid]);
select pg_temp.assert_true((select state='ready' from public.memory_photos),'uploaded file becomes ready');
select pg_temp.assert_true((select memory_origin_date='1999-01-01' from public.pets where id='photo-a'),'completion shifts first-photo Day 0');
select pg_temp.expect_error($q$delete from public.memory_photos$q$,'23514','ready metadata cannot be deleted before file');
delete from storage.objects;
select pg_temp.assert_true((select count(*)=1 from storage.objects),'ready file cannot be deleted directly');
select pg_temp.expect_error($q$update public.pets set memory_origin_type='firstMeeting',memory_origin_date='2000-01-01' where id='photo-a'$q$,'23514','direct Day 0 cannot follow photo');
update public.memory_photos set record_date='1998-01-01';
select pg_temp.assert_true((select memory_origin_date='1998-01-01' from public.pets where id='photo-a'),'date edit shifts Day 0 atomically');
insert into public.memory_photos(id,pet_id,record_date) values ('33000000-0000-0000-0000-000000000002','photo-a','1997-01-01'),('33000000-0000-0000-0000-000000000003','photo-a','1997-01-01');
insert into storage.objects(bucket_id,name) select 'memory-photos',object_path from public.memory_photos where id='33000000-0000-0000-0000-000000000002';
select pg_temp.expect_error($q$select public.finish_memory_photos(array['33000000-0000-0000-0000-000000000002'::uuid,'33000000-0000-0000-0000-000000000003'::uuid])$q$,'23514','batch with missing file rolls back');
select pg_temp.assert_true((select count(*)=2 from public.memory_photos where state='pending') and (select memory_origin_date='1998-01-01' from public.pets where id='photo-a'),'batch rollback preserves visibility and Day 0');
reset role;
insert into public.memory_photos(id,owner_id,pet_id,record_date,created_at) values
('33000000-0000-0000-0000-000000000004','32000000-0000-0000-0000-000000000001','photo-a','1997-01-01',now()-interval '25 hours'),
('33000000-0000-0000-0000-000000000005','32000000-0000-0000-0000-000000000001','photo-a','1997-01-01',now()-interval '24 hours');
set local role authenticated;
select public.claim_memory_photo_cleanup();
select pg_temp.assert_true((select state='deleting' from public.memory_photos where id='33000000-0000-0000-0000-000000000004') and (select state='pending' from public.memory_photos where id='33000000-0000-0000-0000-000000000005'),'cleanup claims only reservations older than 24 hours');
select set_config('request.jwt.claim.sub','32000000-0000-0000-0000-000000000002',true);
select pg_temp.assert_true((select count(*)=0 from public.memory_photos) and (select count(*)=0 from storage.objects),'B cannot read A metadata or files');
update public.memory_photos set state='deleting';
delete from storage.objects;
select pg_temp.expect_error($q$insert into public.memory_photos(pet_id,record_date) values ('photo-b','1999-01-01')$q$,'23514','first-meeting boundary enforced');
select set_config('request.jwt.claim.sub','32000000-0000-0000-0000-000000000001',true);
select pg_temp.assert_true((select count(*)=5 from public.memory_photos),'B mutation leaves A intact');
update public.memory_photos set state='deleting';
select pg_temp.expect_error($q$delete from public.memory_photos where id='33000000-0000-0000-0000-000000000001'$q$,'23514','deleting row protects file until cleanup');
delete from storage.objects;
select pg_temp.expect_error($q$insert into storage.objects(bucket_id,name) values ('memory-photos','32000000-0000-0000-0000-000000000001/33000000-0000-0000-0000-000000000001')$q$,'23514','late upload after cancellation rejected');
delete from public.memory_photos;
delete from public.pets where id='photo-a';
select pg_temp.assert_true((select count(*)=0 from public.memory_photos),'storage cleanup permits metadata and pet deletion');
set local role anon;
select pg_temp.assert_true((select count(*)=0 from storage.objects),'signed-out file access denied');
select pg_temp.expect_error('select * from public.memory_photos','42501','signed-out metadata denied');
reset role;
rollback;
