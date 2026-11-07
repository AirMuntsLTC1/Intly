# Intly 1.3.5 — changes

## 1.3.5
- Your profile: a "Suggestions People" section under Posts, Reels, Followers and
  Following. It shows up to 10 people, scrollable sideways, with photo, name,
  mutual count and a Follow button.
- "See all" opens a full-screen Discover people list. Mutuals come first, then
  Suggested for you.
- Fixed: a tap on a button inside a card or row (for example Follow on a post,
  or the heart on a post) also opened that post or profile. Buttons now absorb
  their own tap.

# Intly 1.3.4 — changes

## 1.3.4
- New welcome screen: Intly wordmark, three swipeable taglines that move on by
  themselves, and two buttons: Create account and Sign in. No logo or icon badges.
- Sign in, create account and forgot password use the same simpler layout, with
  floating labels, a brand-colour focus border, and friendlier wording.
- Sign-in, sign-up, email code and password reset work as before.

# Intly 1.3.3 — changes

## 1.3.3
- Light mode is the default for everyone. The app no longer follows the phone's
  light or dark setting. Settings now offers Light and Dark only.
- Database: migration 20261107060000_intly_default_light_theme.sql changes the
  default to light and converts existing "system" preferences to light.

# Intly 1.3.2 — changes

## 1.3.2
- Profile photo picker shows photos only. Post composer shows photos and videos.
  Reels picker shows videos only. Each picker has its own media library, so one
  kind of permission can no longer hide the other kind.
- Edit profile: username suggestions appear automatically as you type (checked on
  the server, so each one is free). The availability check says when a username
  is already taken.
- Edit profile: a notice (not a block) when another account already uses the same
  display name, since names do not have to be unique.

# Intly 1.3.1 — changes

## 1.3.1
- Follow button in the post header moved to the top-right corner, beside the menu.
- Liking, saving, reposting, sharing, commenting or deleting a reel while it is still
  uploading no longer sends the temporary id to the database ("invalid input syntax
  for type uuid"). Those writes wait for the upload to finish.

## 1.3.0

## Fixed
- Follow button on other users' profiles could not be tapped: it sat outside the
  header's bounds. It now sits inside the header, and it animates between
  Follow / Requested / Following.
- Follow button now appears next to @username on every post in the feed.
- Private accounts show "Requested" immediately instead of "Following".
- Reel heart and save felt delayed: the reel surface no longer has a double-tap
  recognizer that delayed every tap. Buttons respond when the finger lifts.
  Double-tap to like still works.
- Media checks no longer touch the disk during screen builds (in-memory index,
  built once at startup). Reel grid tiles use the thumbnail, not a video decode.
- Follow requests are idempotent (no error on a repeated tap).
- Duplicate-username errors show a readable message.

## Added
- Profile photos (avatars bucket, private to people who can see the profile).
- Edit profile: photo picker, name and @username fields, 7-day cooldowns
  (enforced in the database), username availability check, and suggestions.
- Profile header shows Posts, Reels, Followers, Following.
- Reel thumbnails (thumbnail_path on reels and drafts).
- C++ core: username validation, username suggestions (offline), 64-bit key
  hash for the media index. Each has a pure-Dart fallback.
- Startup timing log (`Intly startup: ...`) for native load and cache readiness.

## Database
Run the new migration:  supabase db push
(supabase/migrations/20261107050000_intly_profile_cooldowns_avatars.sql)

## Not verified yet
- The Dart code has not been compiled. Run `flutter analyze` and build the APK
  in GitHub Actions before installing.
- The reel-delay and feed-jank fixes are based on code reading, not a device
  test. Check on a real phone.
- Not yet done: Explore, Settings and the other screens still need the broader
  redesign you asked for.
