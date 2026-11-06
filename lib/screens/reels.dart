
import 'dart:io';
import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:video_player/video_player.dart';
import '../fx.dart' show ReactButton, Shape, ShapePainter;
import '../reel_fx.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'reel_camera.dart';

class ReelsScreen extends StatefulWidget {
  const ReelsScreen({super.key});
  @override
  State<ReelsScreen> createState() => _ReelsState();
}

class _ReelsState extends State<ReelsScreen> {
  PageController _page = PageController();
  int _idx = 0;
  bool _friends = false, _opening = false;
  int _sort = 0; // 0 for you, 1 latest, 2 most liked

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  List<Reel> _feed(AppState s) {
    final l = s.reels
        .where((r) => !_friends || r.userId == 'me' || s.following.contains(r.userId))
        .toList();
    if (_sort == 1) l.sort((a, b) => a.minutes.compareTo(b.minutes));
    if (_sort == 2) l.sort((a, b) => b.likeCount.compareTo(a.likeCount));
    return l;
  }

  void _restart({bool? friends, int? sort}) {
    setState(() {
      _friends = friends ?? _friends;
      _sort = sort ?? _sort;
      _page.dispose();
      _page = PageController();
      _idx = 0;
    });
  }

  Future<void> _camera() async {
    if (_opening) return;
    _opening = true;
    final done = await Navigator.of(context)
        .push<bool>(slide<bool>(const ReelCameraScreen(), name: 'reel_camera'));
    _opening = false;
    if (done == true && mounted) _restart(friends: false, sort: 0);
  }

  void _sortSheet() {
    final p = context.p;
    const names = ['For you', 'Latest', 'Most liked'];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: p.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: p.line, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 14),
            Text('Show reels', style: ts(p.text, 17, FontWeight.w800)),
            const SizedBox(height: 6),
            for (int i = 0; i < names.length; i++)
              Tap(
                onTap: () {
                  Navigator.pop(sheet);
                  _restart(sort: i);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                  child: Row(children: [
                    Expanded(child: Text(names[i], style: ts(p.text, 16, FontWeight.w600))),
                    if (_sort == i) Icon(LucideIcons.check, size: 20, color: p.accent),
                  ]),
                ),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _topBar() {
    Widget tab(String t, bool on, VoidCallback f) => Tap(
          onTap: f,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Text(t, style: ts(on ? Colors.white : const Color(0x99FFFFFF), 18, FontWeight.w800)),
          ),
        );
    return Positioned(
      top: 0, left: 0, right: 0,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x88000000), Color(0x00000000)]),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(children: [
              IconBtn(LucideIcons.plus, _camera, color: Colors.white),
              const Spacer(),
              tab('Reels', !_friends, () => _friends ? _restart(friends: false) : null),
              tab('Friends', _friends, () => !_friends ? _restart(friends: true) : null),
              const Spacer(),
              IconBtn(LucideIcons.slidersHorizontal, _sortSheet, color: Colors.white),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final visible = s.tab == reelsTab && (ModalRoute.of(context)?.isCurrent ?? true);
    final feed = _feed(s);
    if (_idx >= feed.length) _idx = feed.isEmpty ? 0 : feed.length - 1;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(children: [
          Positioned.fill(
            child: feed.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(LucideIcons.clapperboard, size: 44, color: Colors.white54),
                        const SizedBox(height: 14),
                        Text(_friends ? 'No reels from friends yet' : 'No reels yet',
                            style: ts(Colors.white, 18, FontWeight.w800)),
                        const SizedBox(height: 6),
                        Text(_friends ? 'Follow people to see their reels here.' : 'Tap + to record your first reel.',
                            textAlign: TextAlign.center, style: ts(Colors.white60, 14)),
                        const SizedBox(height: 18),
                        GradBtn('Create reel', _camera),
                      ]),
                    ),
                  )
                : PageView.builder(
                    key: ValueKey('$_friends$_sort'),
                    controller: _page,
                    scrollDirection: Axis.vertical,
                    itemCount: feed.length,
                    onPageChanged: (i) => setState(() => _idx = i),
                    itemBuilder: (c, i) => ReelPage(
                      key: ValueKey(feed[i].id),
                      reel: feed[i],
                      active: visible && i == _idx,
                      near: visible && (i - _idx).abs() <= 1,
                    ),
                  ),
          ),
          _topBar(),
        ]),
      ),
    );
  }
}

