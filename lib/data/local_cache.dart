import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show compute;
import 'package:path_provider/path_provider.dart';

/// The last data the server returned for one user, saved as JSON. The app
/// shows it right away on launch, then replaces it with fresh data.
///
/// Reading and writing big JSON runs in a background isolate, so the UI never
/// stalls while the cache loads.
class LocalCache {
  LocalCache._();

  static Future<Directory> _dir() => getApplicationSupportDirectory();

  static Future<File> _file(String uid) async =>
      File('${(await _dir()).path}/intly_snapshot_$uid.json');

  static Future<File> _lastFile() async => File('${(await _dir()).path}/intly_last_uid.txt');

  /// The user who was signed in last, so the cache can load before Supabase
  /// connects. Empty or missing means nothing is cached yet.
  static Future<String?> lastUid() async {
    try {
      final f = await _lastFile();
      if (!f.existsSync()) return null;
      final uid = (await f.readAsString()).trim();
      return uid.isEmpty ? null : uid;
    } catch (_) {
      return null;
    }
  }

  static Future<void> setLastUid(String uid) async {
    await (await _lastFile()).writeAsString(uid, flush: true);
  }

  static Future<void> clearLastUid() async {
    final f = await _lastFile();
    if (f.existsSync()) await f.delete();
  }

  static Future<Map<String, dynamic>?> load(String uid) async {
    try {
      final f = await _file(uid);
      if (!f.existsSync()) return null;
      final text = await f.readAsString();
      final decoded = await compute(jsonDecode, text);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null; // a damaged cache is ignored, not fatal
    }
  }

  /// Writes to a temporary file first, so a crash never leaves a half-written cache.
  static Future<void> save(String uid, Map<String, dynamic> data) async {
    final f = await _file(uid);
    final text = await compute(jsonEncode, data);
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(text, flush: true);
    await tmp.rename(f.path);
  }

  static Future<void> clear(String uid) async {
    final f = await _file(uid);
    if (f.existsSync()) await f.delete();
  }
}
