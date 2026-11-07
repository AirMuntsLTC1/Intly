
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show ValueNotifier, debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';

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
      throw const AuthFailure('This app build has no Supabase key. Add the GitHub secret SUPABASE_PUBLISHABLE_KEY and rebuild.');
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

