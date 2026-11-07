import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/supabase_config.dart';
import '../state.dart';

/// Startup, in order:
///   1. Supabase connects (restores the saved login session if there is one).
///   2. AppState starts: native code, media cache, and the cached snapshot.
/// AuthGate then calls AppState.onSignedIn(), which refreshes from Supabase.
class AppBootstrap {
  AppBootstrap._();

  static Future<AppState> run() async {
    if (SupabaseConfig.keyIsSet) {
      try {
        await Supabase.initialize(url: SupabaseConfig.url, anonKey: SupabaseConfig.anonKey);
        SupabaseConfig.ready = true;
      } catch (e) {
        SupabaseConfig.startError = e.toString();
        debugPrint('Supabase start failed: $e');
      }
    }
    final state = AppState();
    await state.start();
    return state;
  }
}
