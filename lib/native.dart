import 'dart:ffi';
import 'dart:io';
import 'dart:math' as math;

import 'package:ffi/ffi.dart';

/// Bridge to the C++ core (libintly_native.so). Every function has a pure-Dart
/// fallback, so the app keeps working if the library cannot be loaded.
///
/// The library is loaded once in [init] (called at startup, before the first
/// frame is drawn). Calls then cost a few microseconds and never touch disk.
class Native {
  Native._();

  static bool ok = false;
  static Duration initTime = Duration.zero;

  static int Function(Pointer<Utf8>)? _len;
  static double Function(int, int, int, double)? _score;
  static int Function(Pointer<Utf8>, Pointer<Utf8>, int)? _tags;
  static int Function(Pointer<Utf8>)? _hash;
  static int Function(Pointer<Utf8>)? _validUser;
  static int Function(Pointer<Utf8>, int, int, Pointer<Utf8>, int)? _hints;

  static void init() {
    final sw = Stopwatch()..start();
    try {
      if (!Platform.isAndroid) return;
      final lib = DynamicLibrary.open('libintly_native.so');
      _len = lib.lookupFunction<Int32 Function(Pointer<Utf8>), int Function(Pointer<Utf8>)>(
          'intly_text_length');
      _score = lib.lookupFunction<Double Function(Int32, Int32, Int32, Double),
          double Function(int, int, int, double)>('intly_hot_score');
      _tags = lib.lookupFunction<Int32 Function(Pointer<Utf8>, Pointer<Utf8>, Int32),
          int Function(Pointer<Utf8>, Pointer<Utf8>, int)>('intly_extract_tags');
      _hash = lib.lookupFunction<Uint64 Function(Pointer<Utf8>), int Function(Pointer<Utf8>)>(
          'intly_hash64');
      _validUser = lib.lookupFunction<Int32 Function(Pointer<Utf8>), int Function(Pointer<Utf8>)>(
          'intly_valid_username');
      _hints = lib.lookupFunction<
          Int32 Function(Pointer<Utf8>, Uint32, Int32, Pointer<Utf8>, Int32),
          int Function(Pointer<Utf8>, int, int, Pointer<Utf8>, int)>('intly_username_hints');
      ok = true;
    } catch (_) {
      ok = false;
    } finally {
      sw.stop();
      initTime = sw.elapsed;
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
      return (e + 1.0) / math.pow(hours + 2.0, 1.4);
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

  /// 64-bit hash of a string. Keys the in-memory media index. The same function
  /// is used for every key during one run, so the choice of implementation
  /// never changes the result within a session.
  static int hash(String s) {
    if (!ok) return s.hashCode;
    final p = s.toNativeUtf8();
    try {
      return _hash!(p);
    } finally {
      malloc.free(p);
    }
  }

  /// True when [s] is a valid @username (3-30 letters, digits, '_' or '.').
  static bool validUsername(String s) {
    final v = s.toLowerCase();
    if (!ok) return RegExp(r'^[a-z0-9_.]{3,30}$').hasMatch(v);
    final p = v.toNativeUtf8();
    try {
      return _validUser!(p) == 1;
    } finally {
      malloc.free(p);
    }
  }

  /// Offline username ideas (always valid, availability not checked).
  static List<String> usernameHints(String base, {int count = 5, int seed = 7}) {
    if (!ok) return _hintsDart(base, count, seed);
    final p = base.toNativeUtf8();
    const cap = 512;
    final out = malloc<Uint8>(cap).cast<Utf8>();
    try {
      final n = _hints!(p, seed, count, out, cap);
      if (n == 0) return const [];
      return out.toDartString().split('\n').where((e) => e.isNotEmpty).toList();
    } finally {
      malloc.free(p);
      malloc.free(out);
    }
  }

  static List<String> _hintsDart(String base, int count, int seed) {
    var stem = base
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_.]'), '');
    if (stem.length > 22) stem = stem.substring(0, 22);
    if (stem.length < 3) stem = 'intly';
    final rnd = math.Random(seed);
    final out = <String>[];
    for (var i = 0; out.length < count && i < count * 4; i++) {
      final cand = switch (i % 4) {
        0 => '${stem}_${10 + rnd.nextInt(90)}',
        1 => '$stem${100 + rnd.nextInt(8900)}',
        2 => '$stem.${10 + rnd.nextInt(90)}',
        _ => '${stem}_${100 + rnd.nextInt(900)}',
      };
      if (validUsername(cand) && !out.contains(cand)) out.add(cand);
    }
    return out;
  }
}
