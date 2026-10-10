-- Admin fixture setup checks the FK, not ordinary user permissions.
-- The entire fixture is rolled back; no existing Auth user is targeted.
begin;
do $$
declare fixture_id uuid := gen_random_uuid();
begin
  insert into auth.users(id) values(fixture_id);
  insert into public.profiles(id,name) values(fixture_id,'T27 FK 검증');
  begin
    delete from auth.users where id=fixture_id;
    raise exception 'FAIL: Auth user deletion unexpectedly succeeded';
  exception when foreign_key_violation then
    null;
  end;
end;
$$;
rollback;
