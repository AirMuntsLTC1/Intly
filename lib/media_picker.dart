import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'theme.dart';
import 'widgets.dart';

/// What the picker hands back: a photo, or a video plus its poster frame.
class PickedMedia {
  final String image; // photo path, or poster of the video
  final String? video; // video path (null for photos)
  const PickedMedia(this.image, [this.video]);
}

/// Opens the custom media picker. Returns the saved media, or null.
Future<PickedMedia?> pickMedia(BuildContext c, {MediaLibrary? lib}) => Navigator.of(c)
    .push<PickedMedia>(slide<PickedMedia>(MediaPickerScreen(lib: lib ?? MediaLibrary.I)));

/// Session-wide gallery cache: albums, pages of assets and thumbnails are kept in
/// memory, so re-opening the picker or scrolling back never reloads anything.
class MediaLibrary extends ChangeNotifier {
  MediaLibrary._(this.type);
  /// photos + videos (post composer)
  static final MediaLibrary I = MediaLibrary._(RequestType.common);
  /// videos only (reels)
  static final MediaLibrary V = MediaLibrary._(RequestType.video);
  /// audio files on the device (reel sounds)
  static final MediaLibrary A = MediaLibrary._(RequestType.audio);
  final RequestType type;

  static const _pageSize = 90;
  static const _maxThumbs = 700;

  List<AssetPathEntity> albums = [];
  final Map<String, int> counts = {};
  AssetPathEntity? current;
  final List<AssetEntity> assets = [];
  bool granted = false, ready = false, loading = false, hasMore = true;

  bool _dirty = false, _watching = false;
  int _gen = 0, _next = 0;
  final LinkedHashMap<String, Uint8List> _thumbs = LinkedHashMap();
  final Map<String, Future<Uint8List?>> _pending = {};

  /// Shows the system permission dialog when access has not been granted yet.
  Future<bool> requestAccess() async {
    final st = await PhotoManager.requestPermissionExtend(
      requestOption: PermissionRequestOption(
        androidPermission: AndroidPermission(type: type, mediaLocation: false),
      ),
    );
    granted = st.hasAccess;
    if (granted && !_watching) {
      _watching = true;
      // a new photo was taken / deleted: refresh quietly the next time the picker opens
      PhotoManager.addChangeCallback((_) => _dirty = true);
      PhotoManager.startChangeNotify();
    }
    notifyListeners();
    return granted;
  }

  Future<void> ensureLoaded() async {
    if (ready && !_dirty) return;
    final gen = ++_gen;
    final list = await PhotoManager.getAssetPathList(
      type: type,
      onlyAll: false,
      filterOption: FilterOptionGroup(
        orders: [OrderOption(type: OrderOptionType.createDate, asc: false)],
      ),
    );
    if (gen != _gen) return;
    albums = list;
    await Future.wait(list.map((a) async {
      counts[a.id] = await a.assetCountAsync;
    }));
    if (gen != _gen) return;
    AssetPathEntity? keep;
    for (final a in list) {
      if (a.id == current?.id) keep = a;
    }
    _dirty = false;
    ready = true;
    await selectAlbum(keep ?? (list.isEmpty ? null : list.first));
  }

  Future<void> selectAlbum(AssetPathEntity? a) async {
    _gen++;
    loading = false;
    current = a;
    assets.clear();
    _next = 0;
    hasMore = a != null;
    notifyListeners();
    await loadMore();
  }

  Future<void> loadMore() async {
    final a = current;
    if (a == null || loading || !hasMore) return;
    final gen = _gen;
    loading = true;
    List<AssetEntity> list = const [];
    try {
      list = await a.getAssetListPaged(page: _next, size: _pageSize);
    } catch (_) {}
    if (gen != _gen) return;
    loading = false;
    assets.addAll(list);
    _next++;
    if (list.length < _pageSize) hasMore = false;
    notifyListeners();
  }

  Uint8List? cached(AssetEntity a) {
    final b = _thumbs.remove(a.id);
    if (b != null) _thumbs[a.id] = b; // mark as recently used
    return b;
  }

  Future<Uint8List?> thumb(AssetEntity a) {
    final c = cached(a);
    if (c != null) return Future.value(c);
    return _pending[a.id] ??= _fetch(a);
  }

