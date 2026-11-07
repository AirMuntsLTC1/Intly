
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:video_player/video_player.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'reels.dart';

const _overlay = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
  systemNavigationBarColor: Colors.black,
  systemNavigationBarIconBrightness: Brightness.light,
);

// ============================================================================
// Fullscreen viewer for one account's posted reels (opened from Profile > Reels).
// ============================================================================
class ReelsViewer extends StatefulWidget {
  final String userId;
  final int start;
  const ReelsViewer({super.key, required this.userId, this.start = 0});
  @override
  State<ReelsViewer> createState() => _ReelsViewerState();
}

class _ReelsViewerState extends State<ReelsViewer> {
  late final PageController _page = PageController(initialPage: widget.start);
  late int _idx = widget.start;
  bool _closing = false;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final list = s.reelsOf(widget.userId);
    if (list.isEmpty && !_closing) {
      _closing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
    }
    if (_idx >= list.length) _idx = list.isEmpty ? 0 : list.length - 1;
    final visible = ModalRoute.of(context)?.isCurrent ?? true;
    final inset = MediaQuery.of(context).padding.bottom;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _overlay,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(children: [
          Positioned.fill(
            child: list.isEmpty
                ? const SizedBox.shrink()
                : PageView.builder(
                    controller: _page,
                    scrollDirection: Axis.vertical,
                    itemCount: list.length,
                    onPageChanged: (i) => setState(() => _idx = i),
                    itemBuilder: (c, i) => ReelPage(
                      key: ValueKey(list[i].id),
                      reel: list[i],
                      active: visible && i == _idx,
                      near: visible && (i - _idx).abs() <= 1,
                      bottomInset: inset,
                    ),
                  ),
          ),
          Positioned(
            top: 0, left: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: IconBtn(LucideIcons.arrowLeft, () => Navigator.of(context).maybePop(), color: Colors.white),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ============================================================================
// Drafts: fullscreen pager of the reels you saved as drafts. Only you see them.
// ============================================================================
class DraftsScreen extends StatefulWidget {
  const DraftsScreen({super.key});
  @override
  State<DraftsScreen> createState() => _DraftsState();
}

class _DraftsState extends State<DraftsScreen> {
  final PageController _page = PageController();
  int _idx = 0;
  bool _closing = false;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  Future<void> _delete(ReelDraft d) async {
    final p = context.p;
    final s = context.s;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dc) => AlertDialog(
        backgroundColor: p.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete draft?', style: ts(p.text, 18, FontWeight.w800)),
        content: Text('This draft will be removed for good.', style: ts(p.sub, 14, FontWeight.w500, 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dc, false),
            child: Text('Cancel', style: ts(p.sub, 14, FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dc, true),
            child: Text('Delete', style: ts(p.danger, 14, FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      s.deleteDraft(d);
      toast(context, 'Draft deleted');
    }
  }

  void _post(ReelDraft d) {
    context.s.postDraft(d);
    toast(context, 'Reel shared');
  }

  Widget _bar(ReelDraft d, double inset) {
    final p = context.p;
    return Positioned(
      left: 16, right: 16, bottom: 0,
      child: Padding(
        padding: EdgeInsets.only(bottom: 14 + inset),
        child: Row(children: [
          Tap(
            onTap: () => _delete(d),
            child: Container(
              width: 50, height: 50,
              decoration: BoxDecoration(
                color: const Color(0x33FFFFFF),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white54, width: 1.4),
              ),
              child: const Icon(LucideIcons.trash2, size: 20, color: Colors.white),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Tap(
              onTap: () => _post(d),
              child: Container(
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(gradient: p.grad, borderRadius: BorderRadius.circular(25)),
                child: Text('Share reel', style: ts(Colors.white, 15, FontWeight.w800)),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final list = s.drafts;
    if (list.isEmpty && !_closing) {
      _closing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
    }
    if (_idx >= list.length) _idx = list.isEmpty ? 0 : list.length - 1;
    final visible = ModalRoute.of(context)?.isCurrent ?? true;
    final inset = MediaQuery.of(context).padding.bottom;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _overlay,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(children: [
          Positioned.fill(
            child: list.isEmpty
                ? const SizedBox.shrink()
                : PageView.builder(
                    controller: _page,
                    scrollDirection: Axis.vertical,
                    itemCount: list.length,
                    onPageChanged: (i) => setState(() => _idx = i),
                    itemBuilder: (c, i) => ReelPage(
                      key: ValueKey(list[i].id),
                      reel: list[i].toReel(),
                      active: visible && i == _idx,
                      near: visible && (i - _idx).abs() <= 1,
                      bottomInset: inset + 78,
                      draft: true,
                    ),
                  ),
          ),
          Positioned(
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
                  padding: const EdgeInsets.fromLTRB(6, 6, 16, 6),
                  child: Row(children: [
                    IconBtn(LucideIcons.arrowLeft, () => Navigator.of(context).maybePop(), color: Colors.white),
                    const SizedBox(width: 4),
                    Text('Drafts', style: ts(Colors.white, 18, FontWeight.w800)),
                    const Spacer(),
                    if (list.isNotEmpty)
                      Text('${_idx + 1} / ${list.length}', style: ts(Colors.white70, 14, FontWeight.w700)),
                  ]),
                ),
              ),
            ),
          ),
          if (list.isNotEmpty) _bar(list[_idx], inset),
        ]),
      ),
    );
  }
}

// ============================================================================
// Grid tile for a reel on a profile.
// ============================================================================
class ReelTile extends StatelessWidget {
  final Reel reel;
  final VoidCallback onTap;
  const ReelTile(this.reel, {super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    Widget bg;
    if (reel.poster != null) {
      bg = Image.file(File(reel.poster!), fit: BoxFit.cover, gaplessPlayback: true, cacheWidth: 400);
    } else if (reel.video != null) {
      bg = _VideoFrame(reel.video!);
    } else {
      bg = DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [hsl(reel.hue, .75, .42), hsl(reel.hue + 90, .8, .28)],
          ),
        ),
        child: Center(
          child: Icon(mediaIcons[reel.icon % mediaIcons.length], size: 34, color: Colors.white.withAlpha(160)),
        ),
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: RepaintBoundary(
        child: Stack(fit: StackFit.expand, children: [
          Container(color: p.card),
          bg,
          const Positioned(
            left: 0, right: 0, bottom: 0, height: 44,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0x99000000)]),
              ),
            ),
          ),
          Positioned(
            left: 7, bottom: 6,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(LucideIcons.play, size: 12, color: Colors.white),
              const SizedBox(width: 4),
              Text(compact(reel.likeCount), style: ts(Colors.white, 12, FontWeight.w700)),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Shows the first frame of a local video. Only a few decoders run at once, so a
/// long grid never exhausts the phone's video codecs; the rest show a plain tile.
class _VideoFrame extends StatefulWidget {
  final String path;
  const _VideoFrame(this.path);
  @override
  State<_VideoFrame> createState() => _VideoFrameState();
}

class _Gate {
  static const _max = 4;
  static int _n = 0;
  static bool take() {
    if (_n >= _max) return false;
    _n++;
    return true;
  }

  static void free() {
    if (_n > 0) _n--;
  }
}

class _VideoFrameState extends State<_VideoFrame> {
  VideoPlayerController? _c;
  bool _ready = false, _held = false;

  @override
  void initState() {
    super.initState();
    if (!_Gate.take()) return;
    _held = true;
    final c = VideoPlayerController.file(File(widget.path));
    _c = c;
    c.initialize().then((_) async {
      if (!mounted || _c != c) return;
      await c.setVolume(0);
      await c.seekTo(const Duration(milliseconds: 120));
      if (mounted && _c == c) setState(() => _ready = true);
    }).catchError((Object _) {});
  }

  @override
  void dispose() {
    _c?.dispose();
    if (_held) _Gate.free();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (!_ready || c == null || !c.value.isInitialized) {
      return Center(child: Icon(LucideIcons.clapperboard, size: 28, color: context.p.sub));
    }
    final size = c.value.size;
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(width: size.width, height: size.height, child: VideoPlayer(c)),
      ),
    );
  }
}

/// First row of Profile > Reels (only on your own profile).
class DraftsRow extends StatelessWidget {
  const DraftsRow({super.key});
  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final s = context.s;
    final n = s.drafts.length;
    return Tap(
      onTap: () {
        if (n == 0) {
          toast(context, 'No drafts yet');
          return;
        }
        Navigator.of(context).push(slide(const DraftsScreen(), name: 'drafts'));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.line))),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(14)),
            child: Icon(LucideIcons.fileText, size: 22, color: p.accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Drafts', style: ts(p.text, 16, FontWeight.w800)),
              const SizedBox(height: 2),
              Text(n == 0 ? 'Only you can see your drafts' : '$n saved · only you can see them',
                  style: ts(p.sub, 13)),
            ]),
          ),
          Icon(LucideIcons.chevronRight, size: 20, color: p.sub),
        ]),
      ),
    );
  }
}
