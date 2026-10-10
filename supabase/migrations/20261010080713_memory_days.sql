begin;

-- The composite key prevents attaching an owned journal to another user's pet.
alter table public.pets add constraint pets_id_owner_unique unique (id, owner_id);
create table public.memory_days (
  pet_id text not null,
  owner_id uuid not null default auth.uid(),
  record_date date not null,
  title text not null default '',
  note text not null default '',
  anniversary boolean not null default false,
  primary key (pet_id, record_date),
  constraint memory_days_pet_owner_fkey foreign key (pet_id, owner_id)
    references public.pets (id, owner_id) on delete restrict on update restrict,
  constraint memory_days_date_check check (
    record_date >= date '1990-01-01'
    and record_date <= (now() at time zone 'Asia/Seoul')::date
  )
);
create index memory_days_owner_date_idx on public.memory_days (owner_id, record_date);
create index memory_days_pet_owner_idx on public.memory_days (pet_id, owner_id);

alter table public.memory_days enable row level security;
revoke all on public.memory_days from public, anon, authenticated;
grant select, insert, delete on public.memory_days to authenticated;
grant update (title, note, anniversary) on public.memory_days to authenticated;
create policy memory_days_select_own on public.memory_days
  for select to authenticated using ((select auth.uid()) = owner_id);
create policy memory_days_insert_own on public.memory_days
  for insert to authenticated with check ((select auth.uid()) = owner_id);
create policy memory_days_update_own on public.memory_days
  for update to authenticated using ((select auth.uid()) = owner_id)
  with check ((select auth.uid()) = owner_id);
create policy memory_days_delete_own on public.memory_days
  for delete to authenticated using ((select auth.uid()) = owner_id);

-- Upsert only mutable fields; RLS and column grants still apply to the caller.
create function public.save_memory_day(
  p_pet_id text, p_date date, p_title text, p_note text, p_anniversary boolean
) returns setof public.memory_days
language sql security invoker set search_path = '' as $$
  insert into public.memory_days (pet_id, owner_id, record_date, title, note, anniversary)
  values (p_pet_id, auth.uid(), p_date, btrim(p_title), btrim(p_note), p_anniversary)
  on conflict (pet_id, record_date) do update set
    title = excluded.title, note = excluded.note, anniversary = excluded.anniversary
  returning *;
$$;
revoke all on function public.save_memory_day(text, date, text, text, boolean)
  from public, anon, authenticated;
grant execute on function public.save_memory_day(text, date, text, text, boolean)
  to authenticated;

commit;
