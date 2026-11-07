

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'fx.dart';
import 'native.dart';
import 'screens/compose.dart';
import 'screens/detail.dart';
import 'screens/hashtag.dart';
import 'styles.dart';
import 'screens/profile.dart';
import 'screens/viewer.dart';
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

Route<T> slide<T>(Widget page, {String? name}) => PageRouteBuilder<T>(
      settings: RouteSettings(name: name),
      opaque: true,
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 260),
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

/// Name of the screen currently on top of the navigator.
String? _topRoute(BuildContext c) {
  String? name;
  Navigator.of(c).popUntil((r) {
    name = r.settings.name;
    return true; // never pops anything, only reads the top route
  });
  return name;
}

/// Opens a screen unless that exact screen is already on top, so tapping the same
/// hashtag / profile / post again (or many times fast) never stacks copies of it.
void pushOnce(BuildContext c, String name, Widget page) {
  if (_topRoute(c) == name) return;
  Navigator.of(c).push(slide(page, name: name));
}

void openPost(BuildContext c, Post post, {String? highlightId}) =>
    pushOnce(c, 'post:${post.id}', PostDetail(post, highlightId: highlightId));

void openProfile(BuildContext c, String id) {
  if (id == 'me') {
    c.s.setTab(4);
    Navigator.of(c).popUntil((r) => r.isFirst);
  } else {
    pushOnce(c, 'profile:$id', ProfileScreen(userId: id));
  }
}

/// Full-size gradient art used for demo posts that have no real media file.
Widget mediaPlaceholder(int media, {double iconSize = 60}) => Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [hsl(media * 37 + 10), hsl(media * 37 + 80, .8, .38)],
        ),
      ),
      child: Icon(mediaIcons[media % mediaIcons.length],
          size: iconSize, color: Colors.white.withAlpha(190)),
    );

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
  Widget build(BuildContext context) {
    final fallback = Container(
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
    final photo = user.avatar; // already a local file; no disk check during build
    if (photo == null) return fallback;
    return ClipOval(
      child: Image.file(
        File(photo),
        width: size,
        height: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        cacheWidth: (size * 3).round(),
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }
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
    final status = s.followStatus(userId); // 'following' | 'requested' | 'none'
    final on = status != 'none';
    final label = switch (status) {
      'following' => 'Following',
      'requested' => 'Requested',
      _ => 'Follow',
    };
    return InstantTap(
      onTap: () => s.toggleFollow(userId),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(horizontal: small ? 16 : 22, vertical: small ? 7 : 9),
        decoration: BoxDecoration(
          gradient: on ? null : p.grad,
          color: on ? p.card : null,
          borderRadius: BorderRadius.circular(20),
          border: on ? Border.all(color: p.line, width: 1.5) : null,
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          transitionBuilder: (c, a) => FadeTransition(
            opacity: a,
            child: ScaleTransition(scale: Tween(begin: .92, end: 1.0).animate(a), child: c),
          ),
          child: Text(label,
              key: ValueKey(label),
              style: ts(on ? p.text : Colors.white, small ? 13 : 14, FontWeight.w700)),
        ),
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

const mediaIcons = [
  LucideIcons.sparkles, LucideIcons.sun, LucideIcons.music,
  LucideIcons.camera, LucideIcons.coffee, LucideIcons.mountain,
];

void openTag(BuildContext c, String tag) =>
    pushOnce(c, 'tag:${tag.toLowerCase()}', HashtagScreen(tag: tag.toLowerCase()));

const kSaveColor = Color(0xFFFF9F1C);

class PostCard extends StatelessWidget {
  final Post post;
  final bool detail;
  const PostCard(this.post, {super.key, this.detail = false});

  bool get _canvas =>
      post.bg >= 0 || post.image != null || post.video != null || post.stickers.isNotEmpty;

  bool get _hasMedia => post.image != null || post.video != null;

  void _openMedia(BuildContext c) => pushOnce(
      c,
      'viewer:${post.id}',
      MediaViewer(
        image: post.image,
        video: post.video,
        placeholder: !_hasMedia && post.media >= 0 ? post.media : null,
      ));

  Widget _text(BuildContext c, Pal p) {
    final color = post.tcolor >= 0 ? textColors[post.tcolor] : p.text;
    final style = postStyle(post.font, color, detail ? 18 : 15);
    final spans = <InlineSpan>[];
    int last = 0;
    for (final m in RegExp(r'#[A-Za-z0-9_]+').allMatches(post.text)) {
      if (m.start > last) spans.add(TextSpan(text: post.text.substring(last, m.start)));
      final tag = m.group(0)!;
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: Tap(
          onTap: () => openTag(c, tag.substring(1)),
          child: Text(tag, style: style.copyWith(color: p.accent, fontWeight: FontWeight.w700)),
        ),
      ));
      last = m.end;
    }
    if (last < post.text.length) spans.add(TextSpan(text: post.text.substring(last)));
    return Text.rich(TextSpan(children: spans, style: style));
  }

  Widget _chips(BuildContext c, Pal p) {
    final tags = Native.tags(post.text).toSet().toList();
    if (tags.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(spacing: 8, runSpacing: 4, children: [
        for (final t in tags)
          Tap(onTap: () => openTag(c, t), child: Text('#$t', style: ts(p.accent, 14, FontWeight.w700))),
      ]),
    );
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
            _SheetRow(LucideIcons.bookmark, post.saved ? 'Remove from saved' : 'Save post', () {
              Navigator.pop(sheet);
              s.toggleSave(post);
            }),
            if (u.id == 'me') ...[
              _SheetRow(LucideIcons.pencil, 'Edit post', () {
                Navigator.pop(sheet);
                Navigator.of(c).push(slide(ComposeScreen(edit: post)));
              }),
              _SheetRow(LucideIcons.trash2, 'Delete post', () {
                Navigator.pop(sheet);
                s.deletePost(post);
                if (detail) Navigator.of(c).maybePop();
              }, danger: true),
            ] else ...[
              _SheetRow(s.following.contains(u.id) ? LucideIcons.userX : LucideIcons.userPlus,
                  s.following.contains(u.id) ? 'Unfollow @${u.handle}' : 'Follow @${u.handle}', () {
                Navigator.pop(sheet);
                s.toggleFollow(u.id);
              }),
              _SheetRow(LucideIcons.flag, s.reported.contains(post.id) ? 'Post reported' : 'Report post', () {
                Navigator.pop(sheet);
                if (s.reported.contains(post.id)) {
                  toast(c, 'You already reported this post');
                } else {
                  _report(c);
                }
              }, danger: true),
            ],
          ]),
        ),
      ),
    );
  }

  void _report(BuildContext c) {
    final p = c.p;
    final s = c.s;
    const reasons = <(IconData, String)>[
      (LucideIcons.inbox, 'Spam'),
      (LucideIcons.shieldAlert, 'Harassment or hate'),
      (LucideIcons.eyeOff, 'Nudity or sexual content'),
      (LucideIcons.info, 'False information'),
      (LucideIcons.moreHorizontal, 'Something else'),
    ];
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
            const SizedBox(height: 14),
            Text('Report post', style: ts(p.text, 17, FontWeight.w800)),
            const SizedBox(height: 4),
            Text('Why are you reporting this?', style: ts(p.sub, 13)),
            const SizedBox(height: 6),
            for (final r in reasons)
              _SheetRow(r.$1, r.$2, () {
                Navigator.pop(sheet);
                s.reportPost(post);
                toast(c, 'Thanks, we will review this post');
              }),
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
    final onBg = post.bg >= 0;
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
              if (u.id != 'me') ...[FollowBtn(u.id, small: true), const SizedBox(width: 8)],
              Tap(onTap: () => _more(context),
                  child: Icon(LucideIcons.moreHorizontal, size: 18, color: p.sub)),
            ]),
            const SizedBox(height: 4),
            if (!onBg && post.text.isNotEmpty) _text(context, p),
            if (_canvas)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: PostCanvas(
                  bg: post.bg,
                  image: post.image,
                  video: post.video != null,
                  onTap: detail && _hasMedia ? () => _openMedia(context) : null,
                  stickers: post.stickers,
                  height: onBg ? 240 : (_hasMedia ? 250 : 170),
                  center: onBg
                      ? Text(post.text, textAlign: TextAlign.center,
                          style: postStyle(post.font,
                              post.tcolor >= 0 ? textColors[post.tcolor] : Colors.white, 24))
                      : null,
                ),
              )
            else if (post.media >= 0)
              GestureDetector(
                onTap: detail ? () => _openMedia(context) : null,
                child: Container(
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
                child: Icon(mediaIcons[post.media % mediaIcons.length],
                    size: 60, color: Colors.white.withAlpha(190)),
              ),
              ),
            if (onBg) _chips(context, p),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _Act(LucideIcons.messageCircle, post.commentCount,
                  detail ? null : () => openPost(context, post)),
              ReactButton(
                shape: Shape.heart, icon: LucideIcons.heart, active: post.liked,
                color: p.danger, idle: p.sub, count: post.likeCount, onTap: () => s.toggleLike(post),
              ),
              _Act(LucideIcons.share2, post.shares, () {
                Clipboard.setData(ClipboardData(text: 'intly://post/${post.id}'));
                toast(context, 'Link copied');
              }),
              ReactButton(
                shape: Shape.bookmark, icon: LucideIcons.bookmark, active: post.saved,
                color: kSaveColor, idle: p.sub, onTap: () {
                  s.toggleSave(post);
                },
              ),
            ]),
          ]),
        ),
      ]),
    );
    if (!detail) {
      card = Tap(onTap: () => openPost(context, post), child: card);
    }
    return RepaintBoundary(child: card);
  }
}

