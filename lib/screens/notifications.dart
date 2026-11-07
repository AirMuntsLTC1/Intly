
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

class NotificationsScreen extends StatelessWidget {
  final bool back;
  const NotificationsScreen({super.key, this.back = false});

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final s = context.s;
    final list = s.notifs;
    return Scaffold(
      backgroundColor: p.bg,
      body: Column(children: [
        TopBar('Notifications', back: back, actions: [
          IconBtn(LucideIcons.check, s.markAllRead, color: s.unread > 0 ? p.accent : p.sub),
        ]),
        Expanded(
          child: list.isEmpty
              ? const Empty(LucideIcons.bellOff, 'Nothing yet')
              : ListView.builder(
                  padding: EdgeInsets.zero,
                  cacheExtent: 600,
                  itemCount: list.length,
                  itemBuilder: (c, i) => _Row(list[i]),
                ),
        ),
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  final Notif n;
  const _Row(this.n);

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final s = context.s;
    final u = s.user(n.userId);
    final (IconData icon, Color col) = switch (n.type) {
      'like' => (LucideIcons.heart, p.danger),
      'follow' => (LucideIcons.userPlus, p.accent),
      'comment' => (LucideIcons.messageCircle, const Color(0xFF2EC4B6)),
      _ => (LucideIcons.atSign, const Color(0xFFFFB020)),
    };
    return RepaintBoundary(
      child: Tap(
        onTap: () {
          s.markRead(n);
          final post = n.type == 'follow' ? null : s.postById(n.postId);
          if (post != null) {
            openPost(context, post, highlightId: n.commentId);
          } else if (n.type == 'follow') {
            openProfile(context, u.id);
          } else {
            toast(context, 'This post is no longer available');
          }
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          color: n.read ? null : p.accent.withAlpha(22),
          child: Row(children: [
            Stack(clipBehavior: Clip.none, children: [
              Tap(
                onTap: () {
                  s.markRead(n);
                  openProfile(context, u.id);
                },
                child: Avatar(u, 46),
              ),
              Positioned(
                right: -4, bottom: -4,
                child: Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                      color: col, shape: BoxShape.circle, border: Border.all(color: p.bg, width: 2)),
                  child: Icon(icon, size: 12, color: Colors.white),
                ),
              ),
            ]),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text.rich(TextSpan(children: [
                  TextSpan(text: u.name, style: ts(p.text, 15, FontWeight.w700)),
                  TextSpan(text: ' ${s.notifText(n)}', style: ts(p.text, 15)),
                ])),
                const SizedBox(height: 2),
                Text(timeAgo(n.minutes), style: ts(p.sub, 12)),
              ]),
            ),
            if (!n.read)
              Container(width: 9, height: 9,
                  decoration: BoxDecoration(color: p.accent, shape: BoxShape.circle)),
          ]),
        ),
      ),
    );
  }
}
