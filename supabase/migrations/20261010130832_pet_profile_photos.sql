create table public.pet_avatars (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references public.profiles(id) on delete restrict,
  object_path text generated always as (owner_id::text || '/' || id::text) stored unique,
  state text not null default 'pending' check(state in ('pending','ready','deleting')),
  created_at timestamptz not null default now(),
  unique(id,owner_id)
);
create index pet_avatars_owner_created_idx on public.pet_avatars(owner_id,created_at);
alter table public.pet_avatars enable row level security;
revoke all on public.pet_avatars from public,anon,authenticated;
grant select,delete on public.pet_avatars to authenticated;
grant insert(id),update(state) on public.pet_avatars to authenticated;
grant select,update(state) on public.pet_avatars to service_role;
create policy avatars_read on public.pet_avatars for select to authenticated using(owner_id=(select auth.uid()));
create policy avatars_create on public.pet_avatars for insert to authenticated with check(owner_id=(select auth.uid()));
create policy avatars_edit on public.pet_avatars for update to authenticated using(owner_id=(select auth.uid())) with check(owner_id=(select auth.uid()));
create policy avatars_delete on public.pet_avatars for delete to authenticated using(owner_id=(select auth.uid()));
alter table public.pets add column avatar_id uuid;
alter table public.pets add constraint pets_avatar_owner_fk foreign key(avatar_id,owner_id) references public.pet_avatars(id,owner_id) on delete restrict on update restrict;
alter table public.pets add constraint pets_one_avatar unique(avatar_id,owner_id);
alter table public.pets add constraint pets_photo_source check(avatar_id is null or photo is null);
grant update(avatar_id) on public.pets to authenticated;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('pet-avatars','pet-avatars',false,3145728,array['image/jpeg','image/png','image/webp','image/gif']);
create policy avatar_files_read on storage.objects for select to authenticated using(bucket_id='pet-avatars' and split_part(name,'/',1)=(select auth.uid())::text);
create policy avatar_files_upload on storage.objects for insert to authenticated with check(
  bucket_id='pet-avatars' and split_part(name,'/',1)=(select auth.uid())::text
  and exists(select 1 from public.pet_avatars a where a.object_path=name and a.state='pending')
);
create policy avatar_files_delete on storage.objects for delete to authenticated using(
  bucket_id='pet-avatars' and split_part(name,'/',1)=(select auth.uid())::text
  and exists(select 1 from public.pet_avatars a where a.object_path=name and a.state='deleting')
);
create function public.guard_avatar_upload() returns trigger language plpgsql security invoker set search_path='' as $$
begin
  if new.bucket_id='pet-avatars' then
    perform 1 from public.pet_avatars where object_path=new.name and state='pending' for update;
    if not found then raise exception 'Avatar upload is not pending' using errcode='23514'; end if;
  end if;
  return new;
end; $$;
revoke execute on function public.guard_avatar_upload() from public,anon,authenticated;
create trigger guard_avatar_upload before insert on storage.objects for each row execute function public.guard_avatar_upload();

create function public.guard_avatar() returns trigger language plpgsql security invoker set search_path='' as $$
begin
  if tg_op='DELETE' then
    if old.state<>'deleting' or exists(select 1 from storage.objects where bucket_id='pet-avatars' and name=old.object_path) then
      raise exception 'Remove avatar file before reservation' using errcode='23514';
    end if;
    return old;
  end if;
  if tg_op='INSERT' and new.state<>'pending' then raise exception 'Reserve avatar first' using errcode='23514'; end if;
  if tg_op='UPDATE' and (
    new.id<>old.id or new.owner_id<>old.owner_id or new.created_at<>old.created_at
    or (old.state='ready' and new.state='pending') or (old.state='deleting' and new.state<>'deleting')
  ) then raise exception 'Invalid avatar transition' using errcode='23514'; end if;
  if new.state='ready' and not exists(select 1 from storage.objects where bucket_id='pet-avatars' and name=new.owner_id::text || '/' || new.id::text) then
    raise exception 'Avatar file is missing' using errcode='23514';
  end if;
  if new.state='deleting' and exists(select 1 from public.pets where avatar_id=new.id and owner_id=new.owner_id) then
    raise exception 'Avatar is still attached' using errcode='23514';
  end if;
  return new;
