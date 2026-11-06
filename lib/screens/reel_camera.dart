
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';
import '../media_picker.dart';
import '../reel_fx.dart';
import '../theme.dart';
import '../widgets.dart';
import 'reel_audio.dart';

enum _Tool { none, length, speed, touch }

/// Reel camera: live preview, record, flip, flash, timer, speed, length, effects,
/// touch-up, sound, gallery. Everything is drawn with Lucide icons.
class ReelCameraScreen extends StatefulWidget {
  const ReelCameraScreen({super.key});
  @override
  State<ReelCameraScreen> createState() => _CamState();
}

class _CamState extends State<ReelCameraScreen> with WidgetsBindingObserver {
  List<CameraDescription> _cams = [];
  int _camIdx = 0;
  CameraController? _cc;
  bool _ready = false, _starting = false;
  String? _error;
  ResolutionPreset _quality = ResolutionPreset.high;

  bool _flash = false, _grid = false, _labels = true;
  int _timer = 0; // 0 / 3 / 10 seconds
  int _speedI = 2, _lenI = 0, _fx = 0;
  double _touch = 0;
  _Tool _tool = _Tool.none;
  PickedAudio? _audio;

  bool _rec = false;
  bool _cancelCount = false;
  int? _countdown;
  double _prog = 0;
  Duration _elapsed = Duration.zero;
  Timer? _ticker, _labelTimer;
  final AudioPlayer _player = AudioPlayer();

