
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';
import '../media_picker.dart';
import '../theme.dart';
import '../widgets.dart';

/// Fullscreen viewer. Photos: pinch / double-tap zoom + save to gallery.
/// Videos: playback with a seek bar, and no save / download button.
class MediaViewer extends StatefulWidget {
  final String? image; // photo path (or the poster of a video)
  final String? video; // video path
  final int? placeholder; // demo media index (gradient art)
  const MediaViewer({super.key, this.image, this.video, this.placeholder});
  @override
  State<MediaViewer> createState() => _ViewerState();
}

class _ViewerState extends State<MediaViewer> with SingleTickerProviderStateMixin {
  final _tc = TransformationController();
  late final AnimationController _ac =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 240));
  Animation<Matrix4>? _anim;
  Offset _tap = Offset.zero;
  bool _ui = true, _saving = false, _failed = false;
  VideoPlayerController? _v;

  bool get _isVideo => widget.video != null;
  bool get _canSave => !_isVideo && widget.image != null;

  @override
  void initState() {
    super.initState();
    _ac.addListener(() {
      final a = _anim;
      if (a != null) _tc.value = a.value;
    });
    if (_isVideo) {
      final v = VideoPlayerController.file(File(widget.video!));
      _v = v;
      v.setLooping(true);
      v.initialize().then((_) {
        if (!mounted) return;
        v.play();
        setState(() {});
      }).catchError((Object _) {
        if (mounted) setState(() => _failed = true);
      });
    }
  }

  @override
  void dispose() {
    _tc.dispose();
    _ac.dispose();
    _v?.dispose();
    super.dispose();
  }

  void _doubleTap() {
    final zoomed = _tc.value.getMaxScaleOnAxis() > 1.05;
    const z = 2.6;
    final end = zoomed
        ? Matrix4.identity()
        : (Matrix4.identity()
          ..setEntry(0, 0, z)
          ..setEntry(1, 1, z)
          ..setEntry(0, 3, -_tap.dx * (z - 1))
          ..setEntry(1, 3, -_tap.dy * (z - 1)));
    _anim = Matrix4Tween(begin: _tc.value, end: end)
        .animate(CurvedAnimation(parent: _ac, curve: Curves.easeOutCubic));
    _ac.forward(from: 0);
  }

  Future<void> _toggle() async {
    final v = _v;
    if (v == null || !v.value.isInitialized) return;
    if (v.value.isPlaying) {
      await v.pause();
    } else {
      await v.play();
    }
  }

  Future<void> _save() async {
    final path = widget.image;
    if (path == null || _saving) return;
    setState(() => _saving = true);
    final name = 'Intly_${DateTime.now().millisecondsSinceEpoch}.jpg';
    bool ok = false;
    try {
      await PhotoManager.editor.saveImageWithPath(path, title: name);
      ok = true;
    } catch (_) {
      try {
        if (await MediaLibrary.I.requestAccess()) {
          await PhotoManager.editor.saveImageWithPath(path, title: name);
          ok = true;
        }
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() => _saving = false);
    toast(context, ok ? 'Saved to your gallery' : 'Could not save the photo');
  }

  String _fmt(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  Widget _poster() => widget.image == null
      ? const SizedBox.shrink()
      : Image.file(File(widget.image!),
          fit: BoxFit.contain, width: double.infinity, height: double.infinity,
          errorBuilder: (_, __, ___) => const SizedBox.shrink());

  Widget _zoomable() {
    final Widget child = widget.image != null
        ? _poster()
        : mediaPlaceholder(widget.placeholder ?? 0, iconSize: 90);
    return GestureDetector(
      onTap: () => setState(() => _ui = !_ui),
      onDoubleTapDown: (d) => _tap = d.localPosition,
      onDoubleTap: _doubleTap,
      child: InteractiveViewer(
        transformationController: _tc,
        minScale: 1,
        maxScale: 5,
        child: child,
      ),
    );
  }

  Widget _video() {
    final v = _v!;
    if (!v.value.isInitialized) {
      return Stack(fit: StackFit.expand, children: [
        _poster(),
        Center(
          child: _failed
              ? Text('Could not play this video', style: ts(Colors.white, 15, FontWeight.w600))
              : const CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
        ),
      ]);
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _ui = !_ui),
      onDoubleTap: _toggle,
      child: Center(child: AspectRatio(aspectRatio: v.value.aspectRatio, child: VideoPlayer(v))),
    );
  }

  Widget _topBar() => Positioned(
        top: 0, left: 0, right: 0,
        child: AnimatedOpacity(
          opacity: _ui ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          child: IgnorePointer(
            ignoring: !_ui,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x99000000), Color(0x00000000)]),
              ),
              child: SafeArea(
                bottom: false,
                child: SizedBox(
                  height: 56,
                  child: Row(children: [
                    const SizedBox(width: 6),
                    IconBtn(LucideIcons.arrowLeft, () => Navigator.of(context).maybePop(), color: Colors.white),
                    const Spacer(),
                    if (_canSave)
                      _saving
                          ? const Padding(
                              padding: EdgeInsets.all(14),
                              child: SizedBox(
                                  width: 22, height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)),
                            )
                          : IconBtn(LucideIcons.download, _save, color: Colors.white),
                    const SizedBox(width: 6),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );

  Widget _controls() {
    final v = _v;
    if (v == null || !v.value.isInitialized) return const SizedBox.shrink();
    return Positioned(
      left: 0, right: 0, bottom: 0,
      child: AnimatedOpacity(
        opacity: _ui ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        child: IgnorePointer(
          ignoring: !_ui,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0x99000000)]),
            ),
            child: SafeArea(
              top: false,
              child: ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: v,
                builder: (context, val, _) => Padding(
                  padding: const EdgeInsets.fromLTRB(6, 8, 18, 8),
                  child: Row(children: [
                    IconBtn(val.isPlaying ? LucideIcons.pause : LucideIcons.play, _toggle, color: Colors.white),
                    Text(_fmt(val.position), style: ts(Colors.white, 12, FontWeight.w600)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: VideoProgressIndicator(
                        v,
                        allowScrubbing: true,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        colors: const VideoProgressColors(
                          playedColor: Colors.white,
                          bufferedColor: Colors.white30,
                          backgroundColor: Colors.white24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(_fmt(val.duration), style: ts(Colors.white, 12, FontWeight.w600)),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(fit: StackFit.expand, children: [
          Positioned.fill(child: _isVideo ? _video() : _zoomable()),
          _topBar(),
          if (_isVideo) _controls(),
        ]),
      ),
    );
  }
}