end; $$;
revoke execute on function public.guard_avatar() from public,anon,authenticated;
create trigger guard_avatar before insert or update or delete on public.pet_avatars for each row execute function public.guard_avatar();

create function public.guard_pet_avatar() returns trigger language plpgsql security invoker set search_path='' as $$
begin
  if new.avatar_id is not null then
    perform 1 from public.pet_avatars where id=new.avatar_id and owner_id=new.owner_id and state='ready' for share;
    if not found then raise exception 'Avatar is not ready or owned' using errcode='23514'; end if;
  end if;
  if new.photo is not null and new.photo<>'' and new.photo !~ '^https?://' then
    raise exception 'Photo must be an external URL or avatar reference' using errcode='23514';
  end if;
  return new;
end; $$;
revoke execute on function public.guard_pet_avatar() from public,anon,authenticated;
create trigger guard_pet_avatar before insert or update of avatar_id,photo on public.pets for each row execute function public.guard_pet_avatar();

-- A reservation is independent of a pet until the profile and its photo commit together.
create function public.save_pet_with_avatar(p_pet_id text,p_create boolean,p_values jsonb,p_avatar uuid) returns setof public.pets
language plpgsql security invoker set search_path='' as $$
declare previous_avatar uuid; current_pet public.pets%rowtype;
begin
  if p_values is null or jsonb_typeof(p_values)<>'object' or exists(select 1 from jsonb_object_keys(p_values) k where k not in ('name','breed','birthday','photo')) then
    raise exception 'Invalid profile fields' using errcode='23514';
  end if;
  if p_avatar is not null then
    perform 1 from public.pet_avatars where id=p_avatar and owner_id=auth.uid() and state in ('pending','ready') for update;
    if not found then raise exception 'Avatar unavailable' using errcode='23514'; end if;
  end if;
  if p_create then
    insert into public.pets(id,owner_id,name,breed,birthday) values(p_pet_id,auth.uid(),btrim(p_values->>'name'),coalesce(p_values->>'breed',''),(p_values->>'birthday')::date);
  end if;
  select * into current_pet from public.pets where id=p_pet_id and owner_id=auth.uid() for update;
  if not found then raise exception 'Pet unavailable' using errcode='23514'; end if;
  if p_values ? 'birthday' and (p_values->>'birthday')::date > (now() at time zone 'Asia/Seoul')::date then
    raise exception 'Future birthday' using errcode='23514';
  end if;
  previous_avatar=current_pet.avatar_id;
  if p_avatar is not null then update public.pet_avatars set state='ready' where id=p_avatar; end if;
  update public.pets set
    name=case when p_values ? 'name' then btrim(p_values->>'name') else name end,
    breed=case when p_values ? 'breed' then p_values->>'breed' else breed end,
    birthday=case when p_values ? 'birthday' then (p_values->>'birthday')::date else birthday end,
    photo=case when p_avatar is not null then null when p_values ? 'photo' then nullif(p_values->>'photo','') else photo end,
    avatar_id=p_avatar
  where id=p_pet_id and owner_id=auth.uid();
  if previous_avatar is not null and previous_avatar is distinct from p_avatar then
    update public.pet_avatars set state='deleting' where id=previous_avatar;
  end if;
  return query select * from public.pets where id=p_pet_id and owner_id=auth.uid();
end; $$;
revoke execute on function public.save_pet_with_avatar(text,boolean,jsonb,uuid) from public,anon;
grant execute on function public.save_pet_with_avatar(text,boolean,jsonb,uuid) to authenticated;

create function public.claim_avatar_cleanup() returns void language sql security invoker set search_path='' as $$
  update public.pet_avatars a set state='deleting' where a.owner_id=auth.uid() and (
    (a.state='pending' and a.created_at<now()-interval '24 hours')
    or (a.state='ready' and not exists(select 1 from public.pets p where p.avatar_id=a.id and p.owner_id=a.owner_id))
  );
$$;
revoke execute on function public.claim_avatar_cleanup() from public,anon;
grant execute on function public.claim_avatar_cleanup() to authenticated;
