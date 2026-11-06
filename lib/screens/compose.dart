import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../fx.dart';
import '../media_picker.dart';
import '../native.dart';
import '../state.dart';
import '../styles.dart';
import '../theme.dart';
import '../widgets.dart';

enum _Panel { none, bg, font, color, sticker }

class ComposeScreen extends StatefulWidget {
  final Post? edit;
  const ComposeScreen({super.key, this.edit});
  @override
  State<ComposeScreen> createState() => _ComposeState();
}

class _ComposeState extends State<ComposeScreen> {
  static const max = 280;
  late final TextEditingController _c = TextEditingController(text: widget.edit?.text ?? '');
  late int _bg = widget.edit?.bg ?? -1;
  late int _font = widget.edit?.font ?? 0;
  late int _tc = widget.edit?.tcolor ?? -1;
  late String? _img = widget.edit?.image;
  late final List<Sticker> _st = [...?widget.edit?.stickers.map((e) => e.copy())];
  _Panel _panel = _Panel.none;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  bool get _canvas => _bg >= 0 || _img != null || _st.isNotEmpty;

  Color _color(Pal p) =>
      _tc >= 0 ? textColors[_tc] : (_bg >= 0 ? Colors.white : p.text);

  void _togglePanel(_Panel x) => setState(() => _panel = _panel == x ? _Panel.none : x);

  Future<void> _pick() async {
    FocusScope.of(context).unfocus();
    try {
      // asks for photo permission (system dialog) the first time, then opens our own picker
      await MediaLibrary.I.requestAccess();
      if (!mounted) return;
      final path = await pickMedia(context);
      if (path == null || !mounted) return;
      setState(() {
        _img = path;
        _bg = -1;
        if (_tc == 0 || _tc == 1) _tc = -1;
      });
    } catch (_) {
      if (mounted) toast(context, 'Could not open gallery');
    }
  }

  void _setBg(int i) => setState(() {
        _bg = i;
        if (i >= 0) _img = null;
        if (i < 0 && (_tc == 0 || _tc == 1)) _tc = -1;
      });

  Widget _field(Pal p, bool onBg) => TextField(
        controller: _c,
        maxLines: null,
        minLines: onBg ? 1 : 3,
        textAlign: onBg ? TextAlign.center : TextAlign.start,
        onChanged: (_) => setState(() {}),
        style: postStyle(_font, _color(p), onBg ? 24 : 18),
        cursorColor: onBg ? Colors.white : p.accent,
        decoration: InputDecoration.collapsed(
          hintText: onBg ? 'Type something...' : "What's happening?",
          hintStyle: postStyle(_font, onBg ? Colors.white70 : p.sub, onBg ? 24 : 18),
        ),
      );

  Widget _circle(Pal p, {required Widget child, required bool on, required VoidCallback onTap, Gradient? g, Color? fill}) =>
      Tap(
        onTap: onTap,
        child: Container(
          width: 40, height: 40,
          margin: const EdgeInsets.only(right: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: g,
            color: fill ?? p.card,
            border: Border.all(color: on ? p.accent : p.line, width: on ? 3 : 1.5),
          ),
          child: child,
        ),
      );

