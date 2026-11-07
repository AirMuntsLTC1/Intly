import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// The last data the server returned for one user, saved as JSON. The app
/// shows it immediately on launch, then replaces it with fresh data.
class LocalCache {
  LocalCache._();

  static Future<File> _file(String uid) async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/intly_snapshot_$uid.json');
  }

  static Future<Map<String, dynamic>?> load(String uid) async {
    try {
      final f = await _file(uid);
      if (!await f.exists()) return null;
      final decoded = jsonDecode(await f.readAsString());
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null; // a damaged cache is ignored, not fatal
    }
  }

  /// Writes to a temporary file first, so a crash never leaves a half-written cache.
  static Future<void> save(String uid, Map<String, dynamic> data) async {
    final f = await _file(uid);
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(data), flush: true);
    await tmp.rename(f.path);
  }

  static Future<void> clear(String uid) async {
    final f = await _file(uid);
    if (await f.exists()) await f.delete();
  }
}