  Future<Uint8List?> _fetch(AssetEntity a) async {
    try {
      final b = await a.thumbnailDataWithSize(const ThumbnailSize(260, 260), quality: 80);
      if (b != null) {
        _thumbs[a.id] = b;
        while (_thumbs.length > _maxThumbs) {
          _thumbs.remove(_thumbs.keys.first);
        }
      }
      return b;
    } catch (_) {
      return null;
    } finally {
      _pending.remove(a.id);
    }
  }

  /// Saves the chosen photo (max 1600px, JPEG 85) or video (+ poster frame) into the
  /// app's media folder. Throws a String message when it cannot be used.
  Future<PickedMedia> export(AssetEntity a) async {
    final dir = await getApplicationDocumentsDirectory();
    final d = Directory('${dir.path}/media');
    if (!d.existsSync()) d.createSync(recursive: true);
    final ts = DateTime.now().millisecondsSinceEpoch;
    if (a.type == AssetType.video) {
      final src = await a.originFile;
      if (src == null) throw 'Could not open this video';
      if (await src.length() > 150 * 1024 * 1024) throw 'This video is too large (max 150 MB)';
      final poster = await a.thumbnailDataWithSize(const ThumbnailSize(1280, 1280), quality: 85);
      if (poster == null) throw 'Could not open this video';
      var ext = src.path.contains('.') ? src.path.split('.').last.toLowerCase() : 'mp4';
      if (ext.isEmpty || ext.length > 5) ext = 'mp4';
      final v = await src.copy('${d.path}/$ts.$ext');
      final img = File('${d.path}/$ts.jpg');
      await img.writeAsBytes(poster, flush: true);
      return PickedMedia(img.path, v.path);
    }
    try {
      final w = a.orientatedWidth, h = a.orientatedHeight;
      final big = w > h ? w : h;
      final ThumbnailSize size;
      if (w <= 0 || h <= 0) {
        size = const ThumbnailSize(1600, 1600);
      } else {
        final k = big > 1600 ? 1600 / big : 1.0;
        size = ThumbnailSize((w * k).round().clamp(1, 1600).toInt(), (h * k).round().clamp(1, 1600).toInt());
      }
      final bytes = await a.thumbnailDataWithSize(size, quality: 85);
      if (bytes == null) throw 'Could not open this photo';
      final f = File('${d.path}/$ts.jpg');
      await f.writeAsBytes(bytes, flush: true);
      return PickedMedia(f.path);
    } catch (e) {
      throw e is String ? e : 'Could not open this photo';
    }
  }
}

class MediaPickerScreen extends StatefulWidget {
  final MediaLibrary lib;
  const MediaPickerScreen({super.key, required this.lib});
  @override
  State<MediaPickerScreen> createState() => _MediaPickerState();
}

