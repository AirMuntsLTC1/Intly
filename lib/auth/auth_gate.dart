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
class AuthGate extends StatefulWidget {
  final AppState state;
  const AuthGate({super.key, required this.state});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<AuthState>? _sub;
  CloudSync? _cloud;
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
    _cloud?.stop();
    super.dispose();
  }

  void _refresh() {
    if (!SupabaseConfig.ready) return;
    final uid = Supabase.instance.client.auth.currentSession?.user.id;
    if (uid != _userId) {
      _cloud?.stop();
      _cloud = uid == null ? null : (CloudSync(widget.state)..start(uid));
      _userId = uid;
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!SupabaseConfig.ready || !SupabaseConfig.keyIsSet) {
      return const _SetupNeeded();
    }
    final signedIn = Supabase.instance.client.auth.currentSession != null;
    return signedIn ? const Shell() : const LoginScreen();
  }
}

class _SetupNeeded extends StatelessWidget {
  const _SetupNeeded();

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Scaffold(
      backgroundColor: p.bg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(LucideIcons.info, size: 40, color: p.sub),
            const SizedBox(height: 14),
            Text('Supabase is not connected yet.',
                textAlign: TextAlign.center, style: ts(p.text, 18, FontWeight.w800)),
            const SizedBox(height: 10),
            Text(
              'Open lib/auth/supabase_config.dart, paste your anon key, then rebuild the app.',
              textAlign: TextAlign.center,
              style: ts(p.sub, 15, FontWeight.w500, 1.4),
            ),
          ]),
        ),
      ),
    );
  }
}
