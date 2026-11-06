import 'package:flutter/material.dart';

const bgSets = <List<Color>>[
  [Color(0xFF7C5CFF), Color(0xFFFF5CA8)],
  [Color(0xFF00C6FF), Color(0xFF0072FF)],
  [Color(0xFFF7971E), Color(0xFFFFD200)],
  [Color(0xFF11998E), Color(0xFF38EF7D)],
  [Color(0xFFFF416C), Color(0xFFFF4B2B)],
  [Color(0xFF232526), Color(0xFF414345)],
  [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
  [Color(0xFFEE9CA7), Color(0xFFFFDDE1)],
  [Color(0xFF1D976C), Color(0xFF93F9B9)],
  [Color(0xFF2C3E50), Color(0xFF4CA1AF)],
];

class PostFont {
  final String name;
  final String? family;
  final FontWeight weight;
  final FontStyle style;
  const PostFont(this.name, this.family, this.weight, this.style);
}

const fonts = <PostFont>[
  PostFont('Classic', null, FontWeight.w400, FontStyle.normal),
  PostFont('Bold', null, FontWeight.w900, FontStyle.normal),
  PostFont('Serif', 'serif', FontWeight.w500, FontStyle.normal),
  PostFont('Mono', 'monospace', FontWeight.w500, FontStyle.normal),
  PostFont('Script', 'cursive', FontWeight.w500, FontStyle.normal),
  PostFont('Narrow', 'sans-serif-condensed', FontWeight.w600, FontStyle.normal),
  PostFont('Casual', 'casual', FontWeight.w500, FontStyle.normal),
  PostFont('Italic', null, FontWeight.w500, FontStyle.italic),
];

// 0 white, 1 black, rest are colorful
const textColors = <Color>[
  Color(0xFFFFFFFF), Color(0xFF111111), Color(0xFFFFD60A), Color(0xFFFF5CA8),
  Color(0xFF2EC27E), Color(0xFF1CB5E0), Color(0xFFFF6B35), Color(0xFF7C5CFF),
];

const stickerList = [
  '😀', '😍', '🥳', '😎', '🔥', '✨', '💖', '👍', '🎉', '🌈', '☀️', '🌙',
  '⭐', '🍕', '☕', '🎵', '🚀', '🌸', '🐶', '🐱', '👑', '💯', '🙌', '😂',
];

class Sticker {
  String e;
  double x, y, s;
  Sticker(this.e, this.x, this.y, [this.s = 1]);
  Sticker copy() => Sticker(e, x, y, s);
  List<dynamic> toJson() => [e, x, y, s];
  factory Sticker.fromJson(List<dynamic> j) =>
      Sticker(j[0] as String, (j[1] as num).toDouble(), (j[2] as num).toDouble(), (j[3] as num).toDouble());
}

TextStyle postStyle(int font, Color color, double size) {
  final f = fonts[font.clamp(0, fonts.length - 1)];
  return TextStyle(
    color: color,
    fontSize: size,
    fontFamily: f.family,
    fontWeight: f.weight,
    fontStyle: f.style,
    height: 1.35,
  );
}

