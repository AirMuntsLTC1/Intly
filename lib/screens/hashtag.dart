
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../native.dart';
import '../theme.dart';
import '../widgets.dart';

class HashtagScreen extends StatelessWidget {
  final String tag;
  const HashtagScreen({super.key, required this.tag});

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final s = context.s;
    final list = s.posts.where((x) => Native.tags(x.text).contains(tag)).toList();
    return Scaffold(
      backgroundColor: p.bg,
      body: Column(children: [
        TopBar('#$tag', back: true),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.zero,
            cacheExtent: 800,
            itemCount: list.isEmpty ? 1 : list.length + 1,
            itemBuilder: (c, i) {
              if (i == 0) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.line))),
                  child: Row(children: [
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(gradient: p.grad, shape: BoxShape.circle),
                      child: const Icon(LucideIcons.hash, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('#$tag', style: ts(p.text, 22, FontWeight.w800)),
                        Text('${list.length} ${list.length == 1 ? 'post' : 'posts'}',
                            style: ts(p.sub, 14)),
                      ]),
                    ),
                  ]),
                );
              }
              return PostCard(list[i - 1], key: ValueKey('t${list[i - 1].id}'));
            },
          ),
        ),
        if (list.isEmpty) const Expanded(child: Empty(LucideIcons.hash, 'No posts with this tag yet')),
      ]),
    );
  }
}