class ReelPage extends StatefulWidget {
  final Reel reel;
  final bool active, near;
  /// extra space kept free at the bottom (system bar / custom buttons) when shown fullscreen
  final double bottomInset;
  /// drafts have no likes / comments: the side action buttons are hidden
  final bool draft;
  const ReelPage({
    super.key, required this.reel, required this.active, required this.near,
    this.bottomInset = 0, this.draft = false,
  });
  @override
  State<ReelPage> createState() => _ReelPageState();
}

class _ReelPageState extends State<ReelPage> with TickerProviderStateMixin {
  VideoPlayerController? _v;
  AudioPlayer? _a;
  bool _paused = false, _expanded = false, _audioStarted = false;
  Duration _lastPos = Duration.zero;
  Offset _burstAt = Offset.zero;
  late final AnimationController _art =
      AnimationController(vsync: this, duration: const Duration(seconds: 9));
  late final AnimationController _burst =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 750));

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(ReelPage old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _v?.removeListener(_tick);
    _v?.dispose();
    _a?.dispose();
    _art.dispose();
    _burst.dispose();
    super.dispose();
  }

  void _sync() {
    final r = widget.reel;
    if (r.video != null) {
      if (widget.near && _v == null) _initVideo();
      if (!widget.near && _v != null) _disposeVideo();
    }
    final play = widget.active && !_paused;
    final v = _v;
    if (v != null && v.value.isInitialized) {
      if (play) {
        v.play();
      } else {
        v.pause();
        if (!widget.active) v.seekTo(Duration.zero);
      }
    }
    _audio(play);
    if (play) {
      if (!_art.isAnimating) _art.repeat();
    } else {
      _art.stop();
    }
  }

  void _initVideo() {
    final r = widget.reel;
    final c = VideoPlayerController.file(File(r.video!));
    _v = c;
    c.setLooping(true);
    c.initialize().then((_) async {
      if (!mounted || _v != c) return;
      await c.setPlaybackSpeed(r.speed);
      if (r.audio != null) await c.setVolume(0);
      c.addListener(_tick);
      setState(() {});
      _sync();
    }).catchError((Object _) {});
  }

  void _disposeVideo() {
    final c = _v;
    _v = null;
    c?.removeListener(_tick);
    c?.dispose();
    _stopAudio();
  }

  void _tick() {
    final v = _v;
    if (v == null) return;
    final pos = v.value.position;
    // video looped -> restart the sound track with it
    if (pos + const Duration(milliseconds: 600) < _lastPos) _a?.seek(Duration.zero);
    _lastPos = pos;
  }

  Future<void> _audio(bool play) async {
    final path = widget.reel.audio;
    if (path == null) return;
    try {
      if (play && widget.active) {
        final a = _a ??= AudioPlayer();
        if (!_audioStarted) {
          _audioStarted = true;
          await a.setReleaseMode(ReleaseMode.loop);
          await a.setPlaybackRate(widget.reel.speed);
          await a.play(DeviceFileSource(path));
        } else {
          await a.resume();
        }
      } else if (!widget.active) {
        await _stopAudio();
      } else {
        await _a?.pause();
      }
    } catch (_) {}
  }

  Future<void> _stopAudio() async {
    _audioStarted = false;
    try {
      await _a?.stop();
    } catch (_) {}
  }

  void _toggle() {
    setState(() => _paused = !_paused);
    _sync();
  }

  void _doubleLike() {
    final s = context.s;
    if (!widget.reel.liked) s.toggleReelLike(widget.reel);
    _burst.forward(from: 0);
  }

  // ---------------------------------------------------------------- media layers
  Widget _media(Reel r) {
    if (r.video == null) return _art_(r);
    final v = _v;
    if (v == null || !v.value.isInitialized) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white));
    }
    final size = v.value.size;
    final portrait = size.height >= size.width * 1.2;
    final player = FittedBox(
      fit: portrait ? BoxFit.cover : BoxFit.contain,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(width: size.width, height: size.height, child: VideoPlayer(v)),
    );
    return SizedBox.expand(child: reelFx(player, r.fx, r.touch));
  }

  /// Demo reels have no video file: they are drawn as animated gradient art.
  Widget _art_(Reel r) => AnimatedBuilder(
        animation: _art,
        builder: (context, _) {
          final t = _art.value * 2 * math.pi;
          final h1 = (r.hue + 40 * math.sin(t)).round();
          final h2 = (r.hue + 90 + 40 * math.cos(t)).round();
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(math.cos(t), -1),
                end: Alignment(-math.cos(t), 1),
                colors: [hsl(h1, .75, .42), hsl(h2, .8, .28)],
              ),
            ),
            child: Center(
              child: Transform.scale(
                scale: 1 + .08 * math.sin(t * 2),
                child: Icon(mediaIcons[r.icon % mediaIcons.length], size: 120, color: Colors.white.withAlpha(150)),
              ),
            ),
          );
        },
      );

  // ---------------------------------------------------------------- actions
  void _comments() {
    final p = context.p;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: p.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _CommentsSheet(widget.reel),
    );
  }

  void _more() {
    final p = context.p;
    final s = context.s;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: p.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: p.line, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 8),
            Tap(
              onTap: () {
                Navigator.pop(sheet);
                s.deleteReel(widget.reel);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                child: Row(children: [
                  Icon(LucideIcons.trash2, size: 22, color: p.danger),
                  const SizedBox(width: 16),
                  Text('Delete reel', style: ts(p.danger, 16, FontWeight.w600)),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _actions(Reel r, AppState s) => Positioned(
        right: 8, bottom: 14 + widget.bottomInset,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ReactButton(
            shape: Shape.heart, icon: LucideIcons.heart, active: r.liked, size: 30, vertical: true,
            color: const Color(0xFFFF3B5C), idle: Colors.white, count: r.likeCount,
            onTap: () => s.toggleReelLike(r),
          ),
          _ActBtn(label: compact(r.comments), onTap: _comments,
              child: const Icon(LucideIcons.messageCircle, size: 30, color: Colors.white)),
          _ActBtn(
            pop: !r.reposted,
            label: compact(r.repostCount),
            onTap: () {
              s.toggleReelRepost(r);
              toast(context, r.reposted ? 'Reposted to your profile' : 'Repost removed');
            },
            child: Icon(LucideIcons.repeat2, size: 30, color: r.reposted ? const Color(0xFF4ADE80) : Colors.white),
          ),
          _ActBtn(
            label: compact(r.shares),
            onTap: () {
              Clipboard.setData(ClipboardData(text: 'https://intly.app/reel/${r.id}'));
              s.shareReel(r);
              toast(context, 'Link copied');
            },
            child: const Icon(LucideIcons.send, size: 28, color: Colors.white),
          ),
          ReactButton(
            shape: Shape.bookmark, icon: LucideIcons.bookmark, active: r.saved, size: 30, vertical: true,
            color: kSaveColor, idle: Colors.white, count: r.saveCount,
            onTap: () => s.toggleReelSave(r),
          ),
          if (r.userId == 'me')
            _ActBtn(onTap: _more, child: const Icon(LucideIcons.moreVertical, size: 26, color: Colors.white)),
          const SizedBox(height: 8),
          AnimatedBuilder(
            animation: _art,
            builder: (context, child) => Transform.rotate(angle: _art.value * 2 * math.pi, child: child),
            child: Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: FittedBox(fit: BoxFit.cover, child: Avatar(s.user(r.userId), 34)),
              ),
            ),
          ),
        ]),
      );

  Widget _info(Reel r, AppState s) {
    final u = s.user(r.userId);
    final following = s.following.contains(u.id);
    return Positioned(
      left: 14, right: widget.draft ? 14 : 84, bottom: 14 + widget.bottomInset,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Tap(onTap: () => openProfile(context, u.id), child: Avatar(u, 38)),
          const SizedBox(width: 10),
          Flexible(
            child: Tap(
              onTap: () => openProfile(context, u.id),
              child: Text(u.id == 'me' ? 'You' : u.name,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(Colors.white, 15, FontWeight.w800)),
            ),
          ),
          if (u.id != 'me') ...[
            const SizedBox(width: 12),
            Tap(
              onTap: () => s.toggleFollow(u.id),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: following ? const Color(0x33FFFFFF) : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: Colors.white, width: 1.2),
                ),
                child: Text(following ? 'Following' : 'Follow', style: ts(Colors.white, 13, FontWeight.w700)),
              ),
            ),
          ],
        ]),
        if (r.caption.isNotEmpty) ...[
          const SizedBox(height: 10),
          Tap(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Text(r.caption,
                maxLines: _expanded ? 6 : 2,
                overflow: TextOverflow.ellipsis,
                style: ts(Colors.white, 14, FontWeight.w500, 1.35)),
          ),
        ],
        const SizedBox(height: 8),
        Row(children: [
          const Icon(LucideIcons.music, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Flexible(
            child: Text(r.audioName,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(Colors.white, 13, FontWeight.w600)),
          ),
        ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final r = widget.reel;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggle,
      onDoubleTapDown: (d) => _burstAt = d.localPosition,
      onDoubleTap: _doubleLike,
      child: Stack(fit: StackFit.expand, children: [
        _media(r),
        const Positioned(
          left: 0, right: 0, bottom: 0, height: 260,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0xAA000000)]),
              ),
            ),
          ),
        ),
        if (_paused)
          const IgnorePointer(
            child: Center(
              child: CircleAvatar(
                radius: 36,
                backgroundColor: Color(0x66000000),
                child: Icon(LucideIcons.play, size: 34, color: Colors.white),
              ),
            ),
          ),
        AnimatedBuilder(
          animation: _burst,
          builder: (context, _) {
            if (!_burst.isAnimating) return const SizedBox.shrink();
            final t = _burst.value;
            final scale = t < .35 ? .5 + (t / .35) * .9 : 1.4 - (t - .35) * .3;
            return Positioned(
              left: _burstAt.dx - 50, top: _burstAt.dy - 50,
              child: IgnorePointer(
                child: Opacity(
                  opacity: t < .6 ? 1 : (1 - (t - .6) / .4).clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: scale,
                    child: CustomPaint(size: const Size(100, 100), painter: ShapePainter(Shape.heart, const Color(0xFFFF3B5C))),
                  ),
                ),
              ),
            );
          },
        ),
        _info(r, s),
        if (!widget.draft) _actions(r, s),
        if (_v != null && _v!.value.isInitialized)
          Positioned(
            left: 0, right: 0, bottom: widget.bottomInset, height: 3,
            child: VideoProgressIndicator(
              _v!,
              allowScrubbing: false,
              padding: EdgeInsets.zero,
              colors: const VideoProgressColors(
                playedColor: Colors.white,
                bufferedColor: Colors.white24,
                backgroundColor: Colors.white12,
              ),
            ),
          ),
      ]),
    );
  }
}

