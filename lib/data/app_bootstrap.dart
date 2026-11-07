import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/supabase_config.dart';
import '../state.dart';

/// Startup. Both steps start at once and neither waits for the other:
///   1. The saved data is read from disk, so the feed can show immediately.
///   2. Supabase connects and restores the saved login.
/// The app window opens before either finishes. AuthGate then decides which
/// screen to show, and a refresh from Supabase follows after sign-in.
class AppBootstrap {
  AppBootstrap._();

  static final AppState state = AppState();

  /// Completes when the cache is read and Supabase is connected.
  static final Future<void> started = _start();

  static Future<void> _start() async {
    await Future.wait<void>([_connect(), state.start()]);
  }

  static Future<void> _connect() async {
    if (!SupabaseConfig.keyIsSet) return;
    try {
      await Supabase.initialize(url: SupabaseConfig.url, anonKey: SupabaseConfig.anonKey);
      SupabaseConfig.ready = true;
    } catch (e) {
      SupabaseConfig.startError = e.toString();
      debugPrint('Supabase start failed: $e');
    }
  }
}
