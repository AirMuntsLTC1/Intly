import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'screens/detail.dart';
import 'screens/profile.dart';
import 'state.dart';
import 'theme.dart';

Color hsl(int hue, [double s = .72, double l = .52]) =>
    HSLColor.fromAHSL(1, (hue % 360).toDouble(), s, l).toColor();

String timeAgo(int m) {
  if (m < 1) return 'now';
  if (m < 60) return '${m}m';
  if (m < 1440) return '${m ~/ 60}h';
  return '${m ~/ 1440}d';
}

String compact(int n) => n >= 1000 ? '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1)}k' : '$n';

Route<T> slide<T>(Widget page) => PageRouteBuilder<T>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, a, __, child) {
        final t = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: t,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0.06, 0), end: Offset.zero).animate(t),
            child: child,
          ),
        );
      },
    );

void openProfile(BuildContext c, String id) {
  if (id == 'me') {
    c.s.setTab(4);
    Navigator.of(c).popUntil((r) => r.isFirst);
  } else {
    Navigator.of(c).push(slide(ProfileScreen(userId: id)));
  }
}

void toast(BuildContext c, String msg) {
  final p = c.p;
  ScaffoldMessenger.of(c)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(msg, style: ts(p.text, 14, FontWeight.w600)),
      backgroundColor: p.card,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(milliseconds: 1400),
      elevation: 0,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 76),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14), side: BorderSide(color: p.line)),
    ));
}

/// Press-scale tap target (no system ripple).
class Tap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const Tap({super.key, required this.child, this.onTap});
  @override
  State<Tap> createState() => _TapState();
}

class _TapState extends State<Tap> {
  bool _down = false;
  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? 0.93 : 1,
          duration: const Duration(milliseconds: 90),
          child: widget.child,
        ),
      );
}

class IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  const IconBtn(this.icon, this.onTap, {super.key, this.color});
  @override
  Widget build(BuildContext context) => Tap(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 22, color: color ?? context.p.text),
        ),
      );
}

class TopBar extends StatelessWidget {
  final String title;
  final bool back;
  final List<Widget> actions;
  const TopBar(this.title, {super.key, this.back = false, this.actions = const []});
  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Container(
      decoration: BoxDecoration(color: p.bg, border: Border(bottom: BorderSide(color: p.line))),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Row(children: [
            const SizedBox(width: 6),
            if (back) IconBtn(LucideIcons.arrowLeft, () => Navigator.of(context).maybePop()),
            if (!back) const SizedBox(width: 10),
            Expanded(child: Text(title, style: ts(p.text, 20, FontWeight.w800))),
            ...actions,
            const SizedBox(width: 6),
          ]),
        ),
      ),
    );
  }
}

class Avatar extends StatelessWidget {
  final User user;
  final double size;
  const Avatar(this.user, this.size, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [hsl(user.hue), hsl(user.hue + 50, .75, .45)],
          ),
        ),
        child: Text(
          user.name.isEmpty ? '?' : user.name[0].toUpperCase(),
          style: ts(Colors.white, size * .42, FontWeight.w800),
        ),
      );
}

class GradBtn extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const GradBtn(this.label, this.onTap, {super.key});
  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Tap(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? .4 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
          decoration: BoxDecoration(gradient: p.grad, borderRadius: BorderRadius.circular(20)),
          child: Text(label, style: ts(Colors.white, 14, FontWeight.w700)),
        ),
      ),
    );
  }
}

class FollowBtn extends StatelessWidget {
  final String userId;
  final bool small;
  const FollowBtn(this.userId, {super.key, this.small = false});
  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final s = context.s;
    final on = s.following.contains(userId);
    return Tap(
      onTap: () => s.toggleFollow(userId),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: EdgeInsets.symmetric(horizontal: small ? 16 : 22, vertical: small ? 7 : 9),
        decoration: BoxDecoration(
          gradient: on ? null : p.grad,
          borderRadius: BorderRadius.circular(20),
          border: on ? Border.all(color: p.line, width: 1.5) : null,
        ),
        child: Text(on ? 'Following' : 'Follow',
            style: ts(on ? p.text : Colors.white, small ? 13 : 14, FontWeight.w700)),
      ),
    );
  }
}

class Toggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const Toggle(this.value, this.onChanged, {super.key});
  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Tap(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 48,
        height: 28,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value ? p.accent : p.line,
          borderRadius: BorderRadius.circular(14),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
              width: 22, height: 22,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
        ),
      ),
    );
  }
}

class Empty extends StatelessWidget {
  final IconData icon;
  final String text;
  const Empty(this.icon, this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 32),
      child: Column(children: [
        Icon(icon, size: 40, color: p.sub),
        const SizedBox(height: 12),
        Text(text, textAlign: TextAlign.center, style: ts(p.sub, 15, FontWeight.w500, 1.4)),
      ]),
    );
  }
}