/// Vertical action button: icon with a little pop, count underneath.
class _ActBtn extends StatefulWidget {
  final Widget child;
  final String? label;
  final bool pop;
  final VoidCallback onTap;
  const _ActBtn({required this.child, required this.onTap, this.label, this.pop = false});
  @override
  State<_ActBtn> createState() => _ActBtnState();
}

class _ActBtnState extends State<_ActBtn> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 320));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (widget.pop) _c.forward(from: 0);
          widget.onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AnimatedBuilder(
              animation: _c,
              builder: (context, child) =>
                  Transform.scale(scale: 1 + .4 * math.sin(math.pi * _c.value), child: child),
              child: SizedBox(width: 32, height: 32, child: Center(child: widget.child)),
            ),
            if (widget.label != null) ...[
              const SizedBox(height: 3),
              Text(widget.label!, style: ts(Colors.white, 12, FontWeight.w700)),
            ],
          ]),
        ),
      );
}

class _CommentsSheet extends StatefulWidget {
  final Reel reel;
  const _CommentsSheet(this.reel);
  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _c = TextEditingController();
  final _f = FocusNode();
  ReelComment? _replyTo;

  @override
  void dispose() {
    _c.dispose();
    _f.dispose();
    super.dispose();
  }

  void _reply(ReelComment c) {
    setState(() => _replyTo = c);
    _f.requestFocus();
  }