  double get _speed => reelSpeeds[_speedI];
  int get _maxSec => reelLengths[_lenI];
  bool get _front => _cams.isNotEmpty && _cams[_camIdx].lensDirection == CameraLensDirection.front;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _labelTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _labels = false);
    });
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _labelTimer?.cancel();
    _player.dispose();
    _cc?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      if (_rec) _stop(discard: true);
      final c = _cc;
      _cc = null;
      _ready = false;
      c?.dispose();
    } else if (state == AppLifecycleState.resumed && _cc == null && !_starting && _error == null) {
      _start();
    }
  }

  // ------------------------------------------------------------------ camera
  Future<void> _start() async {
    if (_starting) return;
    _starting = true;
    if (mounted) setState(() => _ready = false);
    final old = _cc;
    _cc = null;
    await old?.dispose();
    try {
      if (_cams.isEmpty) _cams = await availableCameras();
      if (_cams.isEmpty) {
        _error = 'No camera found on this phone';
      } else {
        CameraController c = CameraController(_cams[_camIdx], _quality, enableAudio: _audio == null);
        try {
          await c.initialize();
        } on CameraException catch (e) {
          if (e.code.startsWith('Audio')) {
            // microphone refused: still allow silent clips
            c = CameraController(_cams[_camIdx], _quality, enableAudio: false);
            await c.initialize();
          } else {
            rethrow;
          }
        }
        if (!mounted) {
          await c.dispose();
          _starting = false;
          return;
        }
        try {
          await c.setFlashMode(FlashMode.off);
        } catch (_) {}
        _cc = c;
        _error = null;
        _ready = true;
        if (_flash && !_front) {
          try {
            await c.setFlashMode(FlashMode.torch);
          } catch (_) {}
        }
      }
    } on CameraException catch (e) {
      _error = e.code.contains('Denied')
          ? 'Allow camera access to record reels.'
          : 'Could not open the camera (${e.code}).';
    } catch (_) {
      _error = 'Could not open the camera.';
    }
    _starting = false;
    if (mounted) setState(() {});
  }

  Future<void> _flip() async {
    if (_rec || _starting) return;
    final cur = _cams[_camIdx].lensDirection;
    final next = _cams.indexWhere((d) => d.lensDirection != cur);
    if (next < 0) {
      toast(context, 'No other camera found');
      return;
    }
    _camIdx = next;
    await _start();
  }

  Future<void> _toggleFlash() async {
    if (_front) {
      toast(context, 'Flash is only available on the back camera');
      return;
    }
    final c = _cc;
    if (c == null) return;
    final next = !_flash;
    try {
      await c.setFlashMode(next ? FlashMode.torch : FlashMode.off);
      setState(() => _flash = next);
    } catch (_) {
      if (mounted) toast(context, 'Flash is not available');
    }
  }

  // --------------------------------------------------------------- recording
  Future<void> _shutter() async {
    if (!_ready || _cc == null) return;
    if (_rec) {
      await _stop();
      return;
    }
    if (_countdown != null) {
      _cancelCount = true;
      return;
    }
    if (_timer > 0) {
      _cancelCount = false;
      for (int i = _timer; i > 0; i--) {
        if (!mounted) return;
        setState(() => _countdown = i);
        await Future.delayed(const Duration(seconds: 1));
        if (_cancelCount || !mounted) {
          if (mounted) setState(() => _countdown = null);
          return;
        }
      }
      if (mounted) setState(() => _countdown = null);
    }
    await _begin();
  }

  Future<void> _begin() async {
    final c = _cc;
    if (c == null || !mounted) return;
    try {
      await c.startVideoRecording();
    } catch (_) {
      if (mounted) toast(context, 'Could not start recording');
      return;
    }
    final a = _audio;
    if (a != null) {
      try {
        await _player.setReleaseMode(ReleaseMode.loop);
        await _player.play(DeviceFileSource(a.path));
      } catch (_) {}
    }
    final start = DateTime.now();
    setState(() {
      _rec = true;
      _prog = 0;
      _elapsed = Duration.zero;
      _tool = _Tool.none;
    });
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      final el = DateTime.now().difference(start);
      setState(() {
        _elapsed = el;
        _prog = (el.inMilliseconds / (_maxSec * 1000)).clamp(0.0, 1.0);
      });
      if (el.inSeconds >= _maxSec) _stop();
    });
  }

  Future<void> _stop({bool discard = false}) async {
    if (!_rec) return;
    _ticker?.cancel();
    final c = _cc;
    XFile? f;
    final took = _elapsed;
    try {
      f = await c?.stopVideoRecording();
    } catch (_) {}
    try {
      await _player.stop();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _rec = false;
      _prog = 0;
    });
    if (f == null || discard) return;
    if (took < const Duration(seconds: 1)) {
      try {
        await File(f.path).delete();
      } catch (_) {}
      if (mounted) toast(context, 'Hold a little longer to record a clip');
      return;
    }
    await _openPreview(f.path, owned: false);
  }

  Future<void> _openPreview(String path, {required bool owned, String? poster}) async {
    final done = await Navigator.of(context).push<bool>(slide<bool>(ReelPreviewScreen(
      video: path,
      owned: owned,
      poster: poster,
      audio: _audio,
      speed: _speed,
      fx: _fx,
      touch: _touch,
    )));
    if (done == true && mounted) Navigator.of(context).pop(true);
  }

  // ------------------------------------------------------------------ tools
  Future<void> _pickAudio() async {
    if (_rec) return;
    final a = await showAudioSheet(context);
    if (a == null || !mounted) return;
    setState(() => _audio = a);
    await _start(); // re-open without the microphone when a sound is used
  }

  Future<void> _removeAudio() async {
    setState(() => _audio = null);
    await _start();
  }

  void _effects() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: kSheetDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 14),
            Row(children: [
              const Icon(LucideIcons.sparkles, size: 20, color: Colors.white),
              const SizedBox(width: 8),
              Text('Effects', style: ts(Colors.white, 18, FontWeight.w800)),
            ]),
            const SizedBox(height: 14),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.05,
              children: [
                for (int i = 0; i < reelEffects.length; i++)
                  GestureDetector(
                    onTap: () {
                      setState(() => _fx = i);
                      Navigator.pop(sheet);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: kSheetDarker,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _fx == i ? const Color(0xFF3B9BFF) : Colors.transparent, width: 2),
                      ),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Container(
                          width: 58, height: 58,
                          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
                          child: ClipOval(
                            child: i == 0
                                ? Container(color: Colors.white24, child: const Icon(LucideIcons.ban, color: Colors.white, size: 26))
                                : reelFx(
                                    Container(
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [Color(0xFFFFC371), Color(0xFFFF5F6D), Color(0xFF3B6FFF)],
                                        ),
                                      ),
                                      child: Icon(reelEffects[i].icon, color: Colors.white, size: 26),
                                    ),
                                    i, 0),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(reelEffects[i].name, style: ts(Colors.white, 13, FontWeight.w600)),
                      ]),
                    ),
                  ),
              ],
            ),
          ]),
        ),
      ),
    );
  }

  void _settings() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: kSheetDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (sheet) => StatefulBuilder(
        builder: (context, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 14),
              Text('Camera settings', style: ts(Colors.white, 18, FontWeight.w800)),
              const SizedBox(height: 14),
              Row(children: [
                const Icon(LucideIcons.hash, size: 22, color: Colors.white),
                const SizedBox(width: 14),
                Expanded(child: Text('Grid lines', style: ts(Colors.white, 16, FontWeight.w600))),
                Switch(
                  value: _grid,
                  activeTrackColor: const Color(0xFF7C5CFF),
                  onChanged: (v) {
                    setState(() => _grid = v);
                    setSheet(() {});
                  },
                ),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                const Icon(LucideIcons.video, size: 22, color: Colors.white),
                const SizedBox(width: 14),
                Expanded(child: Text('Video quality', style: ts(Colors.white, 16, FontWeight.w600))),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                for (final q in const [
                  (ResolutionPreset.medium, '480p'),
                  (ResolutionPreset.high, '720p'),
                  (ResolutionPreset.veryHigh, '1080p'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () {
                        if (_quality == q.$1) return;
                        _quality = q.$1;
                        setSheet(() {});
                        _start();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                        decoration: BoxDecoration(
                          color: _quality == q.$1 ? Colors.white : kSheetDarker,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(q.$2, style: ts(_quality == q.$1 ? Colors.black : Colors.white, 14, FontWeight.w700)),
                      ),
                    ),
                  ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _gallery() async {
    if (_rec) return;
    final lib = MediaLibrary.V;
    await lib.requestAccess();
    if (!mounted) return;
    final m = await pickMedia(context, lib: lib);
    if (m == null || m.video == null || !mounted) return;
    await _openPreview(m.video!, owned: true, poster: m.image);
  }

  void _openTool(_Tool t) => setState(() => _tool = _tool == t ? _Tool.none : t);

  // ---------------------------------------------------------------------- UI
  Widget _circle(IconData icon, VoidCallback onTap, {String? label, bool on = false}) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 64, height: 40,
          decoration: BoxDecoration(
            color: on ? Colors.white : const Color(0x55FFFFFF),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 22, color: on ? Colors.black : Colors.white),
            if (label != null) ...[
              const SizedBox(width: 4),
              Text(label, style: ts(on ? Colors.black : Colors.white, 14, FontWeight.w800)),
            ],
          ]),
        ),
      );

  Widget _topBar() => Positioned(
        top: 0, left: 0, right: 0,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: _rec
                ? Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(color: const Color(0x88000000), borderRadius: BorderRadius.circular(16)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(LucideIcons.circle, size: 10, color: Color(0xFFFF3B5C)),
                        const SizedBox(width: 8),
                        Text(
                          '${_elapsed.inMinutes}:${(_elapsed.inSeconds % 60).toString().padLeft(2, '0')}',
                          style: ts(Colors.white, 15, FontWeight.w800),
                        ),
                      ]),
                    ),
                  )
                : Column(children: [
                    Row(children: [
                      IconBtn(LucideIcons.x, () => Navigator.of(context).maybePop(), color: Colors.white),
                      const Spacer(),
                      _circle(_flash ? LucideIcons.zap : LucideIcons.zapOff, _toggleFlash, on: _flash),
                      const SizedBox(width: 8),
                      _circle(LucideIcons.gauge, () => _openTool(_Tool.speed),
                          label: '${_speed == _speed.roundToDouble() ? _speed.toInt() : _speed}×', on: _speedI != 2),
                      const SizedBox(width: 8),
                      _circle(LucideIcons.timer, () => setState(() => _timer = _timer == 0 ? 3 : (_timer == 3 ? 10 : 0)),
                          label: _timer == 0 ? null : '${_timer}s', on: _timer != 0),
                      const Spacer(),
                      IconBtn(LucideIcons.settings, _settings, color: Colors.white),
                    ]),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _pickAudio,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 260),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                        decoration: BoxDecoration(color: const Color(0x66000000), borderRadius: BorderRadius.circular(22)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(LucideIcons.music, size: 18, color: Colors.white),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(_audio?.name ?? 'Add audio',
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: ts(Colors.white, 15, FontWeight.w700)),
                          ),
                          if (_audio != null) ...[
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: _removeAudio,
                              child: const Icon(LucideIcons.x, size: 18, color: Colors.white70),
                            ),
                          ],
                        ]),
                      ),
                    ),
                  ]),
          ),
        ),
      );

  Widget _tool_(IconData icon, String label, VoidCallback onTap, {Widget? badge, bool dim = false}) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Opacity(
            opacity: dim ? .55 : 1,
            child: Row(children: [
              SizedBox(
                width: 40, height: 40,
                child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
                  Icon(icon, size: 30, color: Colors.white),
                  if (badge != null) Positioned(right: -4, bottom: -2, child: badge),
                ]),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                child: _labels
                    ? Padding(
                        padding: const EdgeInsets.only(left: 14),
                        child: Text(label, style: ts(Colors.white, 15, FontWeight.w600)),
                      )
                    : const SizedBox.shrink(),
              ),
            ]),
          ),
        ),
      );

  Widget _lengthTool() {
    if (_tool != _Tool.length) {
      return _tool_(LucideIcons.hourglass, 'Length', () => _openTool(_Tool.length),
          badge: _lenI == 0
              ? null
              : _badge(reelLengthLabel(_maxSec)));
    }
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: const Color(0xCC222222), borderRadius: BorderRadius.circular(22)),
      child: SizedBox(
        width: 144,
        child: Wrap(spacing: 8, runSpacing: 8, children: [
          for (int i = 0; i < reelLengths.length; i++)
            GestureDetector(
              onTap: () => setState(() {
                _lenI = i;
                _tool = _Tool.none;
              }),
              child: Container(
                width: 64, height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _lenI == i ? Colors.white : Colors.transparent,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Text(reelLengthLabel(reelLengths[i]),
                    style: ts(_lenI == i ? Colors.black : Colors.white, 18, FontWeight.w800)),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _badge(String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(9)),
        child: Text(t, style: ts(Colors.white, 10, FontWeight.w800)),
      );

  Widget _tools() => Positioned(
        left: 14, bottom: 12,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          _tool_(LucideIcons.music, 'Audio', _pickAudio),
          _tool_(LucideIcons.sparkles, 'Effects', _effects, badge: _fx == 0 ? null : _badge('•')),
          _tool_(LucideIcons.scanFace, 'Green Screen', () {
            toast(context, 'Green screen needs on-device person cut-out, which is not available yet');
          }, dim: true),
          _tool_(LucideIcons.wand, 'Touch up', () => _openTool(_Tool.touch),
              badge: _touch > 0.01 ? _badge('${(_touch * 100).round()}') : null),
          _lengthTool(),
        ]),
      );

  Widget _touchBar() {
    const h = 230.0;
    return Positioned(
      left: 72, bottom: 96,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('${(_touch * 100).round()}', style: ts(Colors.white, 16, FontWeight.w700)),
        const SizedBox(height: 8),
        GestureDetector(
          onVerticalDragUpdate: (d) =>
              setState(() => _touch = (_touch - d.delta.dy / h).clamp(0.0, 1.0)),
          onTapDown: (d) => setState(() => _touch = (1 - d.localPosition.dy / h).clamp(0.0, 1.0)),
          child: Container(
            width: 56, height: h,
            alignment: Alignment.bottomCenter,
            decoration: BoxDecoration(color: const Color(0x66000000), borderRadius: BorderRadius.circular(18)),
            child: Container(
              width: 56, height: h * _touch,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => setState(() {
            _touch = 0;
            _tool = _Tool.none;
          }),
          child: const CircleAvatar(
            radius: 14,
            backgroundColor: Colors.black87,
            child: Icon(LucideIcons.x, size: 16, color: Colors.white),
          ),
        ),
      ]),
    );
  }

  Widget _speedBar() => Positioned(
        left: 0, right: 0, bottom: 14,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: const Color(0x99000000), borderRadius: BorderRadius.circular(22)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              for (int i = 0; i < reelSpeeds.length; i++)
                GestureDetector(
                  onTap: () => setState(() {
                    _speedI = i;
                    _tool = _Tool.none;
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: _speedI == i ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      '${reelSpeeds[i] == reelSpeeds[i].roundToDouble() ? reelSpeeds[i].toInt() : reelSpeeds[i]}×',
                      style: ts(_speedI == i ? Colors.black : Colors.white, 14, FontWeight.w800),
                    ),
                  ),
                ),
            ]),
          ),
        ),
      );

  Widget _preview() {
    final c = _cc;
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(LucideIcons.video, size: 44, color: Colors.white54),
            const SizedBox(height: 14),
            Text(_error!, textAlign: TextAlign.center, style: ts(Colors.white70, 15, FontWeight.w500, 1.4)),
            const SizedBox(height: 18),
            GradBtn('Try again', () {
              _error = null;
              _start();
            }),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => PhotoManager.openSetting(),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Text('Open settings', style: ts(Colors.white, 14, FontWeight.w700)),
              ),
            ),
          ]),
        ),
      );
    }
    if (c == null || !_ready || !c.value.isInitialized || c.value.previewSize == null) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white));
    }
    final ps = c.value.previewSize!;
    final view = FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(width: ps.height, height: ps.width, child: CameraPreview(c)),
    );
    return Stack(fit: StackFit.expand, children: [
      reelFx(view, _fx, _touch),
      if (_grid) const IgnorePointer(child: CustomPaint(painter: _GridPainter())),
    ]);
  }

  Widget _bottomBar() {
    final bottom = MediaQuery.of(context).padding.bottom;
    return SizedBox(
      height: 150 + bottom,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: Stack(children: [
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: GestureDetector(
                onTap: _shutter,
                child: SizedBox(
                  width: 92, height: 92,
                  child: CustomPaint(painter: _ShutterPainter(_prog, _rec, _countdown != null)),
                ),
              ),
            ),
          ),
          if (!_rec) ...[
            Positioned(
              left: 24, top: 34,
              child: GestureDetector(
                onTap: _gallery,
                child: Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(LucideIcons.images, size: 22, color: Colors.white),
                ),
              ),
            ),
            Positioned(
              right: 24, top: 34,
              child: GestureDetector(
                onTap: _flip,
                child: const SizedBox(
                  width: 48, height: 48,
                  child: Icon(LucideIcons.refreshCw, size: 30, color: Colors.white),
                ),
              ),
            ),
          ],
          Align(
            alignment: Alignment.bottomCenter,
            child: Text(_rec ? 'TAP TO STOP' : 'REEL',
                style: ts(Colors.white, 13, FontWeight.w800).copyWith(letterSpacing: 2.5)),
          ),
        ]),
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
        body: Column(children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(26)),
              child: Stack(fit: StackFit.expand, children: [
                Container(color: const Color(0xFF111111)),
                _preview(),
                if (_ready && !_rec) ...[
                  _tools(),
                  if (_tool == _Tool.touch) _touchBar(),
                  if (_tool == _Tool.speed) _speedBar(),
                ],
                _topBar(),
                if (_countdown != null)
                  IgnorePointer(
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: Text('$_countdown',
                            key: ValueKey(_countdown),
                            style: ts(Colors.white, 130, FontWeight.w800)),
                      ),
                    ),
                  ),
              ]),
            ),
          ),
          _bottomBar(),
        ]),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0x66FFFFFF)
      ..strokeWidth = 1;
    for (int i = 1; i < 3; i++) {
      canvas.drawLine(Offset(size.width * i / 3, 0), Offset(size.width * i / 3, size.height), p);
      canvas.drawLine(Offset(0, size.height * i / 3), Offset(size.width, size.height * i / 3), p);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => false;
}