class _MediaPickerState extends State<MediaPickerScreen> {
  MediaLibrary get lib => widget.lib;
  final _scroll = ScrollController();
  bool _albums = false;
  String? _busy;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.hasClients && _scroll.position.extentAfter < 1400) lib.loadMore();
    });
    if (lib.granted) {
      WidgetsBinding.instance.addPostFrameCallback((_) => lib.ensureLoaded());
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _allow() async {
    final ok = await lib.requestAccess();
    if (!mounted) return;
    if (ok) lib.ensureLoaded();
  }

  Future<void> _choose(AssetEntity a) async {
    if (_busy != null) return;
    setState(() => _busy = a.id);
    PickedMedia? m;
    String err = 'Could not open this file';
    try {
      m = await lib.export(a);
    } catch (e) {
      if (e is String) err = e;
    }
    if (!mounted) return;
    if (m == null) {
      setState(() => _busy = null);
      toast(context, err);
      return;
    }
    Navigator.of(context).pop(m);
  }

  Widget _pill(Pal p) => Tap(
        onTap: lib.albums.isEmpty ? null : () => setState(() => _albums = !_albums),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 170),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(18)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Flexible(
              child: Text(lib.current?.name ?? 'Recent',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(p.text, 14, FontWeight.w700)),
            ),
            const SizedBox(width: 4),
            AnimatedRotation(
              turns: _albums ? .5 : 0,
              duration: const Duration(milliseconds: 160),
              child: Icon(LucideIcons.chevronDown, size: 16, color: p.sub),
            ),
          ]),
        ),
      );

  Widget _denied(Pal p) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(LucideIcons.image, size: 40, color: p.sub),
            const SizedBox(height: 12),
            Text('Allow access to your photos and videos to add media to your post.',
                textAlign: TextAlign.center, style: ts(p.sub, 15, FontWeight.w500, 1.4)),
            const SizedBox(height: 18),
            GradBtn('Allow access', _allow),
            const SizedBox(height: 6),
            Tap(
              onTap: () => PhotoManager.openSetting(),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Text('Open settings', style: ts(p.accent, 14, FontWeight.w700)),
              ),
            ),
          ]),
        ),
      );

  Widget _grid(Pal p) {
    if (!lib.granted) return _denied(p);
    if (!lib.ready) {
      return Center(child: CircularProgressIndicator(strokeWidth: 3, color: p.accent));
    }
    if (lib.assets.isEmpty && !lib.loading && !lib.hasMore) {
      return const Align(alignment: Alignment.topCenter, child: Empty(LucideIcons.image, 'No photos or videos found'));
    }
    return GridView.builder(
      controller: _scroll,
      cacheExtent: 900,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, mainAxisSpacing: 2, crossAxisSpacing: 2),
      itemCount: lib.assets.length,
      itemBuilder: (c, i) {
        final a = lib.assets[i];
        return _Thumb(key: ValueKey(a.id), lib: lib, asset: a, onTap: () => _choose(a));
      },
    );
  }

  Widget _albumList(Pal p) => Positioned.fill(
        child: Container(
          color: p.bg,
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: lib.albums.length,
            itemBuilder: (c, i) {
              final a = lib.albums[i];
              final sel = a.id == lib.current?.id;
              return Tap(
                onTap: () {
                  setState(() => _albums = false);
                  if (!sel) {
                    lib.selectAlbum(a);
                    if (_scroll.hasClients) _scroll.jumpTo(0);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.line))),
                  child: Row(children: [
                    Expanded(
                      child: Text(a.name,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: ts(sel ? p.accent : p.text, 16, FontWeight.w600)),
                    ),
                    Text('${lib.counts[a.id] ?? ''}', style: ts(p.sub, 13, FontWeight.w600)),
                  ]),
                ),
              );
            },
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Scaffold(
      backgroundColor: p.bg,
      body: ListenableBuilder(
        listenable: lib,
        builder: (context, _) => Column(children: [
          TopBar(lib.type == RequestType.video ? 'Select video' : 'Select media', back: true, actions: [if (lib.granted) _pill(p)]),
          Expanded(
            child: Stack(children: [
              Positioned.fill(child: _grid(p)),
              if (_albums) _albumList(p),
              if (_busy != null)
                Positioned.fill(
                  child: Container(
                    color: p.bg.withAlpha(150),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 3, color: p.accent)),
                  ),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Thumb extends StatefulWidget {
  final MediaLibrary lib;
  final AssetEntity asset;
  final VoidCallback onTap;
  const _Thumb({super.key, required this.lib, required this.asset, required this.onTap});
  @override
  State<_Thumb> createState() => _ThumbState();
}

class _ThumbState extends State<_Thumb> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    final lib = widget.lib;
    _bytes = lib.cached(widget.asset);
    if (_bytes == null) {
      lib.thumb(widget.asset).then((b) {
        if (mounted && b != null) setState(() => _bytes = b);
      });
    }
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Stack(fit: StackFit.expand, children: [
            Container(color: context.p.card),
            AnimatedOpacity(
              opacity: _bytes == null ? 0 : 1,
              duration: const Duration(milliseconds: 160),
              child: _bytes == null
                  ? const SizedBox.expand()
                  : Image.memory(_bytes!,
                      fit: BoxFit.cover, gaplessPlayback: true, filterQuality: FilterQuality.low),
            ),
            if (widget.asset.type == AssetType.video)
              Positioned(
                right: 5, bottom: 5,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                      color: const Color(0x99000000), borderRadius: BorderRadius.circular(8)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(LucideIcons.play, size: 10, color: Colors.white),
                    const SizedBox(width: 3),
                    Text(_dur(widget.asset.videoDuration), style: ts(Colors.white, 11, FontWeight.w700)),
                  ]),
                ),
              ),
          ]),
        ),
      );

  String _dur(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
}