  Widget _panelView(Pal p) {
    switch (_panel) {
      case _Panel.bg:
        return _row([
          _circle(p, on: _bg < 0, onTap: () => _setBg(-1), child: Icon(LucideIcons.x, size: 18, color: p.sub)),
          for (int i = 0; i < bgSets.length; i++)
            _circle(p, on: _bg == i, onTap: () => _setBg(i), child: const SizedBox.shrink(),
                g: LinearGradient(colors: bgSets[i])),
        ]);
      case _Panel.font:
        return _row([
          for (int i = 0; i < fonts.length; i++)
            Tap(
              onTap: () => setState(() => _font = i),
              child: Container(
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  color: _font == i ? p.accent : p.card,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(fonts[i].name,
                    style: postStyle(i, _font == i ? Colors.white : p.text, 16)),
              ),
            ),
        ]);
      case _Panel.color:
        return _row([
          _circle(p, on: _tc < 0, onTap: () => setState(() => _tc = -1),
              child: Text('A', style: ts(p.sub, 16, FontWeight.w800))),
          for (int i = _bg >= 0 || _img != null ? 0 : 2; i < textColors.length; i++)
            _circle(p, on: _tc == i, fill: textColors[i], onTap: () => setState(() => _tc = i),
                child: const SizedBox.shrink()),
        ]);
      case _Panel.sticker:
        return SizedBox(
          height: 126,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Wrap(spacing: 4, runSpacing: 4, children: [
              for (final e in stickerList)
                Tap(
                  onTap: () => setState(() {
                    _st.add(Sticker(e, 0.3 + (_st.length % 5) * 0.1, 0.35 + (_st.length % 4) * 0.1));
                  }),
                  child: SizedBox(width: 46, height: 46, child: Center(child: Text(e, style: const TextStyle(fontSize: 28)))),
                ),
            ]),
          ),
        );
      case _Panel.none:
        return const SizedBox.shrink();
    }
  }

  Widget _row(List<Widget> kids) => SizedBox(
        height: 64,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          scrollDirection: Axis.horizontal,
          children: kids,
        ),
      );

  Widget _tool(Pal p, Widget icon, bool on, VoidCallback onTap) => Expanded(
        child: Tap(
          onTap: onTap,
          child: Container(
            height: 46,
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: on ? p.accent.withAlpha(40) : null, borderRadius: BorderRadius.circular(12)),
              child: icon,
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final s = context.s;
    final text = _c.text.trim();
    final len = Native.length(_c.text);
    final over = len > max;
    final tags = Native.tags(_c.text).toSet().toList();
    final can = (text.isNotEmpty || _img != null || _st.isNotEmpty) && !over;
    final editing = widget.edit != null;
    final onBg = _bg >= 0;
    return Scaffold(
      backgroundColor: p.bg,
      body: Column(children: [
        TopBar(editing ? 'Edit post' : 'New post', back: true, actions: [
          GradBtn(editing ? 'Save' : 'Post', can
              ? () {
                  s.publish(
                    edit: widget.edit, text: text, bg: _bg, font: _font, tcolor: _tc,
                    image: _img, stickers: _st,
                  );
                  Navigator.of(context).pop(true);
                }
              : null),
          const SizedBox(width: 6),
        ]),
        Expanded(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Avatar(s.me, 40),
                const SizedBox(width: 10),
                Text(s.me.name, style: ts(p.text, 16, FontWeight.w700)),
              ]),
              const SizedBox(height: 14),
              if (onBg)
                PostCanvas(
                  bg: _bg, image: null, stickers: _st, height: 280, editable: true,
                  onChanged: () => setState(() {}),
                  center: _field(p, true),
                )
              else ...[
                _field(p, false),
                if (_canvas) ...[
                  const SizedBox(height: 12),
                  Stack(children: [
                    PostCanvas(
                      bg: -1, image: _img, stickers: _st, height: _img != null ? 280 : 200,
                      editable: true, onChanged: () => setState(() {}),
                    ),
                    if (_img != null)
                      Positioned(
                        top: 10, right: 10,
                        child: Tap(
                          onTap: () => setState(() => _img = null),
                          child: Container(
                            width: 32, height: 32,
                            decoration: const BoxDecoration(color: Color(0x99000000), shape: BoxShape.circle),
                            child: const Icon(LucideIcons.x, size: 18, color: Colors.white),
                          ),
                        ),
                      ),
                  ]),
                ],
              ],
              if (_st.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('Drag stickers to move · tap to resize · hold to remove',
                      style: ts(p.sub, 12)),
                ),
              if (tags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Wrap(spacing: 8, runSpacing: 6, children: [
                    for (final t in tags.take(6))
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: p.accent.withAlpha(30), borderRadius: BorderRadius.circular(12)),
                        child: Text('#$t', style: ts(p.accent, 13, FontWeight.w700)),
                      ),
                  ]),
                ),
            ]),
          ),
        ),
        Container(
          decoration: BoxDecoration(color: p.bg, border: Border(top: BorderSide(color: p.line))),
          child: SafeArea(
            top: false,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child: _panelView(p),
              ),
              Row(children: [
                _tool(p, Icon(LucideIcons.image, size: 22, color: _img != null ? p.accent : p.sub), false, _pick),
                _tool(p, Icon(LucideIcons.palette, size: 22, color: _panel == _Panel.bg || onBg ? p.accent : p.sub),
                    _panel == _Panel.bg, () => _togglePanel(_Panel.bg)),
                _tool(p, Icon(LucideIcons.type, size: 22, color: _panel == _Panel.font || _font != 0 ? p.accent : p.sub),
                    _panel == _Panel.font, () => _togglePanel(_Panel.font)),
                _tool(
                    p,
                    Container(
                      width: 22, height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _tc >= 0 ? textColors[_tc] : p.card,
                        border: Border.all(color: _panel == _Panel.color ? p.accent : p.sub, width: 2),
                      ),
                    ),
                    _panel == _Panel.color, () => _togglePanel(_Panel.color)),
                _tool(p, Icon(LucideIcons.smile, size: 22, color: _panel == _Panel.sticker || _st.isNotEmpty ? p.accent : p.sub),
                    _panel == _Panel.sticker, () => _togglePanel(_Panel.sticker)),
                Padding(
                  padding: const EdgeInsets.only(right: 16, left: 4),
                  child: Text('$len/$max', style: ts(over ? p.danger : p.sub, 12, FontWeight.w700)),
                ),
              ]),
            ]),
          ),
        ),
      ]),
    );
  }
}

