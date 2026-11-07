import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show ValueNotifier, debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../state.dart';
import 'supabase_config.dart';

/// An error message that can be shown under a form.
class AuthFailure implements Exception {
  final String message;
  const AuthFailure(this.message);
  @override
  String toString() => message;
}

Map<String, dynamic>? _asMap(Object? v) => v is Map<String, dynamic> ? v : null;

class AuthService {
  AuthService._();

  /// Increases whenever a session is stored, so the app reacts straight away.
  static final ValueNotifier<int> tick = ValueNotifier<int>(0);

  static SupabaseClient get _client => Supabase.instance.client;

  static String? get email => SupabaseConfig.ready ? _client.auth.currentUser?.email : null;

  /// Calls the email-code-auth Edge Function (login, sign-up codes, password reset).
  static Future<Map<String, dynamic>> _call(Map<String, dynamic> body) async {
    if (!SupabaseConfig.keyIsSet) {
      throw const AuthFailure('Add your Supabase key in lib/auth/supabase_config.dart first.');
    }
    final http = HttpClient()..connectionTimeout = const Duration(seconds: 20);
    try {
      final req = await http
          .postUrl(Uri.parse('${SupabaseConfig.url}/functions/v1/email-code-auth'))
          .timeout(const Duration(seconds: 20));
      req.headers.set('apikey', SupabaseConfig.anonKey);
      req.headers.set('Authorization', 'Bearer ${SupabaseConfig.anonKey}');
      req.headers.set('Content-Type', 'application/json');
      req.write(jsonEncode(body));
      final res = await req.close().timeout(const Duration(seconds: 40));
      final text = await res.transform(utf8.decoder).join();

      Map<String, dynamic> data = {};
      try {
        data = _asMap(jsonDecode(text)) ?? {};
      } catch (_) {
        // Not JSON (for example a gateway error page): rely on the status code.
      }
      if (res.statusCode >= 400 || data['error'] != null) {
        final msg = data['error'];
        throw AuthFailure(msg is String ? msg : 'Request failed (${res.statusCode}). Try again.');
      }
      return data;
    } on TimeoutException {
      throw const AuthFailure('The server took too long. Please try again.');
    } on IOException {
      throw const AuthFailure('No connection to Intly. Check your internet and try again.');
    } finally {
      http.close(force: true);
    }
  }

  /// Stores a session returned by the Edge Function so the app stays logged in.
  static Future<void> _adopt(Map<String, dynamic>? session) async {
    if (session == null) {
      throw const AuthFailure('Could not start your session. Please log in.');
    }
    try {
      await _client.auth.recoverSession(jsonEncode(session));
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    }
    tick.value++;
  }

  static Future<void> signIn({required String email, required String password}) async {
    final data = await _call({'action': 'login', 'email': email, 'password': password});
    await _adopt(_asMap(data['session']));
  }

  static Future<void> requestSignupCode({
    required String username,
    required String displayName,
    required String email,
  }) async {
    await _call({
      'action': 'send_code',
      'purpose': 'signup',
      'email': email,
      'username': username,
      'display_name': displayName,
    });
  }

  static Future<void> confirmSignup({
    required String email,
    required String code,
    required String password,
  }) async {
    final data = await _call({
      'action': 'verify_code',
      'purpose': 'signup',
      'email': email,
      'code': code,
      'password': password,
    });
    await _adopt(_asMap(data['session']));
  }

  static Future<String> requestResetCode(String email) async {
    final data = await _call({'action': 'send_code', 'purpose': 'password_reset', 'email': email});
    return (data['message'] as String?) ?? 'If an account exists, a code was sent.';
  }

  static Future<String> confirmReset({
    required String email,
    required String code,
    required String password,
  }) async {
    final data = await _call({
      'action': 'verify_code',
      'purpose': 'password_reset',
      'email': email,
      'code': code,
      'password': password,
    });
    final session = _asMap(data['session']);
    if (session != null) await _adopt(session);
    return (data['message'] as String?) ?? 'Password updated.';
  }

  static Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      debugPrint('Sign out failed: $e');
    }
    tick.value++;
  }
}

/// Keeps the signed-in user's profile and settings in step with Supabase.
/// Loads them after login; saves local changes a moment after each edit.
class CloudSync {
  CloudSync(this.state);

  final AppState state;
  Timer? _debounce;
  bool _applying = false;
  String? _last;
  String? _userId;

  String _snapshot() => jsonEncode({
        'name': state.me.name,
        'bio': state.me.bio,
        'private': state.flags['private'] ?? false,
        'push': state.flags['push'] ?? true,
        'likes': state.flags['likes'] ?? true,
        'follows': state.flags['follows'] ?? true,
        'activity': state.flags['activity'] ?? true,
        'theme': state.mode.value,
      });

  void start(String userId) {
    _userId = userId;
    state.addListener(_onChanged);
    _pull();
  }

  void stop() {
    _debounce?.cancel();
    state.removeListener(_onChanged);
    _userId = null;
    _last = null;
  }

  void _onChanged() {
    if (_applying || _userId == null) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 900), _push);
  }

  Future<void> _pull() async {
    final uid = _userId;
    if (uid == null) return;
    try {
      final db = Supabase.instance.client;
      final profile = await db
          .from('profiles')
          .select('username, display_name, bio, is_private')
          .eq('id', uid)
          .maybeSingle();
      final settings = await db
          .from('user_settings')
          .select('theme, push_notifications, notify_likes, notify_follows, show_activity')
          .eq('user_id', uid)
          .maybeSingle();
      if (_userId != uid) return; // signed out while loading

      _applying = true;
      try {
        if (profile != null) {
          final username = profile['username'];
          if (username is String) state.me.handle = username;
          state.updateProfile(
            (profile['display_name'] as String?) ?? state.me.name,
            (profile['bio'] as String?) ?? '',
          );
          state.setFlag('private', profile['is_private'] == true);
        }
        if (settings != null) {
          state.setFlag('push', settings['push_notifications'] != false);
          state.setFlag('likes', settings['notify_likes'] != false);
          state.setFlag('follows', settings['notify_follows'] != false);
          state.setFlag('activity', settings['show_activity'] != false);
          final theme = settings['theme'];
          if (theme is String) state.setMode(theme);
        }
      } finally {
        _applying = false;
      }
      _last = _snapshot();
    } catch (e) {
      debugPrint('Profile sync (load) failed: $e');
    }
  }

  Future<void> _push() async {
    final uid = _userId;
    if (uid == null) return;
    final snap = _snapshot();
    if (snap == _last) return;
    try {
      final db = Supabase.instance.client;
      await db.from('profiles').update({
        'display_name': state.me.name,
        'bio': state.me.bio,
        'is_private': state.flags['private'] ?? false,
      }).eq('id', uid);
      await db.from('user_settings').update({
        'theme': state.mode.value,
        'push_notifications': state.flags['push'] ?? true,
        'notify_likes': state.flags['likes'] ?? true,
        'notify_follows': state.flags['follows'] ?? true,
        'show_activity': state.flags['activity'] ?? true,
      }).eq('user_id', uid);
      _last = snap;
    } catch (e) {
      debugPrint('Profile sync (save) failed: $e');
    }
  }
}
