import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Keeps photos and videos on the phone, so the feed opens instantly and works
/// offline for anything already seen. Files live under
/// <app support>/media/<bucket>/<storage path>.
class MediaCache {
  MediaCache._();

  static late String _root;

  /// Must run once at startup, before any screen reads media.
  static Future<void> init() async {
    final dir = await getApplicationSupportDirectory();
    _root = '${dir.path}/media';
  }

  static String _full(String bucket, String path) => '$_root/$bucket/$path';

  /// The local file path if the media is already on the phone, otherwise null.
  static String? peek(String bucket, String path) {
    final f = File(_full(bucket, path));
    return f.existsSync() ? f.path : null;
  }

  /// Downloads a Storage file once and returns its local path.
  static Future<String> fetch(String bucket, String path) async {
    final dst = File(_full(bucket, path));
    if (dst.existsSync()) return dst.path;
    final bytes = await Supabase.instance.client.storage.from(bucket).download(path);
    await dst.parent.create(recursive: true);
    final tmp = File('${dst.path}.part');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(dst.path);
    return dst.path;
  }

  /// Keeps a copy of a file this phone just uploaded, so it never needs a download.
  static Future<void> adopt(String bucket, String path, File source) async {
    final dst = File(_full(bucket, path));
    await dst.parent.create(recursive: true);
    await source.copy(dst.path);
  }

  /// Removes every cached file (used on sign-out).
  static Future<void> clear() async {
    final dir = Directory(_root);
    if (dir.existsSync()) await dir.delete(recursive: true);
  }
}
