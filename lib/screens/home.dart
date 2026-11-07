
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme.dart';
import '../widgets.dart';
import 'compose.dart';
import 'notifications.dart';
import 'settings.dart';
import 'suggestions.dart';

/// A suggestions strip appears after every this many posts.
const _suggestEvery = 6;

/// Feed rows: the stories bar, then the posts, with a suggestions strip after
/// every [_suggestEvery] posts. Values: -1 = stories, -2 = suggestions, n >= 0 = post n.
List<int> _feedRows(int postCount) {
  final rows = <int>[-1];
  for (var i = 0; i < postCount; i++) {
    rows.add(i);
    if ((i + 1) % _suggestEvery == 0 && i + 1 < postCount) rows.add(-2);
  }
  return rows;
}

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
                IconBtn(LucideIcons.plus, () async {
                  final ok = await Navigator.of(context).push<bool>(slide<bool>(const ComposeScreen()));
                  if (ok == true) s.setTab(0);
                }, color: p.accent),
                _BellBtn(s.unread,
                    () => Navigator.of(context).push(slide(const NotificationsScreen(back: true)))),
                IconBtn(p == Pal.dark ? LucideIcons.sun : LucideIcons.moon,
                    () => s.setMode(p == Pal.dark ? 'light' : 'dark')),
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
            itemCount: _feedRows(posts.length).length,
            itemBuilder: (c, i) {
              final r = _feedRows(posts.length)[i];
              if (r == -1) return const _Stories();
              if (r == -2) {
                return Container(
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.line))),
                  child: const SuggestionsStrip(hideIfEmpty: true),
                );
              }
              return PostCard(posts[r], key: ValueKey(posts[r].id));
            },
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

class _BellBtn extends StatelessWidget {
  final int badge;
  final VoidCallback onTap;
  const _BellBtn(this.badge, this.onTap);
  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Tap(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Stack(clipBehavior: Clip.none, children: [
          Icon(LucideIcons.bell, size: 22, color: p.text),
          if (badge > 0)
            Positioned(
              right: -8, top: -6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(color: p.danger, borderRadius: BorderRadius.circular(9)),
                child: Text('$badge', style: ts(Colors.white, 10, FontWeight.w800)),
              ),
            ),
        ]),
      ),
    );
  }
}
