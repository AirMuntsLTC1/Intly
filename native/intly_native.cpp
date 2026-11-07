// Intly native core (C++17). Loaded from Dart through dart:ffi.
//
// Everything here is pure computation on plain buffers: no allocation that
// outlives a call, no exceptions, no globals. The Dart side keeps a pure-Dart
// fallback for each function, so the app still works if the library is missing.
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstring>

#define INTLY_EXPORT extern "C" __attribute__((visibility("default"))) __attribute__((used))

static inline bool is_word(unsigned char c) {
  return (c >= '0' && c <= '9') || (c >= 'a' && c <= 'z') ||
         (c >= 'A' && c <= 'Z') || c == '_' || c >= 0x80;
}

static inline char to_lower_ascii(char c) {
  return (c >= 'A' && c <= 'Z') ? static_cast<char>(c + 32) : c;
}

static inline bool is_username_char(char c) {
  return (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '_' || c == '.';
}

// Number of Unicode code points in a UTF-8 string.
INTLY_EXPORT int32_t intly_text_length(const char* s) {
  if (!s) return 0;
  int32_t n = 0;
  for (const unsigned char* p = reinterpret_cast<const unsigned char*>(s); *p; ++p)
    if ((*p & 0xC0) != 0x80) ++n;
  return n;
}

// "Hot" ranking: engagement decayed by age (hours).
INTLY_EXPORT double intly_hot_score(int32_t likes, int32_t comments,
                                    int32_t shares, double hours) {
  double e = likes + comments * 2.0 + shares * 3.0;
  return (e + 1.0) / std::pow(hours + 2.0, 1.4);
}

// Writes lowercase hashtags (without '#') separated by '\n'. Returns bytes written.
INTLY_EXPORT int32_t intly_extract_tags(const char* s, char* out, int32_t cap) {
  if (!s || !out || cap < 2) return 0;
  int32_t w = 0;
  size_t n = std::strlen(s);
  for (size_t i = 0; i < n; ++i) {
    if (s[i] != '#') continue;
    if (i > 0 && is_word(static_cast<unsigned char>(s[i - 1]))) continue;
    size_t st = i + 1, j = st;
    while (j < n && is_word(static_cast<unsigned char>(s[j]))) ++j;
    size_t len = j - st;
    if (len == 0) continue;
    if (w + static_cast<int32_t>(len) + 2 > cap) break;
    for (size_t k = st; k < j; ++k) out[w++] = to_lower_ascii(s[k]);
    out[w++] = '\n';
    i = j - 1;
  }
  out[w] = 0;
  return w;
}

// 64-bit FNV-1a hash of a NUL-terminated string. Used as the key of the
// media-cache index, so checking "is this file on the phone?" never touches disk.
INTLY_EXPORT uint64_t intly_hash64(const char* s) {
  if (!s) return 0;
  uint64_t h = 1469598103934665603ULL;
  for (const unsigned char* p = reinterpret_cast<const unsigned char*>(s); *p; ++p) {
    h ^= *p;
    h *= 1099511628211ULL;
  }
  return h;
}

// 1 when s is a valid Intly username (3-30 chars: a-z, 0-9, '_' and '.'),
// ignoring ASCII case. Mirrors the database rule profiles_username_format.
INTLY_EXPORT int32_t intly_valid_username(const char* s) {
  if (!s) return 0;
  size_t n = std::strlen(s);
  if (n < 3 || n > 30) return 0;
  for (size_t i = 0; i < n; ++i) {
    if (!is_username_char(to_lower_ascii(s[i]))) return 0;
  }
  return 1;
}

// Writes up to `count` username ideas derived from `base`, one per line, and
// returns the bytes written. Ideas are always valid usernames. Availability is
// NOT checked here: the server (suggest_usernames) does that. This is the
// offline fallback when the network is unavailable.
INTLY_EXPORT int32_t intly_username_hints(const char* base, uint32_t seed, int32_t count,
                                          char* out, int32_t cap) {
  if (!base || !out || cap < 2 || count <= 0) return 0;

  char stem[24];
  int32_t n = 0;
  for (const char* p = base; *p != 0 && n < 22; ++p) {
    char c = to_lower_ascii(*p);
    if (is_username_char(c)) stem[n++] = c;
  }
  stem[n] = 0;
  if (n < 3) {
    std::memcpy(stem, "intly", 6);  // includes the terminating NUL
    n = 5;
  }

  uint32_t r = seed * 2654435761u + 12345u;
  int32_t w = 0;
  int32_t made = 0;
  for (int32_t attempt = 0; attempt < count * 4 && made < count; ++attempt) {
    r = r * 1664525u + 1013904223u;
    uint32_t pick = r >> 8;
    char cand[40];
    int m = 0;
    switch (attempt % 4) {
      case 0: m = std::snprintf(cand, sizeof cand, "%s_%02u", stem, 10u + pick % 90u); break;
      case 1: m = std::snprintf(cand, sizeof cand, "%s%04u", stem, 100u + pick % 8900u); break;
      case 2: m = std::snprintf(cand, sizeof cand, "%s.%02u", stem, 10u + pick % 90u); break;
      default: m = std::snprintf(cand, sizeof cand, "%s_%03u", stem, 100u + pick % 900u); break;
    }
    if (m <= 0 || m > 30) continue;  // never emit an invalid username
    if (w + m + 1 > cap - 1) break;  // keep room for the terminating NUL
    std::memcpy(out + w, cand, static_cast<size_t>(m));
    w += m;
    out[w++] = '\n';
    ++made;
  }
  out[w] = 0;
  return w;
}
