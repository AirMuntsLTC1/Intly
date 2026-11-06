import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../media_picker.dart';
import '../theme.dart';
import '../widgets.dart';

const kSheetDark = Color(0xFF23262D);
const kSheetDarker = Color(0xFF2E323A);

class PickedAudio {
  final String path, name;
  const PickedAudio(this.path, this.name);
}

/// "Add audio" sheet: lists the sounds stored on the phone (search, saved, pick).
Future<PickedAudio?> showAudioSheet(BuildContext c) => showModalBottomSheet<PickedAudio>(
      context: c,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: kSheetDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => const _AudioSheet(),
    );

class _AudioSheet extends StatefulWidget {
  const _AudioSheet();
  @override
  State<_AudioSheet> createState() => _AudioSheetState();
}

class _AudioSheetState extends State<_AudioSheet> {
  final lib = MediaLibrary.A;
  final _q = TextEditingController();
  final _scroll = ScrollController();
  final Map<String, String> _titles = {};
  Set<String> _saved = {};
  bool _onlySaved = false, _noAccess = false, _busy = false;

  @override
  void initState() {
    super.initState();
    lib.addListener(_onLib);
    _scroll.addListener(() {
      if (_scroll.hasClients && _scroll.position.extentAfter < 600) lib.loadMore();
    });
    _load();
  }

  @override
  void dispose() {
    lib.removeListener(_onLib);
    _q.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final sp = await SharedPreferences.getInstance();
    _saved = (sp.getStringList('audio_saved') ?? const []).toSet();
    final ok = lib.granted || await lib.requestAccess();
    if (!mounted) return;
    if (!ok) {
      setState(() => _noAccess = true);
      return;
    }
    await lib.ensureLoaded();
    await _fillTitles();
  }

  void _onLib() => _fillTitles();

  Future<void> _fillTitles() async {
    final todo = lib.assets.where((a) => !_titles.containsKey(a.id)).toList();
    if (todo.isNotEmpty) {
      await Future.wait(todo.map((a) async {
        try {
          _titles[a.id] = _clean(await a.titleAsync);
        } catch (_) {
          _titles[a.id] = 'Audio';
        }
      }));
    }
    if (mounted) setState(() {});
  }

  String _clean(String t) {
    final i = t.lastIndexOf('.');
    return (i > 0 ? t.substring(0, i) : t).replaceAll('_', ' ');
  }

  Future<void> _toggleSaved(AssetEntity a) async {
    setState(() => _saved.contains(a.id) ? _saved.remove(a.id) : _saved.add(a.id));
    final sp = await SharedPreferences.getInstance();
    await sp.setStringList('audio_saved', _saved.toList());
  }

  String _dur(int sec) => '${sec ~/ 60}:${(sec % 60).toString().padLeft(2, '0')}';

  Future<void> _pick(AssetEntity a) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final src = await a.originFile;
      if (src == null) throw 'Could not open this sound';
      final dir = await getApplicationDocumentsDirectory();
      final d = Directory('${dir.path}/media');
      if (!d.existsSync()) d.createSync(recursive: true);
      var ext = src.path.contains('.') ? src.path.split('.').last.toLowerCase() : 'mp3';
      if (ext.isEmpty || ext.length > 5) ext = 'mp3';
      final copy = await src.copy('${d.path}/audio_${DateTime.now().millisecondsSinceEpoch}.$ext');
      if (!mounted) return;
      Navigator.of(context).pop(PickedAudio(copy.path, _titles[a.id] ?? 'Audio'));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      toast(context, e is String ? e : 'Could not use this sound');
    }
  }

  Widget _chip(String label, bool on, VoidCallback f) => GestureDetector(
        onTap: f,
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          decoration: BoxDecoration(
            color: on ? Colors.white : kSheetDarker,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(label, style: ts(on ? Colors.black : Colors.white, 15, FontWeight.w700)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final query = _q.text.trim().toLowerCase();
    var list = lib.assets.toList();
    if (_onlySaved) list = list.where((a) => _saved.contains(a.id)).toList();
    if (query.isNotEmpty) {
      list = list.where((a) => (_titles[a.id] ?? '').toLowerCase().contains(query)).toList();
    }
    return Stack(children: [
      Column(children: [
        const SizedBox(height: 10),
        Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(color: kSheetDarker, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              const Icon(LucideIcons.search, size: 20, color: Colors.white60),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _q,
                  onChanged: (_) => setState(() {}),
                  style: ts(Colors.white, 15),
                  cursorColor: Colors.white,
                  decoration: InputDecoration.collapsed(hintText: 'Search sounds…', hintStyle: ts(Colors.white54, 15)),
                ),
              ),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(children: [
            _chip('On this phone', !_onlySaved, () => setState(() => _onlySaved = false)),
            _chip('Saved', _onlySaved, () => setState(() => _onlySaved = true)),
          ]),
        ),
        Expanded(
          child: _noAccess
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(LucideIcons.music, size: 40, color: Colors.white54),
                      const SizedBox(height: 12),
                      Text('Allow access to your audio files to pick a sound.',
                          textAlign: TextAlign.center, style: ts(Colors.white70, 15, FontWeight.w500, 1.4)),
                      const SizedBox(height: 16),
                      GradBtn('Open settings', () => PhotoManager.openSetting()),
                    ]),
                  ),
                )
              : !lib.ready
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                  : list.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text(
                              _onlySaved ? 'No saved sounds yet. Tap the bookmark on a sound.' : 'No sounds found.',
                              textAlign: TextAlign.center,
                              style: ts(Colors.white60, 15, FontWeight.w500, 1.4),
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _scroll,
                          itemCount: list.length,
                          itemBuilder: (c, i) {
                            final a = list[i];
                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _pick(a),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                                child: Row(children: [
                                  Container(
                                    width: 54, height: 54,
                                    decoration: BoxDecoration(
                                      color: kSheetDarker,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(LucideIcons.music, size: 24, color: Colors.white70),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(_titles[a.id] ?? '…',
                                          maxLines: 1, overflow: TextOverflow.ellipsis,
                                          style: ts(Colors.white, 16, FontWeight.w700)),
                                      const SizedBox(height: 2),
                                      Text('On this phone • ${_dur(a.duration)}',
                                          maxLines: 1, overflow: TextOverflow.ellipsis,
                                          style: ts(Colors.white60, 14)),
                                    ]),
                                  ),
                                  GestureDetector(
                                    onTap: () => _toggleSaved(a),
                                    child: Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: Icon(LucideIcons.bookmark, size: 26,
                                          color: _saved.contains(a.id) ? const Color(0xFF7C5CFF) : Colors.white),
                                    ),
                                  ),
                                ]),
                              ),
                            );
                          },
                        ),
        ),
      ]),
      if (_busy)
        const Positioned.fill(
          child: ColoredBox(
            color: Color(0x88000000),
            child: Center(child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white)),
          ),
        ),
    ]);
  }
}
