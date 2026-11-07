-- Intly initial Supabase schema
-- Built for the uploaded Intly Flutter source. User identity is Supabase Auth UUIDs.
-- Demo records in assets/seed.json deliberately are NOT inserted into production tables.

-- -----------------------------------------------------------------------------
-- Profiles, preferences, and social graph
-- -----------------------------------------------------------------------------
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null,
  display_name text not null default 'New user',
  bio text not null default '' check (char_length(bio) <= 160),
  avatar_url text,
  website text,
  accent_hue smallint not null default 262 check (accent_hue between 0 and 360),
  is_private boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_username_format check (username ~ '^[a-z0-9_.]{3,30}$')
);
create unique index if not exists profiles_username_lower_uq on public.profiles (lower(username));

create table if not exists public.user_settings (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  theme text not null default 'system' check (theme in ('system','light','dark')),
  push_notifications boolean not null default true,
  notify_likes boolean not null default true,
  notify_follows boolean not null default true,
  show_activity boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.follows (
  follower_id uuid not null references public.profiles(id) on delete cascade,
  following_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'accepted' check (status in ('pending','accepted')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (follower_id, following_id),
  constraint follows_no_self check (follower_id <> following_id)
);
create index if not exists follows_following_status_idx on public.follows (following_id, status, created_at desc);
create index if not exists follows_follower_status_idx on public.follows (follower_id, status, created_at desc);

-- -----------------------------------------------------------------------------
-- Feed posts and engagement
-- -----------------------------------------------------------------------------
create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  body text not null default '',
  background_index integer not null default -1,
  font_index integer not null default 0,
  text_color_index integer not null default -1,
  visibility text not null default 'public' check (visibility in ('public','followers','private')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists posts_feed_idx on public.posts (created_at desc);
create index if not exists posts_user_feed_idx on public.posts (user_id, created_at desc);

create table if not exists public.post_media (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  media_type text not null check (media_type in ('image','video')),
  storage_path text not null,
  poster_path text,
  mime_type text,
  width integer check (width is null or width > 0),
  height integer check (height is null or height > 0),
  duration_seconds numeric(10,3) check (duration_seconds is null or duration_seconds >= 0),
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  unique (post_id, sort_order)
);
create index if not exists post_media_post_idx on public.post_media (post_id, sort_order);

create table if not exists public.post_stickers (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  emoji text not null,
  position_x double precision not null default 0.5 check (position_x between 0 and 1),
  position_y double precision not null default 0.5 check (position_y between 0 and 1),
  scale double precision not null default 1 check (scale > 0 and scale <= 10),
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);
create index if not exists post_stickers_post_idx on public.post_stickers (post_id, sort_order);

create table if not exists public.post_likes (
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);
create index if not exists post_likes_user_idx on public.post_likes (user_id, created_at desc);

create table if not exists public.post_bookmarks (
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);
create index if not exists post_bookmarks_user_idx on public.post_bookmarks (user_id, created_at desc);

create table if not exists public.post_shares (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  share_target text,
  created_at timestamptz not null default now()
);
create index if not exists post_shares_post_idx on public.post_shares (post_id, created_at desc);
create index if not exists post_shares_user_idx on public.post_shares (user_id, created_at desc);

-- -----------------------------------------------------------------------------
-- Feed comments and comment likes (parent_id points to the top-level comment)
-- -----------------------------------------------------------------------------
create table if not exists public.comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  parent_id uuid references public.comments(id) on delete cascade,
  reply_to_user_id uuid references public.profiles(id) on delete set null,
  body text not null check (char_length(trim(body)) > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists comments_post_created_idx on public.comments (post_id, created_at desc);
create index if not exists comments_parent_created_idx on public.comments (parent_id, created_at asc);

create table if not exists public.comment_likes (
  comment_id uuid not null references public.comments(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (comment_id, user_id)
);

-- -----------------------------------------------------------------------------
-- Notifications
-- -----------------------------------------------------------------------------
create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  actor_id uuid references public.profiles(id) on delete set null,
  notification_type text not null check (notification_type in
    ('like','follow','comment','mention','reel_like','reel_comment','reel_repost','story_reaction')),
  message text not null default '',
  post_id uuid references public.posts(id) on delete cascade,
  comment_id uuid references public.comments(id) on delete cascade,
  reel_id uuid,
  reel_comment_id uuid,
  story_id uuid,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists notifications_recipient_idx on public.notifications (recipient_id, created_at desc);
create index if not exists notifications_unread_idx on public.notifications (recipient_id, created_at desc) where is_read = false;

-- -----------------------------------------------------------------------------
-- Reels, drafts, and engagement
-- -----------------------------------------------------------------------------
create table if not exists public.reels (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  caption text not null default '',
  video_path text not null,
  audio_path text,
  audio_name text not null default 'Original audio',
  poster_path text,
  playback_speed numeric(5,2) not null default 1 check (playback_speed > 0 and playback_speed <= 8),
  touch_strength numeric(4,3) not null default 0 check (touch_strength between 0 and 1),
  effect_index integer not null default 0,
  hue integer not null default 0,
  icon_index integer not null default 0,
  visibility text not null default 'public' check (visibility in ('public','followers','private')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists reels_feed_idx on public.reels (created_at desc);
create index if not exists reels_user_feed_idx on public.reels (user_id, created_at desc);

create table if not exists public.reel_drafts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  video_path text not null,
  audio_path text,
  audio_name text not null default 'Original audio',
  poster_path text,
  caption text not null default '',
  playback_speed numeric(5,2) not null default 1 check (playback_speed > 0 and playback_speed <= 8),
  touch_strength numeric(4,3) not null default 0 check (touch_strength between 0 and 1),
  effect_index integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists reel_drafts_user_idx on public.reel_drafts (user_id, updated_at desc);

create table if not exists public.reel_likes (
  reel_id uuid not null references public.reels(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (reel_id, user_id)
);
create table if not exists public.reel_bookmarks (
  reel_id uuid not null references public.reels(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (reel_id, user_id)
);
create index if not exists reel_bookmarks_user_idx on public.reel_bookmarks (user_id, created_at desc);

create table if not exists public.reel_reposts (
  reel_id uuid not null references public.reels(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (reel_id, user_id)
);

create table if not exists public.reel_shares (
  id uuid primary key default gen_random_uuid(),
  reel_id uuid not null references public.reels(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  share_target text,
  created_at timestamptz not null default now()
);

create table if not exists public.reel_comments (
  id uuid primary key default gen_random_uuid(),
  reel_id uuid not null references public.reels(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  parent_id uuid references public.reel_comments(id) on delete cascade,
  reply_to_user_id uuid references public.profiles(id) on delete set null,
  body text not null check (char_length(trim(body)) > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists reel_comments_reel_created_idx on public.reel_comments (reel_id, created_at desc);
create index if not exists reel_comments_parent_created_idx on public.reel_comments (parent_id, created_at asc);

create table if not exists public.reel_comment_likes (
  reel_comment_id uuid not null references public.reel_comments(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (reel_comment_id, user_id)
);

-- -----------------------------------------------------------------------------
-- Hashtags and moderation reports
-- -----------------------------------------------------------------------------
create table if not exists public.hashtags (
  id uuid primary key default gen_random_uuid(),
  tag text not null unique check (tag = lower(tag) and tag ~ '^[a-z0-9_]{1,100}$'),
  created_at timestamptz not null default now()
);

create table if not exists public.post_hashtags (
  post_id uuid not null references public.posts(id) on delete cascade,
  hashtag_id uuid not null references public.hashtags(id) on delete cascade,
  primary key (post_id, hashtag_id)
);
create index if not exists post_hashtags_tag_idx on public.post_hashtags (hashtag_id, post_id);

create table if not exists public.reel_hashtags (
  reel_id uuid not null references public.reels(id) on delete cascade,
  hashtag_id uuid not null references public.hashtags(id) on delete cascade,
  primary key (reel_id, hashtag_id)
);
create index if not exists reel_hashtags_tag_idx on public.reel_hashtags (hashtag_id, reel_id);

create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  target_user_id uuid references public.profiles(id) on delete cascade,
  post_id uuid references public.posts(id) on delete cascade,
  comment_id uuid references public.comments(id) on delete cascade,
  reel_id uuid references public.reels(id) on delete cascade,
  story_id uuid,
  reason text not null check (reason in ('spam','harassment','hate','violence','nudity','misinformation','other')),
  details text not null default '',
  status text not null default 'pending' check (status in ('pending','reviewing','resolved','dismissed')),
  created_at timestamptz not null default now(),
  constraint reports_exactly_one_target check (num_nonnulls(target_user_id, post_id, comment_id, reel_id, story_id) = 1)
);
create index if not exists reports_status_created_idx on public.reports (status, created_at desc);

-- -----------------------------------------------------------------------------
-- Stories (schema foundation; story publishing is not wired in this source version)
-- -----------------------------------------------------------------------------
create table if not exists public.stories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  media_type text not null check (media_type in ('image','video')),
  storage_path text not null,
  poster_path text,
  caption text not null default '',
  background_index integer not null default -1,
  font_index integer not null default 0,
  text_color_index integer not null default -1,
  visibility text not null default 'public' check (visibility in ('public','followers','private')),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '24 hours'),
  check (expires_at > created_at)
);
create index if not exists stories_active_idx on public.stories (expires_at desc, created_at desc);
create index if not exists stories_user_active_idx on public.stories (user_id, expires_at desc);

create table if not exists public.story_views (
  story_id uuid not null references public.stories(id) on delete cascade,
  viewer_id uuid not null references public.profiles(id) on delete cascade,
  viewed_at timestamptz not null default now(),
  primary key (story_id, viewer_id)
);

alter table public.notifications
  add constraint notifications_reel_fk foreign key (reel_id) references public.reels(id) on delete cascade;
alter table public.notifications
  add constraint notifications_story_fk foreign key (story_id) references public.stories(id) on delete cascade;
alter table public.notifications
  add constraint notifications_reel_comment_fk foreign key (reel_comment_id) references public.reel_comments(id) on delete cascade;
alter table public.reports
  add constraint reports_story_fk foreign key (story_id) references public.stories(id) on delete cascade;

create table if not exists public.story_reactions (
  id uuid primary key default gen_random_uuid(),
  story_id uuid not null references public.stories(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  emoji text not null,
  created_at timestamptz not null default now(),
  unique (story_id, user_id)
);

-- -----------------------------------------------------------------------------
-- Updated-at helpers and auth profile bootstrap
-- -----------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create or replace function public.create_profile_for_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  desired_username text;
  desired_name text;
begin
  desired_username := lower(regexp_replace(coalesce(new.raw_user_meta_data ->> 'username', ''), '[^a-zA-Z0-9_.]', '', 'g'));
  if desired_username !~ '^[a-z0-9_.]{3,30}$'
     or exists (select 1 from public.profiles p where lower(p.username) = desired_username) then
    desired_username := 'user_' || replace(substr(new.id::text, 1, 13), '-', '');
  end if;
  desired_name := coalesce(nullif(trim(new.raw_user_meta_data ->> 'display_name'), ''),
                           nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''),
                           nullif(split_part(coalesce(new.email, ''), '@', 1), ''),
                           'New user');
  insert into public.profiles (id, username, display_name)
  values (new.id, desired_username, desired_name)
  on conflict (id) do nothing;
  insert into public.user_settings (user_id)
  values (new.id)
  on conflict (user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_intly on auth.users;
create trigger on_auth_user_created_intly
after insert on auth.users
for each row execute function public.create_profile_for_new_auth_user();

create or replace function public.set_follow_status_for_private_account()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  target_private boolean;
begin
  select p.is_private into target_private from public.profiles p where p.id = new.following_id;
  if tg_op = 'INSERT' then
    if coalesce(target_private, false) then
      new.status := 'pending';
    else
      new.status := 'accepted';
    end if;
  end if;
  new.updated_at := now();
  return new;
end;
$$;

create or replace function public.can_view_profile(target_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = target_user_id
      and (
        p.id = auth.uid()
        or (not p.is_private and auth.uid() is not null)
        or exists (
          select 1 from public.follows f
          where f.follower_id = auth.uid()
            and f.following_id = p.id
            and f.status = 'accepted'
        )
      )
  );
$$;

create or replace function public.can_view_content(owner_user_id uuid, content_visibility text default 'public')
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = owner_user_id
      and (
        p.id = auth.uid()
        or (
          auth.uid() is not null
          and content_visibility <> 'private'
          and (
            (not p.is_private and content_visibility = 'public')
            or exists (
              select 1 from public.follows f
              where f.follower_id = auth.uid()
                and f.following_id = p.id
                and f.status = 'accepted'
            )
          )
        )
      )
  );
$$;

create or replace function public.can_view_post(target_post_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.posts p
    where p.id = target_post_id and public.can_view_content(p.user_id, p.visibility)
  );
$$;

create or replace function public.can_view_reel(target_reel_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.reels r
    where r.id = target_reel_id and public.can_view_content(r.user_id, r.visibility)
  );
$$;

create or replace function public.can_view_story(target_story_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.stories s
    where s.id = target_story_id
      and s.expires_at > now()
      and public.can_view_content(s.user_id, s.visibility)
  );
$$;

-- A reply must belong to the same post/reel and point to a top-level comment.
create or replace function public.validate_post_comment_parent()
returns trigger
language plpgsql
set search_path = public
as $$
declare parent_post uuid; parent_parent uuid;
begin
  if new.parent_id is not null then
    select c.post_id, c.parent_id into parent_post, parent_parent
    from public.comments c where c.id = new.parent_id;
    if parent_post is distinct from new.post_id or parent_parent is not null then
      raise exception 'A reply must point to a top-level comment on the same post';
    end if;
  end if;
  return new;
end;
$$;
create trigger validate_post_comment_parent_trg
before insert or update of parent_id, post_id on public.comments
for each row execute function public.validate_post_comment_parent();

create or replace function public.validate_reel_comment_parent()
returns trigger
language plpgsql
set search_path = public
as $$
declare parent_reel uuid; parent_parent uuid;
begin
  if new.parent_id is not null then
    select c.reel_id, c.parent_id into parent_reel, parent_parent
    from public.reel_comments c where c.id = new.parent_id;
    if parent_reel is distinct from new.reel_id or parent_parent is not null then
      raise exception 'A reply must point to a top-level comment on the same reel';
    end if;
  end if;
  return new;
end;
$$;
create trigger validate_reel_comment_parent_trg
before insert or update of parent_id, reel_id on public.reel_comments
for each row execute function public.validate_reel_comment_parent();

-- -----------------------------------------------------------------------------
-- Database-generated notifications for core social actions
-- -----------------------------------------------------------------------------
create or replace function public.notify_post_like()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare owner_id uuid;
begin
  select p.user_id into owner_id from public.posts p where p.id = new.post_id;
  if owner_id is not null and owner_id <> new.user_id then
    insert into public.notifications (recipient_id, actor_id, notification_type, message, post_id)
    values (owner_id, new.user_id, 'like', 'liked your post', new.post_id);
  end if;
  return new;
end;
$$;

create or replace function public.notify_new_comment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare owner_id uuid;
begin
  select p.user_id into owner_id from public.posts p where p.id = new.post_id;
  if owner_id is not null and owner_id <> new.user_id then
    insert into public.notifications (recipient_id, actor_id, notification_type, message, post_id, comment_id)
    values (owner_id, new.user_id, 'comment', 'commented: ' || left(new.body, 160), new.post_id, new.id);
  end if;
  return new;
end;
$$;

create or replace function public.notify_follow_activity()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    insert into public.notifications (recipient_id, actor_id, notification_type, message)
    values (new.following_id, new.follower_id, 'follow',
            case when new.status = 'pending' then 'requested to follow you' else 'started following you' end);
  elsif old.status = 'pending' and new.status = 'accepted' then
    insert into public.notifications (recipient_id, actor_id, notification_type, message)
    values (new.follower_id, new.following_id, 'follow', 'accepted your follow request');
  end if;
  return new;
end;
$$;

create or replace function public.notify_reel_like()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare owner_id uuid;
begin
  select r.user_id into owner_id from public.reels r where r.id = new.reel_id;
  if owner_id is not null and owner_id <> new.user_id then
    insert into public.notifications (recipient_id, actor_id, notification_type, message, reel_id)
    values (owner_id, new.user_id, 'reel_like', 'liked your reel', new.reel_id);
  end if;
  return new;
end;
$$;

create or replace function public.notify_new_reel_comment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare owner_id uuid;
begin
  select r.user_id into owner_id from public.reels r where r.id = new.reel_id;
  if owner_id is not null and owner_id <> new.user_id then
    insert into public.notifications (recipient_id, actor_id, notification_type, message, reel_id, reel_comment_id)
    values (owner_id, new.user_id, 'reel_comment', 'commented: ' || left(new.body, 160), new.reel_id, new.id);
  end if;
  return new;
end;
$$;

create or replace function public.notify_reel_repost()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare owner_id uuid;
begin
  select r.user_id into owner_id from public.reels r where r.id = new.reel_id;
  if owner_id is not null and owner_id <> new.user_id then
    insert into public.notifications (recipient_id, actor_id, notification_type, message, reel_id)
    values (owner_id, new.user_id, 'reel_repost', 'reposted your reel', new.reel_id);
  end if;
  return new;
end;
$$;

create or replace function public.notify_story_reaction()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare owner_id uuid;
begin
  select s.user_id into owner_id from public.stories s where s.id = new.story_id;
  if owner_id is not null and owner_id <> new.user_id then
    insert into public.notifications (recipient_id, actor_id, notification_type, message, story_id)
    values (owner_id, new.user_id, 'story_reaction', 'reacted ' || new.emoji || ' to your story', new.story_id);
  end if;
  return new;
end;
$$;

create trigger post_like_notification_trg after insert on public.post_likes
for each row execute function public.notify_post_like();
create trigger post_comment_notification_trg after insert on public.comments
for each row execute function public.notify_new_comment();
create trigger follow_notification_insert_trg after insert on public.follows
for each row execute function public.notify_follow_activity();
create trigger follow_notification_accept_trg after update of status on public.follows
for each row when (old.status = 'pending' and new.status = 'accepted')
execute function public.notify_follow_activity();
create trigger reel_like_notification_trg after insert on public.reel_likes
for each row execute function public.notify_reel_like();
create trigger reel_comment_notification_trg after insert on public.reel_comments
for each row execute function public.notify_new_reel_comment();
create trigger reel_repost_notification_trg after insert on public.reel_reposts
for each row execute function public.notify_reel_repost();
create trigger story_reaction_notification_trg after insert on public.story_reactions
for each row execute function public.notify_story_reaction();

-- updated_at triggers
drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at before update on public.profiles for each row execute function public.set_updated_at();
drop trigger if exists user_settings_set_updated_at on public.user_settings;
create trigger user_settings_set_updated_at before update on public.user_settings for each row execute function public.set_updated_at();
drop trigger if exists follows_set_updated_at on public.follows;
create trigger follows_set_updated_at before update on public.follows for each row execute function public.set_updated_at();
drop trigger if exists posts_set_updated_at on public.posts;
create trigger posts_set_updated_at before update on public.posts for each row execute function public.set_updated_at();
drop trigger if exists comments_set_updated_at on public.comments;
create trigger comments_set_updated_at before update on public.comments for each row execute function public.set_updated_at();
drop trigger if exists reels_set_updated_at on public.reels;
create trigger reels_set_updated_at before update on public.reels for each row execute function public.set_updated_at();
drop trigger if exists reel_drafts_set_updated_at on public.reel_drafts;
create trigger reel_drafts_set_updated_at before update on public.reel_drafts for each row execute function public.set_updated_at();
drop trigger if exists reel_comments_set_updated_at on public.reel_comments;
create trigger reel_comments_set_updated_at before update on public.reel_comments for each row execute function public.set_updated_at();

-- -----------------------------------------------------------------------------
-- Row Level Security
-- -----------------------------------------------------------------------------
alter table public.profiles enable row level security;
alter table public.user_settings enable row level security;
alter table public.follows enable row level security;
alter table public.posts enable row level security;
alter table public.post_media enable row level security;
alter table public.post_stickers enable row level security;
alter table public.post_likes enable row level security;
alter table public.post_bookmarks enable row level security;
alter table public.post_shares enable row level security;
alter table public.comments enable row level security;
alter table public.comment_likes enable row level security;
alter table public.notifications enable row level security;
alter table public.reels enable row level security;
alter table public.reel_drafts enable row level security;
alter table public.reel_likes enable row level security;
alter table public.reel_bookmarks enable row level security;
alter table public.reel_reposts enable row level security;
alter table public.reel_shares enable row level security;
alter table public.reel_comments enable row level security;
alter table public.reel_comment_likes enable row level security;
alter table public.hashtags enable row level security;
alter table public.post_hashtags enable row level security;
alter table public.reel_hashtags enable row level security;
alter table public.reports enable row level security;
alter table public.stories enable row level security;
alter table public.story_views enable row level security;
alter table public.story_reactions enable row level security;

-- Profiles and settings
create policy profiles_read_visible on public.profiles for select to authenticated using (public.can_view_profile(id));
create policy profiles_update_self on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());
create policy settings_read_self on public.user_settings for select to authenticated using (user_id = auth.uid());
create policy settings_insert_self on public.user_settings for insert to authenticated with check (user_id = auth.uid());
create policy settings_update_self on public.user_settings for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Follow relationships. A BEFORE trigger enforces pending status for private accounts.
create trigger follows_private_status_trg before insert or update of status on public.follows
for each row execute function public.set_follow_status_for_private_account();
create policy follows_read_visible on public.follows for select to authenticated
using (follower_id = auth.uid() or following_id = auth.uid()
       or (public.can_view_profile(follower_id) and public.can_view_profile(following_id)));
create policy follows_insert_self on public.follows for insert to authenticated
with check (follower_id = auth.uid() and follower_id <> following_id);
create policy follows_update_target on public.follows for update to authenticated
using (following_id = auth.uid()) with check (following_id = auth.uid() and status in ('pending','accepted'));
create policy follows_delete_participant on public.follows for delete to authenticated
using (follower_id = auth.uid() or following_id = auth.uid());

-- Posts and their attached media/stickers
create policy posts_read_visible on public.posts for select to authenticated
using (public.can_view_content(user_id, visibility));
create policy posts_insert_self on public.posts for insert to authenticated with check (user_id = auth.uid());
create policy posts_update_self on public.posts for update to authenticated
using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy posts_delete_self on public.posts for delete to authenticated using (user_id = auth.uid());

create policy post_media_read_visible on public.post_media for select to authenticated
using (public.can_view_post(post_id));
create policy post_media_insert_owner on public.post_media for insert to authenticated
with check (exists (select 1 from public.posts p where p.id = post_id and p.user_id = auth.uid()));
create policy post_media_update_owner on public.post_media for update to authenticated
using (exists (select 1 from public.posts p where p.id = post_id and p.user_id = auth.uid()))
with check (exists (select 1 from public.posts p where p.id = post_id and p.user_id = auth.uid()));
create policy post_media_delete_owner on public.post_media for delete to authenticated
using (exists (select 1 from public.posts p where p.id = post_id and p.user_id = auth.uid()));

create policy post_stickers_read_visible on public.post_stickers for select to authenticated
using (public.can_view_post(post_id));
create policy post_stickers_insert_owner on public.post_stickers for insert to authenticated
with check (exists (select 1 from public.posts p where p.id = post_id and p.user_id = auth.uid()));
create policy post_stickers_update_owner on public.post_stickers for update to authenticated
using (exists (select 1 from public.posts p where p.id = post_id and p.user_id = auth.uid()))
with check (exists (select 1 from public.posts p where p.id = post_id and p.user_id = auth.uid()));
create policy post_stickers_delete_owner on public.post_stickers for delete to authenticated
using (exists (select 1 from public.posts p where p.id = post_id and p.user_id = auth.uid()));

-- Post engagement
create policy post_likes_read_visible on public.post_likes for select to authenticated
using (public.can_view_post(post_id));
create policy post_likes_insert_self on public.post_likes for insert to authenticated
with check (user_id = auth.uid() and public.can_view_post(post_id));
create policy post_likes_delete_self on public.post_likes for delete to authenticated using (user_id = auth.uid());
create policy post_bookmarks_read_self on public.post_bookmarks for select to authenticated using (user_id = auth.uid());
create policy post_bookmarks_insert_self on public.post_bookmarks for insert to authenticated
with check (user_id = auth.uid() and public.can_view_post(post_id));
create policy post_bookmarks_delete_self on public.post_bookmarks for delete to authenticated using (user_id = auth.uid());
create policy post_shares_read_self on public.post_shares for select to authenticated using (user_id = auth.uid());
create policy post_shares_insert_self on public.post_shares for insert to authenticated
with check (user_id = auth.uid() and public.can_view_post(post_id));
create policy post_shares_delete_self on public.post_shares for delete to authenticated using (user_id = auth.uid());

-- Comments and comment likes
create policy comments_read_visible on public.comments for select to authenticated using (public.can_view_post(post_id));
create policy comments_insert_self on public.comments for insert to authenticated
with check (user_id = auth.uid() and public.can_view_post(post_id));
create policy comments_update_self on public.comments for update to authenticated
using (user_id = auth.uid()) with check (user_id = auth.uid() and public.can_view_post(post_id));
create policy comments_delete_author_or_post_owner on public.comments for delete to authenticated
using (user_id = auth.uid() or exists (select 1 from public.posts p where p.id = post_id and p.user_id = auth.uid()));
create policy comment_likes_read_visible on public.comment_likes for select to authenticated
using (exists (select 1 from public.comments c where c.id = comment_id and public.can_view_post(c.post_id)));
create policy comment_likes_insert_self on public.comment_likes for insert to authenticated
with check (user_id = auth.uid() and exists (select 1 from public.comments c where c.id = comment_id and public.can_view_post(c.post_id)));
create policy comment_likes_delete_self on public.comment_likes for delete to authenticated using (user_id = auth.uid());

-- Notifications are private to the recipient
create policy notifications_read_self on public.notifications for select to authenticated using (recipient_id = auth.uid());
create policy notifications_update_self on public.notifications for update to authenticated
using (recipient_id = auth.uid()) with check (recipient_id = auth.uid());
create policy notifications_delete_self on public.notifications for delete to authenticated using (recipient_id = auth.uid());

-- Reels and drafts
create policy reels_read_visible on public.reels for select to authenticated
using (public.can_view_content(user_id, visibility));
create policy reels_insert_self on public.reels for insert to authenticated with check (user_id = auth.uid());
create policy reels_update_self on public.reels for update to authenticated
using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy reels_delete_self on public.reels for delete to authenticated using (user_id = auth.uid());

create policy reel_drafts_read_self on public.reel_drafts for select to authenticated using (user_id = auth.uid());
create policy reel_drafts_insert_self on public.reel_drafts for insert to authenticated with check (user_id = auth.uid());
create policy reel_drafts_update_self on public.reel_drafts for update to authenticated
using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy reel_drafts_delete_self on public.reel_drafts for delete to authenticated using (user_id = auth.uid());

create policy reel_likes_read_visible on public.reel_likes for select to authenticated using (public.can_view_reel(reel_id));
create policy reel_likes_insert_self on public.reel_likes for insert to authenticated
with check (user_id = auth.uid() and public.can_view_reel(reel_id));
create policy reel_likes_delete_self on public.reel_likes for delete to authenticated using (user_id = auth.uid());
create policy reel_bookmarks_read_self on public.reel_bookmarks for select to authenticated using (user_id = auth.uid());
create policy reel_bookmarks_insert_self on public.reel_bookmarks for insert to authenticated
with check (user_id = auth.uid() and public.can_view_reel(reel_id));
create policy reel_bookmarks_delete_self on public.reel_bookmarks for delete to authenticated using (user_id = auth.uid());
create policy reel_reposts_read_visible on public.reel_reposts for select to authenticated using (public.can_view_reel(reel_id));
create policy reel_reposts_insert_self on public.reel_reposts for insert to authenticated
with check (user_id = auth.uid() and public.can_view_reel(reel_id));
create policy reel_reposts_delete_self on public.reel_reposts for delete to authenticated using (user_id = auth.uid());
create policy reel_shares_read_self on public.reel_shares for select to authenticated using (user_id = auth.uid());
create policy reel_shares_insert_self on public.reel_shares for insert to authenticated
with check (user_id = auth.uid() and public.can_view_reel(reel_id));
create policy reel_shares_delete_self on public.reel_shares for delete to authenticated using (user_id = auth.uid());

-- Reel comments and comment likes
create policy reel_comments_read_visible on public.reel_comments for select to authenticated using (public.can_view_reel(reel_id));
create policy reel_comments_insert_self on public.reel_comments for insert to authenticated
with check (user_id = auth.uid() and public.can_view_reel(reel_id));
create policy reel_comments_update_self on public.reel_comments for update to authenticated
using (user_id = auth.uid()) with check (user_id = auth.uid() and public.can_view_reel(reel_id));
create policy reel_comments_delete_author_or_reel_owner on public.reel_comments for delete to authenticated
using (user_id = auth.uid() or exists (select 1 from public.reels r where r.id = reel_id and r.user_id = auth.uid()));
create policy reel_comment_likes_read_visible on public.reel_comment_likes for select to authenticated
using (exists (select 1 from public.reel_comments c where c.id = reel_comment_id and public.can_view_reel(c.reel_id)));
create policy reel_comment_likes_insert_self on public.reel_comment_likes for insert to authenticated
with check (user_id = auth.uid() and exists (select 1 from public.reel_comments c where c.id = reel_comment_id and public.can_view_reel(c.reel_id)));
create policy reel_comment_likes_delete_self on public.reel_comment_likes for delete to authenticated using (user_id = auth.uid());

-- Hashtags and tag relations
create policy hashtags_read_authenticated on public.hashtags for select to authenticated using (true);
create policy hashtags_insert_authenticated on public.hashtags for insert to authenticated with check (true);
create policy post_hashtags_read_visible on public.post_hashtags for select to authenticated using (public.can_view_post(post_id));
create policy post_hashtags_insert_post_owner on public.post_hashtags for insert to authenticated
with check (exists (select 1 from public.posts p where p.id = post_id and p.user_id = auth.uid()));
create policy post_hashtags_delete_post_owner on public.post_hashtags for delete to authenticated
using (exists (select 1 from public.posts p where p.id = post_id and p.user_id = auth.uid()));
create policy reel_hashtags_read_visible on public.reel_hashtags for select to authenticated using (public.can_view_reel(reel_id));
create policy reel_hashtags_insert_reel_owner on public.reel_hashtags for insert to authenticated
with check (exists (select 1 from public.reels r where r.id = reel_id and r.user_id = auth.uid()));
create policy reel_hashtags_delete_reel_owner on public.reel_hashtags for delete to authenticated
using (exists (select 1 from public.reels r where r.id = reel_id and r.user_id = auth.uid()));

-- Reports: users can submit and see their own reports. Moderation status changes belong to service/admin.
create policy reports_insert_self on public.reports for insert to authenticated with check (reporter_id = auth.uid());
create policy reports_read_self on public.reports for select to authenticated using (reporter_id = auth.uid());

-- Stories (24-hour expiry is enforced when reading, not by deleting rows automatically)
create policy stories_read_visible on public.stories for select to authenticated
using (expires_at > now() and public.can_view_content(user_id, visibility));
create policy stories_insert_self on public.stories for insert to authenticated with check (user_id = auth.uid());
create policy stories_update_self on public.stories for update to authenticated
using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy stories_delete_self on public.stories for delete to authenticated using (user_id = auth.uid());
create policy story_views_read_author_or_viewer on public.story_views for select to authenticated
using (viewer_id = auth.uid() or exists (select 1 from public.stories s where s.id = story_id and s.user_id = auth.uid()));
create policy story_views_insert_self on public.story_views for insert to authenticated
with check (viewer_id = auth.uid() and public.can_view_story(story_id));
create policy story_views_update_self on public.story_views for update to authenticated
using (viewer_id = auth.uid()) with check (viewer_id = auth.uid());
create policy story_reactions_read_author_or_user on public.story_reactions for select to authenticated
using (user_id = auth.uid() or exists (select 1 from public.stories s where s.id = story_id and s.user_id = auth.uid()));
create policy story_reactions_insert_self on public.story_reactions for insert to authenticated
with check (user_id = auth.uid() and public.can_view_story(story_id));
create policy story_reactions_delete_self on public.story_reactions for delete to authenticated using (user_id = auth.uid());

-- Do not grant anonymous table access. Authenticated access is governed by RLS.
grant usage on schema public to authenticated;
revoke all on table
  public.profiles, public.user_settings, public.follows, public.posts, public.post_media,
  public.post_stickers, public.post_likes, public.post_bookmarks, public.post_shares,
  public.comments, public.comment_likes, public.notifications, public.reels, public.reel_drafts,
  public.reel_likes, public.reel_bookmarks, public.reel_reposts, public.reel_shares,
  public.reel_comments, public.reel_comment_likes, public.hashtags, public.post_hashtags,
  public.reel_hashtags, public.reports, public.stories, public.story_views, public.story_reactions
from anon;
revoke all on table
  public.profiles, public.user_settings, public.follows, public.posts, public.post_media,
  public.post_stickers, public.post_likes, public.post_bookmarks, public.post_shares,
  public.comments, public.comment_likes, public.notifications, public.reels, public.reel_drafts,
  public.reel_likes, public.reel_bookmarks, public.reel_reposts, public.reel_shares,
  public.reel_comments, public.reel_comment_likes, public.hashtags, public.post_hashtags,
  public.reel_hashtags, public.reports, public.stories, public.story_views, public.story_reactions
from authenticated;
grant select, insert, update, delete on table
  public.profiles, public.user_settings, public.follows, public.posts, public.post_media,
  public.post_stickers, public.post_likes, public.post_bookmarks, public.post_shares,
  public.comments, public.comment_likes, public.notifications, public.reels, public.reel_drafts,
  public.reel_likes, public.reel_bookmarks, public.reel_reposts, public.reel_shares,
  public.reel_comments, public.reel_comment_likes, public.hashtags, public.post_hashtags,
  public.reel_hashtags, public.reports, public.stories, public.story_views, public.story_reactions
to authenticated;

-- Limit sensitive updates to the columns the client actually needs to change.
revoke update on public.follows, public.notifications from authenticated;
grant update (status) on public.follows to authenticated;
grant update (is_read) on public.notifications to authenticated;

-- Functions used by RLS are available to authenticated users only.
revoke all on function public.can_view_profile(uuid) from public, anon;
revoke all on function public.can_view_content(uuid, text) from public, anon;
revoke all on function public.can_view_post(uuid) from public, anon;
revoke all on function public.can_view_reel(uuid) from public, anon;
revoke all on function public.can_view_story(uuid) from public, anon;
grant execute on function public.can_view_profile(uuid) to authenticated;
grant execute on function public.can_view_content(uuid, text) to authenticated;
grant execute on function public.can_view_post(uuid) to authenticated;
grant execute on function public.can_view_reel(uuid) to authenticated;
grant execute on function public.can_view_story(uuid) to authenticated;

-- Grant required access to trigger functions; they execute through their triggers.
revoke all on function public.create_profile_for_new_auth_user() from public, anon, authenticated;
revoke all on function public.set_updated_at() from public, anon, authenticated;
revoke all on function public.set_follow_status_for_private_account() from public, anon, authenticated;
revoke all on function public.validate_post_comment_parent() from public, anon, authenticated;
revoke all on function public.validate_reel_comment_parent() from public, anon, authenticated;
revoke all on function public.notify_post_like() from public, anon, authenticated;
revoke all on function public.notify_new_comment() from public, anon, authenticated;
revoke all on function public.notify_follow_activity() from public, anon, authenticated;
revoke all on function public.notify_reel_like() from public, anon, authenticated;
revoke all on function public.notify_new_reel_comment() from public, anon, authenticated;
revoke all on function public.notify_reel_repost() from public, anon, authenticated;
revoke all on function public.notify_story_reaction() from public, anon, authenticated;

