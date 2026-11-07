-- Intly: private media buckets and Storage access rules.
-- Files live at <user_id>/<folder>/<file>. Only the owner can upload, replace
-- or delete. Anyone who may see the post or reel (the existing RLS rules) may
-- download its media.

insert into storage.buckets (id, name, public)
values ('post-media', 'post-media', false),
       ('reel-media', 'reel-media', false)
on conflict (id) do update set public = false;

drop policy if exists intly_media_owner_insert on storage.objects;
create policy intly_media_owner_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id in ('post-media', 'reel-media')
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Upload with upsert needs update permission as well as insert.
drop policy if exists intly_media_owner_update on storage.objects;
create policy intly_media_owner_update on storage.objects
  for update to authenticated
  using (
    bucket_id in ('post-media', 'reel-media')
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id in ('post-media', 'reel-media')
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists intly_media_owner_delete on storage.objects;
create policy intly_media_owner_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id in ('post-media', 'reel-media')
    and (storage.foldername(name))[1] = auth.uid()::text
  );

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
        where storage.objects.name in (r.video_path, r.audio_path, r.poster_path)
          and public.can_view_reel(r.id)
      )
    )
  );
