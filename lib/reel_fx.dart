
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Index of the Reels tab in the bottom navigation / IndexedStack.
const reelsTab = 5;

const reelSpeeds = <double>[0.3, 0.5, 1, 2, 3];
const reelLengths = <int>[15, 30, 60, 1200]; // seconds
String reelLengthLabel(int s) => s >= 120 ? '${s ~/ 60}m' : '$s';

class ReelEffect {
  final String name;
  final IconData icon;
  final List<double>? matrix; // 4x5 colour matrix, null = no effect
  const ReelEffect(this.name, this.icon, this.matrix);
}

List<double> _sat(double s) {
  const r = .2126, g = .7152, b = .0722;
  final i = 1 - s;
  return [
    r * i + s, g * i, b * i, 0, 0,
    r * i, g * i + s, b * i, 0, 0,
    r * i, g * i, b * i + s, 0, 0,
    0, 0, 0, 1, 0,
  ];
}

/// Colour-grade effects: applied live on the camera preview and again on playback.
const reelEffects = <ReelEffect>[
  ReelEffect('No effect', LucideIcons.ban, null),
  ReelEffect('Noir', LucideIcons.moon, [
    .2126, .7152, .0722, 0, 0,
    .2126, .7152, .0722, 0, 0,
    .2126, .7152, .0722, 0, 0,
    0, 0, 0, 1, 0,
  ]),
  ReelEffect('Warm', LucideIcons.sun, [
    1.12, 0, 0, 0, 6,
    0, 1.0, 0, 0, 0,
    0, 0, .86, 0, -6,
    0, 0, 0, 1, 0,
  ]),
  ReelEffect('Cool', LucideIcons.snowflake, [
    .9, 0, 0, 0, -4,
    0, 1.0, 0, 0, 0,
    0, 0, 1.16, 0, 8,
    0, 0, 0, 1, 0,
  ]),
  ReelEffect('Vivid', LucideIcons.sparkles, [
    1, 0, 0, 0, 0,
    0, 1, 0, 0, 0,
    0, 0, 1, 0, 0,
    0, 0, 0, 1, 0,
  ]),
  ReelEffect('Sepia', LucideIcons.coffee, [
    .393, .769, .189, 0, 0,
    .349, .686, .168, 0, 0,
    .272, .534, .131, 0, 0,
    0, 0, 0, 1, 0,
  ]),
  ReelEffect('Fade', LucideIcons.cloud, [
    .85, 0, 0, 0, 30,
    0, .85, 0, 0, 30,
    0, 0, .85, 0, 30,
    0, 0, 0, 1, 0,
  ]),
  ReelEffect('Dream', LucideIcons.heart, [
    1.05, 0, .05, 0, 10,
    0, .95, .05, 0, 0,
    .1, 0, 1.1, 0, 16,
    0, 0, 0, 1, 0,
  ]),
];

/// Saturated "Vivid" matrix is built at runtime (const lists cannot call functions).
List<double>? effectMatrix(int fx) {
  if (fx == 4) return _sat(1.6);
  return reelEffects[fx.clamp(0, reelEffects.length - 1).toInt()].matrix;
}

/// Wraps [child] (camera preview or video) with the chosen effect and touch-up.
Widget reelFx(Widget child, int fx, double touch) {
  Widget w = child;
  if (touch > 0.01) {
    final sigma = touch * 1.8;
    w = ImageFiltered(
      imageFilter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.clamp),
      child: w,
    );
  }
  final m = effectMatrix(fx);
  if (m != null) w = ColorFiltered(colorFilter: ColorFilter.matrix(m), child: w);
  return w;
}
