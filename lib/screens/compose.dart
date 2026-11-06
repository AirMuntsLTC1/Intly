import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../native.dart';
import '../theme.dart';
import '../widgets.dart';

class ComposeScreen extends StatefulWidget {
  const ComposeScreen({super.key});
  @override
  State<ComposeScreen> createState() => _ComposeState();
}

class _ComposeState extends State<ComposeScreen> {
  static const max = 280;
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final s = context.s;
    final text = _c.text.trim();
    final len = Native.length(_c.text);
    final over = len > max;
    final tags = Native.tags(_c.text).toSet().toList();
    return Scaffold(
      backgroundColor: p.bg,
      body: Column(children: [
        TopBar('New post', back: true, actions: [
          GradBtn('Post', text.isEmpty || over
              ? null
              : () {
                  s.addPost(text);
                  Navigator.of(context).pop(true);
                }),
          const SizedBox(width: 6),
        ]),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Avatar(s.me, 44),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _c,
                  autofocus: true,
                  maxLines: null,
                  onChanged: (_) => setState(() {}),
                  style: ts(p.text, 18, FontWeight.w400, 1.4),
                  cursorColor: p.accent,
                  decoration: InputDecoration.collapsed(
                      hintText: "What's happening?", hintStyle: ts(p.sub, 18)),
                ),
              ),
            ]),
          ),
        ),
        Container(
          decoration: BoxDecoration(border: Border(top: BorderSide(color: p.line))),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: SafeArea(
            top: false,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (tags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
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
              Row(children: [
                Icon(LucideIcons.image, size: 22, color: p.accent),
                const SizedBox(width: 18),
                Icon(LucideIcons.hash, size: 22, color: p.accent),
                const Spacer(),
                Text('$len/$max', style: ts(over ? p.danger : p.sub, 13, FontWeight.w700)),
              ]),
            ]),
          ),
        ),
      ]),
    );
  }
}