class _ShutterPainter extends CustomPainter {
  final double progress;
  final bool rec, waiting;
  const _ShutterPainter(this.progress, this.rec, this.waiting);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.drawCircle(
      c, r - 3,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = const Color(0xE6FFFFFF),
    );
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r - 3),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 6
          ..color = const Color(0xFFFF3B5C),
      );
    }
    if (rec) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: 34, height: 34), const Radius.circular(9)),
        Paint()..color = const Color(0xFFFF3B5C),
      );
    } else {
      canvas.drawCircle(c, r - 13, Paint()..color = waiting ? const Color(0xFFFFB3C0) : const Color(0xFFF1F1F1));
    }
  }

  @override
  bool shouldRepaint(_ShutterPainter o) => o.progress != progress || o.rec != rec || o.waiting != waiting;
}

// ============================================================================
// After recording: preview with the chosen effect + sound, add a caption, share.
// ============================================================================
class ReelPreviewScreen extends StatefulWidget {
  final String video;
  final bool owned; // already inside the app's media folder
  final String? poster; // cover image when the video came from the gallery
  final PickedAudio? audio;
  final double speed, touch;
  final int fx;
  const ReelPreviewScreen({
    super.key, required this.video, required this.owned, this.poster, required this.audio,
    required this.speed, required this.fx, required this.touch,
  });
  @override
  State<ReelPreviewScreen> createState() => _PreviewState();
}