const _mediaIcons = [
  LucideIcons.sparkles, LucideIcons.sun, LucideIcons.music,
  LucideIcons.camera, LucideIcons.coffee, LucideIcons.mountain,
];

class PostCard extends StatelessWidget {
  final Post post;
  final bool detail;
  const PostCard(this.post, {super.key, this.detail = false});

  Widget _rich(Pal p) {
    final spans = <InlineSpan>[];
    int last = 0;
    for (final m in RegExp(r'#[A-Za-z0-9_]+').allMatches(post.text)) {
      if (m.start > last) spans.add(TextSpan(text: post.text.substring(last, m.start)));
      spans.add(TextSpan(text: m.group(0), style: TextStyle(color: p.accent, fontWeight: FontWeight.w600)));
      last = m.end;
    }
    if (last < post.text.length) spans.add(TextSpan(text: post.text.substring(last)));
    return Text.rich(TextSpan(children: spans), style: ts(p.text, detail ? 17 : 15, FontWeight.w400, 1.42));
  }

  void _more(BuildContext c) {
    final p = c.p;
    final s = c.s;
    final u = s.user(post.userId);
    showModalBottomSheet<void>(
      context: c,
      backgroundColor: p.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: p.line, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 8),
            _SheetRow(post.saved ? LucideIcons.bookmark : LucideIcons.bookmark,
                post.saved ? 'Remove from saved' : 'Save post', () {
              Navigator.pop(sheet);
              s.toggleSave(post);
            }),
            if (u.id != 'me')
              _SheetRow(s.following.contains(u.id) ? LucideIcons.userX : LucideIcons.userPlus,
                  s.following.contains(u.id) ? 'Unfollow @${u.handle}' : 'Follow @${u.handle}', () {
                Navigator.pop(sheet);
                s.toggleFollow(u.id);
              }),
            _SheetRow(LucideIcons.flag, 'Report', () {
              Navigator.pop(sheet);
              toast(c, 'Thanks, we will review this post');
            }, danger: true),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final s = context.s;
    final u = s.user(post.userId);
    Widget card = Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.line))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Tap(onTap: () => openProfile(context, u.id), child: Avatar(u, 44)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(u.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: ts(p.text, 15, FontWeight.w700))),
              const SizedBox(width: 6),
              Flexible(child: Text('@${u.handle} · ${timeAgo(post.minutes)}', maxLines: 1,
                  overflow: TextOverflow.ellipsis, style: ts(p.sub, 13))),
              const Spacer(),
              Tap(onTap: () => _more(context),
                  child: Icon(LucideIcons.moreHorizontal, size: 18, color: p.sub)),
            ]),
            const SizedBox(height: 4),
            _rich(p),
            if (post.media >= 0)
              Container(
                margin: const EdgeInsets.only(top: 10),
                height: 190,
                width: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [hsl(post.media * 37 + 10), hsl(post.media * 37 + 80, .8, .38)],
                  ),
                ),
                child: Icon(_mediaIcons[post.media % _mediaIcons.length],
                    size: 60, color: Colors.white.withAlpha(190)),
              ),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _Act(LucideIcons.messageCircle, post.commentCount, false, p.accent,
                  detail ? null : () => Navigator.of(context).push(slide(PostDetail(post)))),
              _Act(LucideIcons.heart, post.likeCount, post.liked, p.danger, () => s.toggleLike(post)),
              _Act(LucideIcons.share2, post.shares, false, p.accent, () {
                Clipboard.setData(ClipboardData(text: 'intly://post/${post.id}'));
                toast(context, 'Link copied');
              }),
              _Act(LucideIcons.bookmark, null, post.saved, p.accent, () => s.toggleSave(post)),
            ]),
          ]),
        ),
      ]),
    );
    if (!detail) {
      card = Tap(onTap: () => Navigator.of(context).push(slide(PostDetail(post))), child: card);
    }
    return RepaintBoundary(child: card);
  }
}

class _Act extends StatelessWidget {
  final IconData icon;
  final int? count;
  final bool active;
  final Color activeColor;
  final VoidCallback? onTap;
  const _Act(this.icon, this.count, this.active, this.activeColor, this.onTap);
  @override
  Widget build(BuildContext context) {
    final c = active ? activeColor : context.p.sub;
    return Tap(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(children: [
          Icon(icon, size: 20, color: c),
          if (count != null) ...[
            const SizedBox(width: 6),
            Text(compact(count!), style: ts(c, 13, FontWeight.w600)),
          ],
        ]),
      ),
    );
  }
}

class _SheetRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;
  const _SheetRow(this.icon, this.label, this.onTap, {this.danger = false});
  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final c = danger ? p.danger : p.text;
    return Tap(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(children: [
          Icon(icon, size: 22, color: c),
          const SizedBox(width: 16),
          Text(label, style: ts(c, 16, FontWeight.w600)),
        ]),
      ),
    );
  }
}
