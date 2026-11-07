
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../screens/shell.dart';
import '../state.dart';
import '../theme.dart';
import 'auth_screens.dart';
import 'auth_service.dart';
import 'supabase_config.dart';

/// Shows the login screens when nobody is signed in, and the app when someone is.
/// Signing in loads that user's cache and then fresh data; signing out clears them.
class AuthGate extends StatefulWidget {
  final AppState state;
  const AuthGate({super.key, required this.state});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<AuthState>? _sub;
  String? _userId;

  @override
  void initState() {
    super.initState();
    AuthService.tick.addListener(_refresh);
    if (SupabaseConfig.ready) {
      _sub = Supabase.instance.client.auth.onAuthStateChange.listen((_) => _refresh());
    }
    _refresh();
  }

  @override
  void dispose() {
    AuthService.tick.removeListener(_refresh);
    _sub?.cancel();
    super.dispose();
  }

  void _refresh() {
    if (!SupabaseConfig.ready) return;
    final uid = Supabase.instance.client.auth.currentSession?.user.id;
    if (uid != _userId) {
      _userId = uid;
      if (uid == null) {
        widget.state.onSignedOut();
      } else {
        widget.state.onSignedIn();
      }
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!SupabaseConfig.keyIsSet || !SupabaseConfig.ready) {
      return _SetupNeeded(
        keyMissing: !SupabaseConfig.keyIsSet,
        error: SupabaseConfig.startError,
      );
    }
    final signedIn = Supabase.instance.client.auth.currentSession != null;
    return signedIn ? const Shell() : const LoginScreen();
  }
}

class _SetupNeeded extends StatelessWidget {
  final bool keyMissing;
  final String? error;
  const _SetupNeeded({required this.keyMissing, this.error});

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Scaffold(
      backgroundColor: p.bg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(LucideIcons.info, size: 40, color: p.sub),
            const SizedBox(height: 14),
            Text('Supabase is not connected yet.',
                textAlign: TextAlign.center, style: ts(p.text, 18, FontWeight.w800)),
            const SizedBox(height: 10),
            Text(
              keyMissing
                  ? 'This build has no Supabase key. Check that the GitHub secret SUPABASE_PUBLISHABLE_KEY exists with a value, then rebuild and install the newest APK.'
                  : 'Supabase could not start in this build.',
              textAlign: TextAlign.center,
              style: ts(p.sub, 15, FontWeight.w500, 1.4),
            ),
            if (error != null) ...[
              const SizedBox(height: 14),
              Text(error!, textAlign: TextAlign.center, style: ts(p.danger, 13, FontWeight.w600, 1.3)),
            ],
          ]),
        ),
      ),
    );
  }
}