class _Act extends StatelessWidget {
  final IconData icon;
  final int count;
  final VoidCallback? onTap;
  const _Act(this.icon, this.count, this.onTap);
  @override
  Widget build(BuildContext context) {
    final c = context.p.sub;
    return Tap(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(children: [
          Icon(icon, size: 20, color: c),
          const SizedBox(width: 6),
          Text(compact(count), style: ts(c, 13, FontWeight.w600)),
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

/// A tap that answers the moment the finger lifts. Unlike [Tap] it does not wait
/// for the gesture arena, so a screen that listens for double taps cannot delay
/// it. Moving the finger more than a few pixels cancels it, so scrolling past a
/// button never presses it. It also absorbs the tap, so a card or row around it
/// (a post, a profile row) does not open at the same time.
class InstantTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const InstantTap({super.key, required this.child, this.onTap});
  @override
  State<InstantTap> createState() => _InstantTapState();
}

class _InstantTapState extends State<InstantTap> {
  Offset? _start;
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {}, // wins the tap against any parent, so the parent stays quiet
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (e) {
            _start = e.localPosition;
            _set(true);
          },
          onPointerMove: (e) {
            final s = _start;
            if (s != null && (e.localPosition - s).distance > 12) {
              _start = null;
              _set(false);
            }
          },
          onPointerCancel: (_) {
            _start = null;
            _set(false);
          },
          onPointerUp: (_) {
            final s = _start;
            _start = null;
            _set(false);
            if (s != null) widget.onTap?.call();
          },
          child: AnimatedScale(
            scale: _down ? 0.93 : 1,
            duration: const Duration(milliseconds: 90),
            child: widget.child,
          ),
        ),
      );
}
