// Intly native core (C++17). Loaded from Dart through dart:ffi.
#include <cmath>
#include <cstdint>
#include <cstring>

#define INTLY_EXPORT extern "C" __attribute__((visibility("default"))) __attribute__((used))

static inline bool is_word(unsigned char c) {
  return (c >= '0' && c <= '9') || (c >= 'a' && c <= 'z') ||
         (c >= 'A' && c <= 'Z') || c == '_' || c >= 0x80;
}

// Number of Unicode code points in a UTF-8 string.
INTLY_EXPORT int32_t intly_text_length(const char* s) {
  if (!s) return 0;
  int32_t n = 0;
  for (const unsigned char* p = (const unsigned char*)s; *p; ++p)
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
    if (i > 0 && is_word((unsigned char)s[i - 1])) continue;
    size_t st = i + 1, j = st;
    while (j < n && is_word((unsigned char)s[j])) ++j;
    size_t len = j - st;
    if (len == 0) continue;
    if (w + (int32_t)len + 2 > cap) break;
    for (size_t k = st; k < j; ++k) {
      char c = s[k];
      if (c >= 'A' && c <= 'Z') c += 32;
      out[w++] = c;
    }
    out[w++] = '\n';
    i = j - 1;
  }
  out[w] = 0;
  return w;
}