  void _send() {
    final text = _c.text.trim();
    if (text.isEmpty) return;
    final s = context.s;
    final r = _replyTo;
    if (r == null) {
      s.addReelComment(widget.reel, text);
    } else if (r.parent == null) {
      s.addReelComment(widget.reel, text, parent: r.id);
    } else {
      s.addReelComment(widget.reel, text, parent: r.parent, replyToUser: r.userId);
    }
    _c.clear();
    setState(() => _replyTo = null);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final s = context.s;
    final all = s.reelComments[widget.reel.id] ?? const <ReelComment>[];
    final items = <Widget>[];
    for (final t in all.where((c) => c.parent == null)) {
      items.add(_ReelCommentTile(t, widget.reel, 0, () => _reply(t)));
      // replies sit under their comment, oldest first
      for (final r in all.where((c) => c.parent == t.id).toList().reversed) {
        items.add(_ReelCommentTile(r, widget.reel, 1, () => _reply(r)));
      }
    }
    final can = _c.text.trim().isNotEmpty;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * .66,
        child: Column(children: [
          const SizedBox(height: 10),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: p.line, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          Text('Comments', style: ts(p.text, 17, FontWeight.w800)),
          const SizedBox(height: 8),
          Divider(height: 1, color: p.line),
          Expanded(
            child: items.isEmpty
                ? const Empty(LucideIcons.messageCircle, 'No comments yet. Be the first!')
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: items.length,
                    itemBuilder: (c, i) => items[i],
                  ),
          ),
          Divider(height: 1, color: p.line),
          SafeArea(
            top: false,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (_replyTo != null)
                Container(
                  color: p.card,
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                  child: Row(children: [
                    Icon(LucideIcons.reply, size: 16, color: p.accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Replying to ${s.user(_replyTo!.userId).name}',
                          style: ts(p.sub, 13, FontWeight.w600)),
                    ),
                    Tap(
                      onTap: () => setState(() => _replyTo = null),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(LucideIcons.x, size: 18, color: p.sub),
                      ),
                    ),
                  ]),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                child: Row(children: [
                  Expanded(
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(22)),
                      alignment: Alignment.centerLeft,
                      child: TextField(
                        controller: _c,
                        focusNode: _f,
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) => _send(),
                        style: ts(p.text, 15),
                        cursorColor: p.accent,
                        textInputAction: TextInputAction.send,
                        decoration: InputDecoration.collapsed(
                            hintText: _replyTo == null ? 'Add a comment…' : 'Write a reply…',
                            hintStyle: ts(p.sub, 15)),
                      ),
                    ),
                  ),
                  IconBtn(LucideIcons.send, _send, color: can ? p.accent : p.sub),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// One comment or reply in the reels comment sheet: reply, Author badge, animated heart.
class _ReelCommentTile extends StatelessWidget {
  final ReelComment c;
  final Reel reel;
  final int depth;
  final VoidCallback onReply;
  const _ReelCommentTile(this.c, this.reel, this.depth, this.onReply);

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final s = context.s;
    final u = s.user(c.userId);
    final isAuthor = c.userId == reel.userId;
    final mention = c.replyToUser == null ? null : s.user(c.replyToUser!);
    return Padding(
      padding: EdgeInsets.fromLTRB(16 + depth * 44.0, 10, 8, 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Tap(onTap: () => openProfile(context, u.id), child: Avatar(u, depth == 0 ? 36 : 28)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(u.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: ts(p.text, 14, FontWeight.w700)),
              ),
              if (isAuthor) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                      color: p.accent.withAlpha(36), borderRadius: BorderRadius.circular(8)),
                  child: Text('Author', style: ts(p.accent, 10, FontWeight.w800)),
                ),
              ],
              const SizedBox(width: 6),
              Text(timeAgo(c.minutes), style: ts(p.sub, 12)),
            ]),
            const SizedBox(height: 2),
            Text.rich(TextSpan(children: [
              if (mention != null)
                TextSpan(text: '@${mention.handle} ',
                    style: TextStyle(color: p.accent, fontWeight: FontWeight.w700)),
              TextSpan(text: c.text),
            ]), style: ts(p.text, 15, FontWeight.w400, 1.35)),
            Tap(
              onTap: onReply,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text('Reply', style: ts(p.sub, 13, FontWeight.w700)),
              ),
            ),
          ]),
        ),
        ReactButton(
          shape: Shape.heart,
          icon: LucideIcons.heart,
          active: s.likedComments.contains(c.id),
          color: p.danger,
          idle: p.sub,
          count: s.reelCommentLikes(c) > 0 ? s.reelCommentLikes(c) : null,
          onTap: () => s.toggleCommentLikeId(c.id),
        ),
      ]),
    );
  }
}
