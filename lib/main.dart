import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'auth/auth_gate.dart';
import 'data/app_bootstrap.dart';
import 'state.dart';
import 'theme.dart';

final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // Start loading the cache and connecting now. The window opens at once.
  final _ = AppBootstrap.started;
  runApp(IntlyApp(AppBootstrap.state));
}

class IntlyApp extends StatefulWidget {
  final AppState state;
  const IntlyApp(this.state, {super.key});
  @override
  State<IntlyApp> createState() => _IntlyAppState();
}

class _IntlyAppState extends State<IntlyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.state.notice.addListener(_showNotice);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.state.notice.removeListener(_showNotice);
    super.dispose();
  }

  // A save or upload failed: tell the user once.
  void _showNotice() {
    final message = widget.state.notice.value;
    if (message == null) return;
    widget.state.notice.value = null;
    messengerKey.currentState?.showSnackBar(SnackBar(content: Text(message)));
  }

  // Phone switched between light/dark: rebuild so "system" mode follows it.
  @override
  void didChangePlatformBrightness() => setState(() {});

  // Back in the app: pull fresh data in the background.
  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.resumed) widget.state.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return Scope(
      state: state,
      child: ValueListenableBuilder<String>(
        valueListenable: state.mode,
        builder: (context, mode, _) {
          final sys = PlatformDispatcher.instance.platformBrightness == Brightness.dark;
          final dark = mode == 'dark' || (mode == 'system' && sys);
          final p = dark ? Pal.dark : Pal.light;
          final icons = dark ? Brightness.light : Brightness.dark;
          SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: icons,
            systemNavigationBarColor: p.bg,
            systemNavigationBarIconBrightness: icons,
          ));
          return PalScope(
            pal: p,
            child: MaterialApp(
              title: 'Intly',
              debugShowCheckedModeBanner: false,
              scrollBehavior: const NoGlow(),
              scaffoldMessengerKey: messengerKey,
              theme: ThemeData(
                useMaterial3: false,
                brightness: dark ? Brightness.dark : Brightness.light,
                scaffoldBackgroundColor: p.bg,
                splashFactory: NoSplash.splashFactory,
                highlightColor: Colors.transparent,
                textSelectionTheme: TextSelectionThemeData(
                  cursorColor: p.accent,
                  selectionHandleColor: p.accent,
                  selectionColor: p.accent.withAlpha(80),
                ),
              ),
              // Until the cache and Supabase are ready, show only the background colour.
              home: FutureBuilder<void>(
                future: AppBootstrap.started,
                builder: (context, snap) => snap.connectionState == ConnectionState.done
                    ? AuthGate(state: state)
                    : ColoredBox(color: p.bg),
              ),
            ),
          );
        },
      ),
    );
  }
}
