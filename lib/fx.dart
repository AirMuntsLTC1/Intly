import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'styles.dart';
import 'theme.dart';
import 'widgets.dart';

enum Shape { heart, bookmark }

class ShapePainter extends CustomPainter {
  final Shape shape;
  final Color color;
  const ShapePainter(this.shape, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    final p = Path();
    if (shape == Shape.heart) {
      p.moveTo(12, 21.35);
      p.lineTo(10.55, 20.03);
      p.cubicTo(5.4, 15.36, 2, 12.28, 2, 8.5);
      p.cubicTo(2, 5.42, 4.42, 3, 7.5, 3);
      p.cubicTo(9.24, 3, 10.91, 3.81, 12, 5.09);
      p.cubicTo(13.09, 3.81, 14.76, 3, 16.5, 3);
      p.cubicTo(19.58, 3, 22, 5.42, 22, 8.5);
      p.cubicTo(22, 12.28, 18.6, 15.36, 13.45, 20.04);
      p.close();
    } else {
      p.moveTo(7, 3);
      p.lineTo(17, 3);
      p.quadraticBezierTo(19, 3, 19, 5);
      p.lineTo(19, 21);
      p.lineTo(12, 17);
      p.lineTo(5, 21);
      p.lineTo(5, 5);
      p.quadraticBezierTo(5, 3, 7, 3);
      p.close();
    }
    canvas.drawPath(p, Paint()..color = color..isAntiAlias = true);
  }

  @override
  bool shouldRepaint(ShapePainter o) => o.shape != shape || o.color != color;
}

/// Like / save button: fills with colour, bounces, and floats little shapes up.
/// [vertical] puts the count under the icon (reels); [size] is the outline icon size.
class ReactButton extends StatefulWidget {
  final Shape shape;
  final IconData icon;
  final bool active;
  final Color color, idle;
  final int? count;
  final VoidCallback onTap;
  final bool vertical;
  final double size;
  const ReactButton({
    super.key, required this.shape, required this.icon, required this.active,
    required this.color, required this.idle, required this.onTap, this.count,
    this.vertical = false, this.size = 20,
  });
  @override
  State<ReactButton> createState() => _ReactState();
}

class _ReactState extends State<ReactButton> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 800));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _tap() {
    final turningOn = !widget.active;
    widget.onTap();
    if (turningOn) _c.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final col = widget.active ? widget.color : widget.idle;
    final box = widget.size + 4;
    final iconBox = SizedBox(
      width: box,
      height: box,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          final bounce = t < 0.5 ? 1 + 0.45 * math.sin(math.pi * (t * 2)) : 1.0;
          return Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
            if (_c.isAnimating)
              for (int i = 0; i < 7; i++) _particle(i, t, box / 2),
            Transform.scale(
              scale: bounce,
              child: widget.active
                  ? CustomPaint(
                      size: Size(widget.size + 2, widget.size + 2),
                      painter: ShapePainter(widget.shape, widget.color))
                  : Icon(widget.icon, size: widget.size, color: widget.idle),
            ),
          ]);
        },
      ),
    );
    if (widget.vertical) {
      return Tap(
        onTap: _tap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            iconBox,
            if (widget.count != null) ...[
              const SizedBox(height: 3),
              Text(compact(widget.count!), style: ts(col, 12, FontWeight.w700)),
            ],
          ]),
        ),
      );
    }
    return Tap(
      onTap: _tap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(children: [
          iconBox,
          if (widget.count != null) ...[
            const SizedBox(width: 6),
            Text(compact(widget.count!), style: ts(col, 13, FontWeight.w600)),
          ],
        ]),
      ),
    );
  }

  Widget _particle(int i, double t, double half) {
    final e = Curves.easeOut.transform(t);
    final size = 9.0 + (i % 3) * 3;
    final dx = (i - 3) * 8.0 + math.sin(i * 1.7 + t * 6) * 5;
    final rise = 14 + e * (34 + (i % 3) * 10);
    return Positioned(
      left: half + dx - size / 2,
      top: half - rise - size / 2,
      child: Opacity(
        opacity: (1 - t).clamp(0.0, 1.0),
        child: CustomPaint(size: Size(size, size), painter: ShapePainter(widget.shape, widget.color)),
      ),
    );
  }
}

/// Coloured / image canvas with emoji stickers. Used by the feed and the editor.
class PostCanvas extends StatelessWidget {
  final int bg;
  final String? image;
  final List<Sticker> stickers;
  final double height;
  final Widget? center;
  final bool editable;
  final bool video; // shows a play badge over the poster
  final VoidCallback? onChanged;
  final VoidCallback? onTap;
  const PostCanvas({
    super.key, required this.bg, required this.image, required this.stickers,
    required this.height, this.center, this.editable = false, this.video = false,
    this.onChanged, this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final box = Container(
      height: height,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: p.card,
        gradient: bg >= 0
            ? LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight, colors: bgSets[bg % bgSets.length])
            : null,
      ),
      child: LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth, h = box.maxHeight;
        return Stack(fit: StackFit.expand, children: [
          if (image != null)
            Image.file(File(image!), fit: BoxFit.cover, cacheWidth: 900,
                errorBuilder: (_, __, ___) => const SizedBox.shrink()),
          if (center != null) Center(child: Padding(padding: const EdgeInsets.all(22), child: center)),
          for (final st in stickers) _sticker(st, w, h),
          if (video)
            Center(
              child: Container(
                width: 56, height: 56,
                decoration: const BoxDecoration(color: Color(0x99000000), shape: BoxShape.circle),
                child: const Icon(LucideIcons.play, size: 28, color: Colors.white),
              ),
            ),
        ]);
      }),
    );
    return onTap == null ? box : GestureDetector(onTap: onTap, child: box);
  }

  Widget _sticker(Sticker st, double w, double h) {
    final size = 46.0 * st.s;
    final child = SizedBox(
      width: size, height: size,
      child: Center(child: Text(st.e, style: TextStyle(fontSize: size * .72))),
    );
    return Positioned(
      left: st.x * w - size / 2,
      top: st.y * h - size / 2,
      child: editable
          ? GestureDetector(
              onPanUpdate: (d) {
                st.x = (st.x + d.delta.dx / w).clamp(0.04, 0.96);
                st.y = (st.y + d.delta.dy / h).clamp(0.06, 0.94);
                onChanged?.call();
              },
              onTap: () {
                st.s = st.s >= 2.2 ? 0.7 : st.s + 0.5;
                onChanged?.call();
              },
              onLongPress: () {
                stickers.remove(st);
                onChanged?.call();
              },
              child: child,
            )
          : child,
    );
  }
}