class _PreviewState extends State<ReelPreviewScreen> {
  VideoPlayerController? _v;
  AudioPlayer? _a;
  final _cap = TextEditingController();
  bool _saving = false, _failed = false;

  @override
  void initState() {
    super.initState();
    final c = VideoPlayerController.file(File(widget.video));
    _v = c;
    c.setLooping(true);
    c.initialize().then((_) async {
      if (!mounted) return;
      await c.setPlaybackSpeed(widget.speed);
      if (widget.audio != null) {
        await c.setVolume(0);
        final a = AudioPlayer();
        _a = a;
        await a.setReleaseMode(ReleaseMode.loop);
        await a.setPlaybackRate(widget.speed);
        await a.play(DeviceFileSource(widget.audio!.path));
      }
      c.addListener(_tick);
      await c.play();
      setState(() {});
    }).catchError((Object _) {
      if (mounted) setState(() => _failed = true);
    });
  }

  Duration _last = Duration.zero;
  void _tick() {
    final pos = _v?.value.position ?? Duration.zero;
    if (pos + const Duration(milliseconds: 600) < _last) _a?.seek(Duration.zero);
    _last = pos;
  }

  @override
  void dispose() {
    _v?.removeListener(_tick);
    _v?.dispose();
    _a?.dispose();
    _cap.dispose();
    super.dispose();
  }

