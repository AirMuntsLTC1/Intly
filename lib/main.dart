import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/shell.dart';
import 'state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final state = AppState();
  await state.load();
  runApp(IntlyApp(state));
}

class IntlyApp extends StatelessWidget {
  final AppState state;
  const IntlyApp(this.state, {super.key});

  @override
  Widget build(BuildContext context) {
    return Scope(
      state: state,
      child: ValueListenableBuilder<bool>(
        valueListenable: state.dark,
        builder: (context, dark, _) {
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
              home: const Shell(),
            ),
          );
        },
      ),
    );
  }
}
