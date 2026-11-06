import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme.dart';
import '../widgets.dart';
import 'settings.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final s = context.s;
    final posts = s.posts;
    return Scaffold(
      backgroundColor: p.bg,
      body: Column(children: [
        Container(
          decoration: BoxDecoration(color: p.bg, border: Border(bottom: BorderSide(color: p.line))),
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: 56,
              child: Row(children: [
                const SizedBox(width: 16),
                ShaderMask(
                  shaderCallback: (r) => p.grad.createShader(r),
                  child: Text('Intly',
                      style: ts(Colors.white, 28, FontWeight.w900).copyWith(letterSpacing: -1)),
                ),
                const Spacer(),
                IconBtn(p == Pal.dark ? LucideIcons.sun : LucideIcons.moon,
                    () => s.setMode(p == Pal.dark ? 'light' : 'dark')),
                IconBtn(LucideIcons.search, () => s.setTab(1)),
                IconBtn(LucideIcons.settings, () => Navigator.of(context).push(slide(const SettingsScreen()))),
                const SizedBox(width: 6),
              ]),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.zero,
            cacheExtent: 900,
            itemCount: posts.length + 1,
            itemBuilder: (c, i) => i == 0
                ? const _Stories()
                : PostCard(posts[i - 1], key: ValueKey(posts[i - 1].id)),
          ),
        ),
      ]),
    );
  }
}

class _Stories extends StatelessWidget {
  const _Stories();
  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final s = context.s;
    final others = s.users.values.where((u) => u.id != 'me').toList();
    return Container(
      height: 108,
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.line))),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        itemCount: others.length + 1,
        itemBuilder: (c, i) {
          final u = i == 0 ? s.me : others[i - 1];
          return Tap(
            onTap: () => openProfile(context, u.id),
            child: Container(
              width: 72,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(children: [
                Stack(clipBehavior: Clip.none, children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: i == 0 ? null : p.grad,
                      border: i == 0 ? Border.all(color: p.line, width: 2) : null,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(color: p.bg, shape: BoxShape.circle),
                      child: Avatar(u, 54),
                    ),
                  ),
                  if (i == 0)
                    Positioned(
                      right: 0, bottom: 0,
                      child: Container(
                        width: 22, height: 22,
                        decoration: BoxDecoration(
                            gradient: p.grad, shape: BoxShape.circle,
                            border: Border.all(color: p.bg, width: 2)),
                        child: const Icon(LucideIcons.plus, size: 14, color: Colors.white),
                      ),
                    ),
                ]),
                const SizedBox(height: 6),
                Text(i == 0 ? 'Your story' : u.name.split(' ').first,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(p.sub, 12, FontWeight.w500)),
              ]),
            ),
          );
        },
      ),
    );
  }
}
