INTLY - SUPABASE LOGIN UPDATE
=============================

WHAT THIS UPDATE ADDS
---------------------
* Log in, Create account (email code), Forgot password (email code + new password)
  Lucide icons, inline error messages, show/hide password.
* Stays logged in after closing the app (session is saved on the phone).
* Log out: Settings > Account > Log out.
* Profile and settings sync with Supabase after login:
  display name, bio, private account, theme, notification and activity switches.
* Internet permission added to the release APK (release builds need it to reach Supabase).

NOT YET CONNECTED (still saved on the phone only)
-------------------------------------------------
Posts, comments, likes, follows, reels, saved items and photos/videos.
Connecting those needs Supabase Storage buckets for media and rewriting
lib/state.dart to read and write the tables. That is the next step.

INSTALL IN TERMUX
-----------------
1. Unzip this over your project (it only overwrites the files listed here):

   cd ~/intly
   unzip -o ~/storage/downloads/intly_auth_update.zip -d .

2. Paste your anon / publishable key:

   nano lib/auth/supabase_config.dart

   Replace PASTE_YOUR_ANON_KEY_HERE with the key from
   Supabase Dashboard > Project Settings > API.
   Use the "anon" key (starts with eyJ) if you can, or the publishable key.
   Never use the service_role or secret key.

3. Check that the database migrations are applied to the linked project:

   supabase migration list --linked

   Rows 20261107010000, 20261107020000 and 20261107030000 must show in both
   columns. If the Remote column is empty for any of them, run:

   supabase db push --linked --dry-run
   supabase db push --linked

4. Redeploy the sign-in function (it is a public endpoint and does its own checks):

   supabase functions deploy email-code-auth --linked --no-verify-jwt

   If you get "Invalid JWT" or 401 when signing in, this step fixes it.

5. Commit and push. GitHub builds the APK:

   cd ~/intly
   git add .
   git commit -m "Supabase login, register, forgot password, logout"
   git push

   Download the APK from Actions > Build Intly > Intly-arm64-apk.

NOTES
-----
* Email codes are sent from the Gmail account configured in the Supabase secrets.
  Gmail has daily sending limits. Anyone can request codes for any email address,
  so consider adding a captcha (Cloudflare Turnstile) later.
* The sign-up screen tells the user when a username is taken. That reveals which
  usernames exist. This is a small trade-off, and it can be removed if you prefer.
* Never commit lib/auth/supabase_config.dart with a service_role or secret key.
