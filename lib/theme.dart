import 'package:flutter/material.dart';
import 'state.dart';

class Pal {
  final Color bg, card, text, sub, line, accent, accent2, danger;
  const Pal({
    required this.bg, required this.card, required this.text, required this.sub,
    required this.line, required this.accent, required this.accent2, required this.danger,
  });
  static const dark = Pal(
    bg: Color(0xFF0B0B10), card: Color(0xFF16161F), text: Color(0xFFF4F4F8),
    sub: Color(0xFF8D8DA0), line: Color(0xFF23232E), accent: Color(0xFF7C5CFF),
    accent2: Color(0xFFFF5CA8), danger: Color(0xFFFF4D6A),
  );
  static const light = Pal(
    bg: Color(0xFFFFFFFF), card: Color(0xFFF3F3F8), text: Color(0xFF12121A),
    sub: Color(0xFF72728A), line: Color(0xFFE8E8F0), accent: Color(0xFF6D4AFF),
    accent2: Color(0xFFFF4E9B), danger: Color(0xFFE5304F),
  );
  LinearGradient get grad => LinearGradient(
      colors: [accent, accent2], begin: Alignment.topLeft, end: Alignment.bottomRight);
}

class PalScope extends InheritedWidget {
  final Pal pal;
  const PalScope({super.key, required this.pal, required super.child});
  static Pal of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<PalScope>()!.pal;
  @override
  bool updateShouldNotify(PalScope o) => o.pal != pal;
}

extension Ctx on BuildContext {
  Pal get p => PalScope.of(this);
  AppState get s => Scope.of(this);
}

TextStyle ts(Color c, double size, [FontWeight w = FontWeight.w400, double? h]) =>
    TextStyle(color: c, fontSize: size, fontWeight: w, height: h);

class NoGlow extends ScrollBehavior {
  const NoGlow();
  @override
  Widget buildOverscrollIndicator(BuildContext c, Widget child, ScrollableDetails d) => child;
  @override
  ScrollPhysics getScrollPhysics(BuildContext c) => const ClampingScrollPhysics();
}
