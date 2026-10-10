create table public.memory_photos (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid(),
  pet_id text not null,
  record_date date not null check (record_date >= date '1990-01-01' and record_date <= (now() at time zone 'Asia/Seoul')::date),
  object_path text generated always as (owner_id::text || '/' || id::text) stored unique,
  state text not null default 'pending' check (state in ('pending','ready','deleting')),
  created_at timestamptz not null default now(),
  foreign key (pet_id,owner_id) references public.pets(id,owner_id) on delete restrict on update restrict
);
create index memory_photos_owner_date_idx on public.memory_photos(owner_id,record_date,id);
create index memory_photos_pet_owner_idx on public.memory_photos(pet_id,owner_id);
alter table public.memory_photos enable row level security;
revoke all on public.memory_photos from anon, authenticated;
grant select, delete on public.memory_photos to authenticated;
grant insert(id,pet_id,record_date), update(pet_id,record_date,state) on public.memory_photos to authenticated;
create policy photos_read on public.memory_photos for select to authenticated using (owner_id=(select auth.uid()));
create policy photos_create on public.memory_photos for insert to authenticated with check (owner_id=(select auth.uid()));
create policy photos_edit on public.memory_photos for update to authenticated using (owner_id=(select auth.uid())) with check (owner_id=(select auth.uid()));
create policy photos_delete on public.memory_photos for delete to authenticated using (owner_id=(select auth.uid()));

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('memory-photos','memory-photos',false,3145728,array['image/jpeg','image/png','image/webp','image/gif']);
create policy memory_files_read on storage.objects for select to authenticated
using (bucket_id='memory-photos' and split_part(name,'/',1)=(select auth.uid())::text);
create policy memory_files_upload on storage.objects for insert to authenticated with check (
  bucket_id='memory-photos' and split_part(name,'/',1)=(select auth.uid())::text
  and exists(select 1 from public.memory_photos p where p.object_path=name and p.state='pending')
);
create policy memory_files_delete on storage.objects for delete to authenticated using (
  bucket_id='memory-photos' and split_part(name,'/',1)=(select auth.uid())::text
  and exists(select 1 from public.memory_photos p where p.object_path=name and p.state in ('pending','deleting'))
);

-- Serialize an in-flight upload with cancellation so cleanup cannot lose its file.
create function public.guard_memory_file_upload() returns trigger language plpgsql security invoker set search_path='' as $$
begin
  if new.bucket_id='memory-photos' then
    perform 1 from public.memory_photos where object_path=new.name and state='pending' for update;
    if not found then raise exception 'Photo upload is not pending' using errcode='23514'; end if;
  end if;
  return new;
end;
$$;
revoke execute on function public.guard_memory_file_upload() from public,anon,authenticated;
create trigger guard_memory_file_upload before insert on storage.objects for each row execute function public.guard_memory_file_upload();

create function public.guard_memory_photo() returns trigger language plpgsql security invoker set search_path='' as $$
declare origin_type text; origin_date date;
begin
  if tg_op='DELETE' then
    if old.state='ready' or exists(select 1 from storage.objects where bucket_id='memory-photos' and name=old.object_path) then
      raise exception 'Remove the file through Storage before deleting its reservation' using errcode='23514';
    end if;
    return old;
  end if;
  if tg_op='INSERT' and new.state<>'pending' then
    raise exception 'Reserve before uploading' using errcode='23514';
  end if;
  if tg_op='UPDATE' and (
    (old.state='ready' and new.state='pending') or
    (old.state='deleting' and new.state<>'deleting') or
    new.id<>old.id or new.owner_id<>old.owner_id or new.created_at<>old.created_at
  ) then raise exception 'Invalid photo transition' using errcode='23514'; end if;
  if new.state='deleting' then return new; end if;
  select memory_origin_type,memory_origin_date into origin_type,origin_date
    from public.pets where id=new.pet_id and owner_id=new.owner_id for update;
  if origin_type='firstMeeting' and new.record_date<origin_date then
    raise exception 'Photo precedes first meeting' using errcode='23514';
  end if;
  if new.state='ready' and not exists(select 1 from storage.objects where bucket_id='memory-photos' and name=new.owner_id::text || '/' || new.id::text) then
    raise exception 'Photo file is missing' using errcode='23514';
  end if;
  return new;
end;
$$;
revoke execute on function public.guard_memory_photo() from public,anon,authenticated;
create trigger guard_memory_photo before insert or update or delete on public.memory_photos for each row execute function public.guard_memory_photo();

create function public.advance_photo_origin() returns trigger language plpgsql security invoker set search_path='' as $$
begin
  if new.state='ready' then
    update public.pets set memory_origin_date=new.record_date
      where id=new.pet_id and owner_id=new.owner_id and memory_origin_type='firstPhoto' and memory_origin_date>new.record_date;
  end if;
  return new;
end;
$$;
revoke execute on function public.advance_photo_origin() from public,anon,authenticated;
create trigger advance_photo_origin after insert or update on public.memory_photos for each row execute function public.advance_photo_origin();

create function public.guard_pet_photo_origin() returns trigger language plpgsql security invoker set search_path='' as $$
declare first_date date;
begin
  if new.memory_origin_type is distinct from old.memory_origin_type or new.memory_origin_date is distinct from old.memory_origin_date then
    select min(record_date) into first_date from public.memory_photos where pet_id=new.id and owner_id=new.owner_id and state='ready';
    if first_date is not null then
      if new.memory_origin_type='firstPhoto' then new.memory_origin_date=first_date;
      elsif new.memory_origin_date>first_date then raise exception 'Day 0 follows an existing photo' using errcode='23514';
      end if;
    end if;
  end if;
  return new;
end;
$$;
revoke execute on function public.guard_pet_photo_origin() from public,anon,authenticated;
create trigger guard_pet_photo_origin before update on public.pets for each row execute function public.guard_pet_photo_origin();

-- All chosen files become visible together; replacement keeps the old file until this commit.
create function public.finish_memory_photos(p_ids uuid[], p_replace uuid default null) returns void
language plpgsql security invoker set search_path='' as $$
declare expected integer;
begin
  expected=cardinality(p_ids);
  if expected is null or expected=0 or expected<>(select count(distinct x) from unnest(p_ids) x) then
    raise exception 'Invalid photo batch' using errcode='23514';
  end if;
  if p_replace is not null then
    if expected<>1 or p_replace=any(p_ids) then raise exception 'Invalid replacement' using errcode='23514'; end if;
    perform 1 from public.memory_photos where id=p_replace and owner_id=auth.uid() and state='ready' for update;
    if not found then raise exception 'Photo to replace is unavailable' using errcode='23514'; end if;
  end if;
  if (select count(*) from public.memory_photos where id=any(p_ids) and owner_id=auth.uid() and state in ('pending','ready'))<>expected then
    raise exception 'Photo batch is unavailable' using errcode='23514';
  end if;
  update public.memory_photos set state='ready' where id=any(p_ids) and state='pending';
  if p_replace is not null then update public.memory_photos set state='deleting' where id=p_replace; end if;
end;
$$;
revoke execute on function public.finish_memory_photos(uuid[],uuid) from public,anon;
grant execute on function public.finish_memory_photos(uuid[],uuid) to authenticated;

create function public.claim_memory_photo_cleanup() returns void language sql security invoker set search_path='' as $$
  update public.memory_photos set state='deleting'
  where owner_id=auth.uid() and state='pending' and created_at<now()-interval '24 hours';
$$;
revoke execute on function public.claim_memory_photo_cleanup() from public,anon;
grant execute on function public.claim_memory_photo_cleanup() to authenticated;
