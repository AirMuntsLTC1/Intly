import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth/auth_gate.dart';
import 'auth/supabase_config.dart';
import 'state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  try {
    await Supabase.initialize(url: SupabaseConfig.url, anonKey: SupabaseConfig.anonKey);
    SupabaseConfig.ready = true;
  } catch (e) {
    debugPrint('Supabase start failed: $e');
  }
  final state = AppState();
  await state.load();
  runApp(IntlyApp(state));
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
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Phone switched between light/dark: rebuild so "system" mode follows it.
  @override
  void didChangePlatformBrightness() => setState(() {});

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
              home: AuthGate(state: state),
            ),
          );
        },
      ),
    );
  }
}
