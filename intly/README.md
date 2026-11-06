# Intly

Simple, fast social app. **Flutter** (UI, Lucide icons) + **C++** (native core via FFI) + **Python** (data tooling).

## Screens
Home (stories + feed, animated like and save) · Explore (search, trending, who to follow) · Compose (custom media picker) ·
Notifications (tap opens the post and highlights the comment; tap the avatar opens the profile) ·
Profile (own + others) · Edit profile · Post detail + comments · Report post · Settings

## Build with GitHub (Termux)
```bash
pkg install git unzip python
unzip intly.zip && cd intly
git init && git add . && git commit -m "Intly"
git branch -M main
git remote add origin https://github.com/YOUR_USER/intly.git
git push -u origin main
```
Open the repo > **Actions** > *Build Intly (arm64 APK)* > download artifact **Intly-arm64-apk**.
First build ~6-8 min, cached builds are much faster.

## Layout
- `lib/` Flutter app  - `native/intly_native.cpp` C++ core (hashtags, UTF-8 length, hot ranking)
- `tools/gen_seed.py` Python demo-data generator  - `.github/workflows/build.yml` CI

