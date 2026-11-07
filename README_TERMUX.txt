INTLY — SUPABASE DATABASE BUNDLE
================================

This ZIP contains the initial Supabase database migration for the Intly app.
It creates 27 public tables, indexes, foreign keys, triggers, notification
creation, and Row Level Security (RLS) policies.

CONNECTED SUPABASE PROJECT
--------------------------
Project ref: ysjyyhgzhpdtdtrwqqwk
Project name: Intly-db

IMPORTANT
---------
* This bundle contains SQL schema only. It does not contain passwords, API keys,
  Personal Access Tokens, OAuth refresh tokens, or other credentials.
* Do not add SUPABASE_ACCESS_TOKEN, service-role keys, or Gmail OAuth secrets
  to this ZIP or to Flutter source code.
* Supabase Auth (auth.users) is the source of real user IDs. A profile and
  default settings row are created automatically when a new Auth user is made.
* The sample users in assets/seed.json are local demo data with IDs such as
  u1 and u2. They are intentionally NOT imported into the real database.
* Story tables are included as a foundation. The uploaded Intly source version
  does not yet connect story publishing to Supabase.
* Uploaded media itself is not included. The media tables store Storage paths;
  private Supabase Storage buckets and their object policies should be set up
  when the app's media upload/download code is connected.

INSTALL IN TERMUX
-----------------
1. Save intly_supabase_bundle.zip in Android Downloads.
2. In Termux, run:

   pkg install unzip -y
   cd ~/intly
   unzip -o ~/storage/downloads/intly_supabase_bundle.zip -d .

   If ~/storage/downloads does not exist, run `termux-setup-storage` once,
   allow the Android permission, and repeat the unzip command.

3. Confirm the migration file exists:

   ls -lh supabase/migrations/20261107000000_intly_initial_schema.sql

4. Ensure the project is linked (the project ref is already recorded above):

   supabase link --project-ref ysjyyhgzhpdtdtrwqqwk

   If the project is already linked, this command simply confirms/reselects it.

5. Review the pending migration before applying it:

   supabase migration list --linked
   supabase db push --dry-run --linked

6. Only after the dry run shows the intended migration, push it:

   supabase db push --linked

7. Verify the remote migration history:

   supabase migration list --linked

CLI VERSION NOTE
----------------
These commands use `--linked`, which is supported by the Supabase CLI version
reported in the Intly setup (v2.121.0).

MIGRATION HISTORY WARNING
-------------------------
The migration filename/version is 20261107000000. The earlier Intly setup
created a migration with this same filename. This ZIP intentionally replaces
that file with the complete schema. If `supabase migration list --linked`
shows version 20261107000000 as ALREADY APPLIED remotely, STOP and do not expect
editing the file to rerun it. Send the migration-list output so a safe follow-up
migration can be prepared instead.

WHAT IS CREATED
---------------
1. profiles
2. user_settings
3. follows
4. posts
5. post_media
6. post_stickers
7. post_likes
8. post_bookmarks
9. post_shares
10. comments
11. comment_likes
12. notifications
13. reels
14. reel_drafts
15. reel_likes
16. reel_bookmarks
17. reel_reposts
18. reel_shares
19. reel_comments
20. reel_comment_likes
21. hashtags
22. post_hashtags
23. reel_hashtags
24. reports
25. stories
26. story_views
27. story_reactions

SECURITY OVERVIEW
-----------------
* RLS is enabled on all 27 tables.
* Anonymous table access is revoked for these tables.
* Users can edit their own profiles, posts, reels, drafts, comments and settings.
* Private-account follow requests are stored as `pending`; the account owner
  can accept a request, after which it becomes `accepted`.
* Bookmarks and private drafts are visible only to their owner.
* Notifications are recipient-only and created by database triggers for core
  likes, comments, follows, reposts and story reactions.
* Reports can be submitted/read by the reporter. Moderation updates should be
  performed by a trusted server/admin process.
* The database does not contain any Gmail refresh token. Keep OAuth credentials
  inside Supabase Edge Function secrets.
