begin;

-- Fail on existing table names rather than replacing an unknown remote schema.
create table public.profiles (
  id uuid primary key references auth.users(id) on delete restrict,
  name text not null,
  constraint profiles_name_check check (
    name = btrim(name) and char_length(name) between 1 and 30
  )
);

create table public.pets (
  -- Text keeps the existing local pet identifiers usable during a later import.
  id text primary key default gen_random_uuid()::text,
  owner_id uuid not null default auth.uid()
    references public.profiles(id) on delete restrict,
  name text not null,
  breed text not null default '',
  birthday date,
  photo text,
  memory_origin_type text,
  memory_origin_date date,
  constraint pets_id_check check (id = btrim(id) and id <> ''),
  constraint pets_name_check check (
    name = btrim(name) and char_length(name) between 1 and 60
  ),
  constraint pets_breed_check check (char_length(breed) <= 80),
  constraint pets_birthday_check check (birthday >= date '1990-01-01'),
  constraint pets_memory_origin_check check (
    (memory_origin_type is null and memory_origin_date is null)
    or (
      memory_origin_type is not null and memory_origin_date is not null
      and memory_origin_type in ('firstMeeting', 'firstPhoto')
      and memory_origin_date >= date '1990-01-01'
    )
  )
);
create index pets_owner_id_idx on public.pets(owner_id);

alter table public.profiles enable row level security;
alter table public.pets enable row level security;

-- Supabase projects can have automatic grants. Replace them explicitly.
revoke all on public.profiles, public.pets from public, anon, authenticated;
grant select, insert, delete on public.profiles to authenticated;
grant update (name) on public.profiles to authenticated;
grant select, insert, delete on public.pets to authenticated;
grant update (name, breed, birthday, photo, memory_origin_type, memory_origin_date)
  on public.pets to authenticated;

create policy profiles_select_own on public.profiles
  for select to authenticated using ((select auth.uid()) = id);
create policy profiles_insert_own on public.profiles
  for insert to authenticated with check ((select auth.uid()) = id);
create policy profiles_update_own on public.profiles
  for update to authenticated
  using ((select auth.uid()) = id) with check ((select auth.uid()) = id);
create policy profiles_delete_own on public.profiles
  for delete to authenticated using ((select auth.uid()) = id);

create policy pets_select_own on public.pets
  for select to authenticated using ((select auth.uid()) = owner_id);
create policy pets_insert_own on public.pets
  for insert to authenticated with check ((select auth.uid()) = owner_id);
create policy pets_update_own on public.pets
  for update to authenticated
  using ((select auth.uid()) = owner_id)
  with check ((select auth.uid()) = owner_id);
create policy pets_delete_own on public.pets
  for delete to authenticated using ((select auth.uid()) = owner_id);

-- No account-delete endpoint or automatic Auth/profile creation in this stage.
-- Future memory/membership foreign keys must RESTRICT pet deletion too.
commit;
