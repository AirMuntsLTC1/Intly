-- Intly: profile photos, 7-day cooldowns for display name and @username,
-- username suggestions, and reel thumbnails.
--
-- The cooldown is enforced HERE (a trigger), not only in the app, so it cannot be
-- bypassed by calling the REST API directly.

-- -----------------------------------------------------------------------------
-- 1. Profile columns
-- -----------------------------------------------------------------------------
alter table public.profiles
  add column if not exists avatar_path text,
  add column if not exists name_changed_at timestamptz,
  add column if not exists username_changed_at timestamptz;

-- Reel and draft thumbnails. The grid shows this image, never a decoded video.
alter table public.reels add column if not exists thumbnail_path text;
alter table public.reel_drafts add column if not exists thumbnail_path text;

update public.reels
   set thumbnail_path = poster_path
 where thumbnail_path is null and poster_path is not null;

-- -----------------------------------------------------------------------------
-- 2. Cooldown trigger: display name and username may change once every 7 days
-- -----------------------------------------------------------------------------
create or replace function public.enforce_profile_cooldowns()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.display_name is distinct from old.display_name then
    if old.name_changed_at is not null
       and old.name_changed_at > now() - interval '7 days' then
      raise exception 'You can change your name again on %',
        to_char((old.name_changed_at + interval '7 days') at time zone 'UTC', 'YYYY-MM-DD')
        using errcode = 'P0001';
    end if;
    new.name_changed_at := now();
  end if;

  if new.username is distinct from old.username then
    new.username := lower(new.username);
    if new.username !~ '^[a-z0-9_.]{3,30}$' then
      raise exception 'Usernames use 3-30 letters, numbers, dots or underscores'
        using errcode = 'P0001';
    end if;
    if old.username_changed_at is not null
       and old.username_changed_at > now() - interval '7 days' then
      raise exception 'You can change your username again on %',
        to_char((old.username_changed_at + interval '7 days') at time zone 'UTC', 'YYYY-MM-DD')
        using errcode = 'P0001';
    end if;
    new.username_changed_at := now();
  end if;

  return new;
end;
$$;

drop trigger if exists profiles_enforce_cooldowns on public.profiles;
create trigger profiles_enforce_cooldowns
before update of display_name, username on public.profiles
for each row execute function public.enforce_profile_cooldowns();

-- -----------------------------------------------------------------------------
-- 3. Username availability and suggestions
-- -----------------------------------------------------------------------------
create or replace function public.is_username_available(candidate text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select lower(candidate) ~ '^[a-z0-9_.]{3,30}$'
     and not exists (
       select 1 from public.profiles p
        where lower(p.username) = lower(candidate)
          and p.id <> auth.uid()
     );
$$;

-- Returns up to `wanted` free usernames based on `base_name` (for example the
-- person's display name). Every suggestion is checked against the live table.
create or replace function public.suggest_usernames(base_name text, wanted int default 5)
returns setof text
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  stem text;
  cand text;
  picked text[] := '{}';
  i int;
begin
  stem := left(lower(regexp_replace(coalesce(base_name, ''), '[^a-zA-Z0-9_.]', '', 'g')), 22);
  if length(stem) < 3 then
    stem := 'intly';
  end if;

  for i in 1..60 loop
    exit when coalesce(array_length(picked, 1), 0) >= least(greatest(wanted, 1), 10);
    cand := left(case i % 4
      when 0 then stem || '_' || (10 + floor(random() * 89))::int
      when 1 then stem || (100 + floor(random() * 8900))::int
      when 2 then stem || '.' || (10 + floor(random() * 89))::int
      else stem || '_' || (100 + floor(random() * 899))::int
    end, 30);
    if cand <> all(picked) and public.is_username_available(cand) then
      picked := picked || cand;
    end if;
  end loop;

  return query select unnest(picked);
end;
$$;

revoke all on function public.is_username_available(text) from public, anon;
revoke all on function public.suggest_usernames(text, int) from public, anon;
grant execute on function public.is_username_available(text) to authenticated;
grant execute on function public.suggest_usernames(text, int) to authenticated;

-- -----------------------------------------------------------------------------
-- 4. Avatars bucket: <user_id>/<file>. Owners write. Anyone who may see the
--    profile can read the picture.
-- -----------------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', false)
on conflict (id) do update set public = false;

drop policy if exists intly_avatar_owner_insert on storage.objects;
create policy intly_avatar_owner_insert on storage.objects
  for insert to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists intly_avatar_owner_update on storage.objects;
create policy intly_avatar_owner_update on storage.objects
  for update to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists intly_avatar_owner_delete on storage.objects;
create policy intly_avatar_owner_delete on storage.objects
  for delete to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists intly_avatar_read on storage.objects;
create policy intly_avatar_read on storage.objects
  for select to authenticated
  using (
    bucket_id = 'avatars'
    and exists (
      select 1 from public.profiles p
       where p.id::text = (storage.foldername(name))[1]
         and public.can_view_profile(p.id)
    )
  );

-- -----------------------------------------------------------------------------
-- 5. Reel thumbnails must be downloadable with the reel, so the read rule
--    also covers thumbnail_path.
-- -----------------------------------------------------------------------------
drop policy if exists intly_media_read on storage.objects;
create policy intly_media_read on storage.objects
  for select to authenticated
  using (
    bucket_id in ('post-media', 'reel-media')
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or exists (
        select 1 from public.post_media pm
        where pm.storage_path = storage.objects.name
          and public.can_view_post(pm.post_id)
      )
      or exists (
        select 1 from public.reels r
        where storage.objects.name in (r.video_path, r.audio_path, r.poster_path, r.thumbnail_path)
          and public.can_view_reel(r.id)
      )
    )
  );