  /// Moves the video into the app's media folder (when it is not there yet).
  Future<String> _persist() async {
    String path = widget.video;
    if (!widget.owned) {
      final dir = await getApplicationDocumentsDirectory();
      final d = Directory('${dir.path}/media');
      if (!d.existsSync()) d.createSync(recursive: true);
      var ext = path.contains('.') ? path.split('.').last.toLowerCase() : 'mp4';
      if (ext.isEmpty || ext.length > 5) ext = 'mp4';
      final copy = await File(path).copy('${d.path}/reel_${DateTime.now().millisecondsSinceEpoch}.$ext');
      try {
        await File(path).delete();
      } catch (_) {}
      path = copy.path;
    }
    return path;
  }

  Future<void> _share() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final path = await _persist();
      if (!mounted) return;
      context.s.addReel(
        video: path,
        audio: widget.audio?.path,
        audioName: widget.audio?.name ?? 'Original audio',
        caption: _cap.text.trim(),
        speed: widget.speed,
        fx: widget.fx,
        touch: widget.touch,
        poster: widget.poster,
      );
      context.s.setTab(reelsTab);
      toast(context, 'Reel shared');
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      toast(context, 'Could not save the reel');
    }
  }

  /// Keeps the reel in drafts: only you see it, from Profile > Reels > Drafts.
  Future<void> _draft() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final path = await _persist();
      if (!mounted) return;
      context.s.addDraft(
        video: path,
        audio: widget.audio?.path,
        audioName: widget.audio?.name ?? 'Original audio',
        caption: _cap.text.trim(),
        speed: widget.speed,
        fx: widget.fx,
        touch: widget.touch,
        poster: widget.poster,
      );
      toast(context, 'Saved to drafts');
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      toast(context, 'Could not save the draft');
    }
  }

  Widget _pillBtn(String label, VoidCallback onTap, {required bool filled, IconData? icon}) {
    final p = context.p;
    return Tap(
      onTap: onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          gradient: filled ? p.grad : null,
          color: filled ? null : const Color(0x33FFFFFF),
          borderRadius: BorderRadius.circular(25),
          border: filled ? null : Border.all(color: Colors.white54, width: 1.4),
        ),
        alignment: Alignment.center,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(width: 8),
          ],
          Text(label, style: ts(Colors.white, 15, FontWeight.w800)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final v = _v;
    Widget media;
    if (_failed) {
      media = Center(child: Text('Could not play this video', style: ts(Colors.white, 15, FontWeight.w600)));
    } else if (v == null || !v.value.isInitialized) {
      media = const Center(child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white));
    } else {
      final size = v.value.size;
      final portrait = size.height >= size.width * 1.2;
      media = SizedBox.expand(
        child: reelFx(
          FittedBox(
            fit: portrait ? BoxFit.cover : BoxFit.contain,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(width: size.width, height: size.height, child: VideoPlayer(v)),
          ),
          widget.fx,
          widget.touch,
        ),
      );
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: true,
        body: Stack(fit: StackFit.expand, children: [
          media,
          const Positioned(
            left: 0, right: 0, bottom: 0, height: 280,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x00000000), Color(0xCC000000)]),
                ),
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
          Positioned(
            left: 16, right: 16, bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (widget.audio != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(children: [
                        const Icon(LucideIcons.music, size: 16, color: Colors.white),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(widget.audio!.name,
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: ts(Colors.white, 14, FontWeight.w600)),
                        ),
                      ]),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    height: 50,
                    decoration: BoxDecoration(color: const Color(0x55FFFFFF), borderRadius: BorderRadius.circular(25)),
                    alignment: Alignment.centerLeft,
                    child: TextField(
                      controller: _cap,
                      maxLength: 200,
                      style: ts(Colors.white, 15),
                      cursorColor: Colors.white,
                      decoration: InputDecoration(
                        counterText: '',
                        border: InputBorder.none,
                        hintText: 'Write a caption…',
                        hintStyle: ts(Colors.white70, 15),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 50,
                    child: _saving
                        ? const Center(child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                        : Row(children: [
                            Expanded(flex: 3, child: _pillBtn('Share reel', _share, filled: true)),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: _pillBtn('Draft', _draft, filled: false, icon: LucideIcons.fileText),
                            ),
                          ]),
                  ),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
