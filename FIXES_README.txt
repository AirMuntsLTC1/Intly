INTLY - REELS, FOLLOW, SPEED AND STARTUP FIXES
==============================================

Unzip this inside your project root (~/intly) and answer "yes" to overwrite.

CHANGED FILES
  lib/state.dart                 separate upload queue, pending-change overlay,
                                 faster startup, on-demand reel video download
  lib/main.dart                  window opens at once; save errors shown as messages
  lib/data/app_bootstrap.dart    cache and Supabase start in parallel
  lib/data/local_cache.dart      reads and writes JSON off the UI thread
  lib/data/intly_repository.dart clearer "file too large" message
  lib/media_picker.dart          reels picker shows videos only; size limit message
  lib/widgets.dart               Follow / Following label animates
  lib/screens/reels.dart         reel video reuse, poster while loading,
                                 animated Follow, "Posting reel..." indicator

STEP 1 - Raise the upload size limit (needed for bigger videos)
  Supabase Dashboard > Storage > Settings > "Upload file size limit".
  The default is 50 MB. Set it to the size you want (e.g. 150 MB).
  Free plans cap the limit at 50 MB; larger limits need a paid plan.
  Then, in lib/media_picker.dart, set kMaxVideoBytes to the same value:
      const int kMaxVideoBytes = 150 * 1024 * 1024;
  Keep it at 50 * 1024 * 1024 if you stay on the default.

STEP 2 - Commit and build
  git add -A
  git commit -m "Fix reels upload, follow label, reel speed and startup"
  git push

STEP 3 - Test
  1. Post 3 reels in a row. Each one should show "Posting reel..." and then appear.
  2. Tap Follow on a profile. The label should change at once and animate.
  3. Like, save and comment on reels. They should respond at once.
  4. Close the app and reopen it. The feed should show before the network responds.
  5. Scroll away from a reel and back. Its video should start without a long wait.
