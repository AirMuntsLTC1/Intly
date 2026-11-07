# Intly Supabase schema

The migration at `supabase/migrations/20261107000000_intly_initial_schema.sql`
creates the first server-side schema for the uploaded Intly Flutter app.

## Table groups

| Group | Tables |
|---|---|
| Accounts | `profiles`, `user_settings` |
| Social graph | `follows` |
| Feed | `posts`, `post_media`, `post_stickers`, `post_likes`, `post_bookmarks`, `post_shares` |
| Feed discussion | `comments`, `comment_likes` |
| Notifications | `notifications` |
| Reels | `reels`, `reel_drafts`, `reel_likes`, `reel_bookmarks`, `reel_reposts`, `reel_shares` |
| Reel discussion | `reel_comments`, `reel_comment_likes` |
| Discovery | `hashtags`, `post_hashtags`, `reel_hashtags` |
| Moderation | `reports` |
| Stories foundation | `stories`, `story_views`, `story_reactions` |

## Important relationships

- `profiles.id` references `auth.users.id`; a trigger creates a profile and
  default settings row for each new Supabase Auth user.
- Media tables store Storage object paths, not the binary image/video data.
- `comments.parent_id` and `reel_comments.parent_id` point to a top-level
  comment in the same post/reel, matching Intly's reply threading model.
- A private profile's new follow requests are inserted as `pending`; the
  account owner can update the relationship to `accepted`.
- Story records expire after 24 hours by default. Expired rows are hidden by
  RLS but are not automatically deleted.

## Source alignment and limits

This schema models the local state structures found in `lib/state.dart` and
related Intly screens: profile name/bio and privacy settings, follows, posts,
post text styling/stickers/media, post comments/replies/likes/bookmarks/shares,
reels and drafts, reel comments/replies/likes/bookmarks/reposts/shares,
hashtags, and notifications.

The uploaded source still reads its demo users, posts, comments, notifications,
and reels from `assets/seed.json`, and writes much of the current user's
activity to `SharedPreferences`. Applying this migration creates the database;
it does **not** automatically switch the Flutter app from local storage to
Supabase. That app integration is a separate next step.

Story tables are included as a database foundation, but story publishing is not
implemented in this source version. Storage buckets/policies and actual media
upload/download code are also separate from this database migration.
