import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../native.dart';

/// Keeps photos, videos and thumbnails on the phone, so the feed opens instantly
/// and works offline for anything already seen. Files live under
/// <app support>/media/<bucket>/<storage path>.
///
/// [peek] runs on every screen rebuild, so it never touches the disk. Instead,
/// [init] indexes the folder once (in the background, off the UI thread) and
/// keeps a set of 64-bit keys, computed by the C++ core, for the files present.
class MediaCache {
  MediaCache._();

  static late String _root;
  static final Set<int> _known = <int>{};

  /// Must run once at startup, after [Native.init], before any screen reads media.
  static Future<void> init() async {
    final dir = await getApplicationSupportDirectory();
    _root = '${dir.path}/media';
    await _indexFolder();
  }

  static Future<void> _indexFolder() async {
    _known.clear();
    final root = Directory(_root);
    if (!await root.exists()) return;
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File || entity.path.endsWith('.part')) continue;
      final rel = entity.path.substring(_root.length + 1);
      _known.add(Native.hash(rel));
    }
  }

  static String _rel(String bucket, String path) => '$bucket/$path';

  /// The local file path if the media is already on the phone, otherwise null.
  /// Pure memory lookup: safe to call from build().
  static String? peek(String bucket, String path) {
    final rel = _rel(bucket, path);
    if (!_known.contains(Native.hash(rel))) return null;
    return '$_root/$rel';
  }

  /// Downloads a Storage file once and returns its local path.
  static Future<String> fetch(String bucket, String path) async {
    final rel = _rel(bucket, path);
    final key = Native.hash(rel);
    final dst = File('$_root/$rel');
    if (_known.contains(key) && dst.existsSync()) return dst.path;
    final bytes = await Supabase.instance.client.storage.from(bucket).download(path);
    await dst.parent.create(recursive: true);
    final tmp = File('${dst.path}.part');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(dst.path);
    _known.add(key);
    return dst.path;
  }

  /// Keeps a copy of a file this phone just uploaded, so it never needs a download.
  static Future<void> adopt(String bucket, String path, File source) async {
    final dst = File('$_root/${_rel(bucket, path)}');
    await dst.parent.create(recursive: true);
    await source.copy(dst.path);
    _known.add(Native.hash(_rel(bucket, path)));
  }

  /// Removes every cached file (used on sign-out).
  static Future<void> clear() async {
    _known.clear();
    final dir = Directory(_root);
    if (dir.existsSync()) await dir.delete(recursive: true);
  }
}
