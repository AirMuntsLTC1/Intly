import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

/// Bridge to the C++ core (libintly_native.so). Falls back to pure Dart if missing.
class Native {
  static bool ok = false;
  static int Function(Pointer<Utf8>)? _len;
  static double Function(int, int, int, double)? _score;
  static int Function(Pointer<Utf8>, Pointer<Utf8>, int)? _tags;

  static void init() {
    try {
      if (!Platform.isAndroid) return;
      final lib = DynamicLibrary.open('libintly_native.so');
      _len = lib.lookupFunction<Int32 Function(Pointer<Utf8>),
          int Function(Pointer<Utf8>)>('intly_text_length');
      _score = lib.lookupFunction<Double Function(Int32, Int32, Int32, Double),
          double Function(int, int, int, double)>('intly_hot_score');
      _tags = lib.lookupFunction<
          Int32 Function(Pointer<Utf8>, Pointer<Utf8>, Int32),
          int Function(Pointer<Utf8>, Pointer<Utf8>, int)>('intly_extract_tags');
      ok = true;
    } catch (_) {
      ok = false;
    }
  }

  static int length(String s) {
    if (!ok) return s.runes.length;
    final p = s.toNativeUtf8();
    try {
      return _len!(p);
    } finally {
      malloc.free(p);
    }
  }

  static double hot(int likes, int comments, int shares, double hours) {
    if (!ok) {
      final e = likes + comments * 2.0 + shares * 3.0;
      return (e + 1.0) / _pow(hours + 2.0, 1.4);
    }
    return _score!(likes, comments, shares, hours);
  }

  static List<String> tags(String s) {
    if (!ok) {
      return RegExp(r'(?:^|[^A-Za-z0-9_])#([A-Za-z0-9_]+)')
          .allMatches(s)
          .map((m) => m.group(1)!.toLowerCase())
          .toList();
    }
    const cap = 512;
    final p = s.toNativeUtf8();
    final out = malloc<Uint8>(cap).cast<Utf8>();
    try {
      final n = _tags!(p, out, cap);
      if (n == 0) return const [];
      return out.toDartString().split('\n').where((e) => e.isNotEmpty).toList();
    } finally {
      malloc.free(p);
      malloc.free(out);
    }
  }

  static double _pow(double a, double b) {
    // exp(b * ln a) without dart:math import clutter
    double x = b * _ln(a);
    double r = 1, t = 1;
    for (int i = 1; i < 40; i++) {
      t *= x / i;
      r += t;
    }
    return r;
  }

  static double _ln(double a) {
    double y = (a - 1) / (a + 1), y2 = y * y, s = 0, t = y;
    for (int i = 1; i < 60; i += 2) {
      s += t / i;
      t *= y2;
    }
    return 2 * s;
  }
}
