
import 'dart:async';

import 'package:flutter/widgets.dart';

import 'data/intly_repository.dart';
import 'data/local_cache.dart';
import 'data/media_cache.dart';
import 'native.dart';
import 'styles.dart';

double _between(double v, double lo, double hi) => v < lo ? lo : (v > hi ? hi : v);

int _minus(Object? total, bool mine) {
  final n = ((total as int?) ?? 0) - (mine ? 1 : 0);
  return n < 0 ? 0 : n;
}

DateTime? _ts(Object? v) => v is String ? DateTime.tryParse(v) : null;

int _ageMinutes(String iso) {
  final m = DateTime.now().toUtc().difference(DateTime.parse(iso).toUtc()).inMinutes;
  return m < 0 ? 0 : m;
}

class User {
  final String id;
  String name, handle, bio;
  int hue, followers, following;
  String? avatar; // local file of the profile photo, when it is on the phone
  bool isPrivate = false;
  DateTime? nameChangedAt, usernameChangedAt; // start of the 7-day cooldowns
  User(this.id, this.name, this.handle, this.bio, this.hue, this.followers, this.following);
}

class Post {
  final String id, userId;
  String text;
  int minutes;
  final int media, likes, shares;
  int commentCount;
  bool liked = false, saved = false;
  int bg = -1, font = 0, tcolor = -1;
  String? image; // photo, or the poster frame when [video] is set (local file)
  String? video; // local video file
  List<Sticker> stickers = [];
  Post(this.id, this.userId, this.text, this.minutes, this.media, this.likes,
      this.commentCount, this.shares);
  int get likeCount => likes + (liked ? 1 : 0);
}

class Comment {
  final String id, postId, userId, text;
  final int minutes;
  final String? parent; // id of the top-level comment when this is a reply
  final String? replyToUser; // set when replying to a reply
  Comment(this.id, this.postId, this.userId, this.text, this.minutes, this.parent,
      [this.replyToUser]);
}

class Notif {
  final String id, type, userId, text;
  final int minutes;
  final String? postId; // post this notification is about
  final String? commentId; // comment to highlight when the post opens
  bool read;
  Notif({
    required this.id,
    required this.type,
    required this.userId,
    required this.text,
    required this.minutes,
    required this.read,
    this.postId,
    this.commentId,
  });
}

class Reel {
  final String id, userId, audioName, caption;
  String? video; // local file; null until the video is on this phone
  String? audio; // optional sound track played with the video
  String? poster; // cover image for profile grids
  String? videoPath, audioPath, posterPath; // storage paths, used to download on demand
  final double speed, touch; // playback speed, touch-up strength 0..1
  final int fx, hue, icon, minutes, likes, reposts, saves;
  int comments, shares;
  bool liked = false, saved = false, reposted = false;
  Reel({
    required this.id,
    required this.userId,
    required this.caption,
    this.video,
    this.audio,
    this.poster,
    this.audioName = 'Original audio',
    this.speed = 1,
    this.touch = 0,
    this.fx = 0,
    this.hue = 0,
    this.icon = 0,
    this.minutes = 0,
    this.likes = 0,
    this.comments = 0,
    this.reposts = 0,
    this.shares = 0,
    this.saves = 0,
  });
  int get likeCount => likes + (liked ? 1 : 0);
  int get repostCount => reposts + (reposted ? 1 : 0);
  int get saveCount => saves + (saved ? 1 : 0);
}

/// A reel saved to drafts: only its author can see it, and it is not in any feed.
class ReelDraft {
  String id; // server id once saved
  final String video, audioName, caption;
  final String? audio, poster;
  final double speed, touch;
  final int fx, ts;
  String? videoPath, audioPath, posterPath; // storage paths, set after upload
  ReelDraft({
    required this.id,
    required this.video,
    required this.caption,
    required this.audioName,
    required this.speed,
    required this.touch,
    required this.fx,
    required this.ts,
    this.audio,
    this.poster,
    this.videoPath,
    this.audioPath,
    this.posterPath,
  });

  Reel toReel() => Reel(
        id: id,
        userId: 'me',
        caption: caption,
        video: video,
        audio: audio,
        poster: poster,
        audioName: audioName,
        speed: speed,
        touch: touch,
        fx: fx,
      );
}

class ReelComment {
  final String id, reelId, userId, text;
  final int minutes;
  final String? parent; // id of the top-level comment when this is a reply
  final String? replyToUser; // set when replying to a reply
  const ReelComment(this.id, this.reelId, this.userId, this.text, this.minutes,
      {this.parent, this.replyToUser});
}

class Scope extends InheritedNotifier<AppState> {
  const Scope({super.key, required AppState state, required super.child})
      : super(notifier: state);
  static AppState of(BuildContext c) =>
      c.dependOnInheritedWidgetOfExactType<Scope>()!.notifier!;
}

/// A change the user made that the server has not confirmed yet. While it is
/// pending, every refresh shows it, so the screen never flips back.
class _Pending {
  _Pending(this.value);
  final bool value;
  int? settled; // write-sequence number once the server accepted it
}

/// The app's state. Screens read it synchronously and call its methods.
///
/// Two queues go to Supabase, each in order:
///  * quick writes (likes, saves, follows, comments): never wait for uploads;
///  * uploads (photos and videos): one at a time, in the background.
/// A change shows at once and stays on screen until the server confirms it.
/// If the server refuses it, the change is undone and the user sees a message.
class AppState extends ChangeNotifier {
  static const Map<String, bool> _defaults = {
    'push': true, 'likes': true, 'follows': true, 'private': false, 'activity': true,
  };
  static const Map<String, String> _flagColumns = {
    'push': 'push_notifications',
    'likes': 'notify_likes',
    'follows': 'notify_follows',
    'activity': 'show_activity',
  };

  /// 'system' (default, follows the phone), 'light' or 'dark'.
  final mode = ValueNotifier<String>('system');

  /// Number of uploads still running (shows a "Posting…" pill).
  final ValueNotifier<int> uploads = ValueNotifier<int>(0);

  /// A short message for the user when something could not be saved.
  final ValueNotifier<String?> notice = ValueNotifier<String?>(null);

  /// Set when the last refresh failed (for example offline); cleared on success.
  final syncError = ValueNotifier<String?>(null);

  int tab = 0;
  final Map<String, User> users = {};
  final List<Post> posts = [];
  final List<Comment> comments = [];
  final List<Notif> notifs = [];
  final Set<String> following = {};
  final Set<String> reported = {};
  final Set<String> likedComments = {}; // comments and reply-comments you liked
  final Set<String> _pendingOut = {}; // follow requests you sent to private accounts
  final Map<String, List<String>> _followersOf = {}; // local id -> followers
  final Map<String, List<String>> _followingOf = {}; // local id -> accounts they follow
  final List<String> incoming = []; // people waiting for you to accept them
  final Map<String, int> _likeCounts = {}; // comment and reply ids -> hearts (incl. yours)
  final Set<String> _reelCommentIds = {};
  final List<Reel> reels = [];
  final Map<String, List<ReelComment>> reelComments = {};
  final List<ReelDraft> drafts = []; // newest first, private to you
  final Map<String, bool> flags = {..._defaults};
  late User me = User('me', 'You', 'you', 'Hello Intly 👋', 262, 0, 0);

  final Map<String, String> _idMap = {}; // temporary id -> server id
  final Map<String, _Pending> _ov = {}; // pending changes, by key (see _send)
  // Temporary reel id -> the server id, once its upload has finished.
  final Map<String, Future<String>> _reelReady = {};
  String? _avatarPath; // storage path of your current profile photo
  int _writeSeq = 0;
  RemoteSnapshot? _snap;
  Future<void>? _inFlight;
  Future<void> _chain = Future<void>.value();
  Future<void> _uploadChain = Future<void>.value();
  Timer? _saveTimer, _reapplyTimer;
  final Set<String> _downloading = {};

  User user(String id) => users[id] ?? User(id, 'Intly user', 'user', '', 262, 0, 0);
  int get unread => notifs.where((n) => !n.read).length;
  bool get isPrivate => flags['private'] ?? false;

  /// People who follow [id]. Use 'me' for yourself.
  List<String> followersList(String id) => [...(_followersOf[id] ?? const <String>[])];

  /// Accounts [id] follows. Use 'me' for yourself.
  List<String> followingList(String id) =>
      id == 'me' ? following.toList() : [...(_followingOf[id] ?? const <String>[])];

  /// Pending follow requests waiting for your answer.
  List<String> get requests => List.unmodifiable(incoming);

  int followersOf(User u) => followersList(u.id).length;
  int followingOf(User u) => followingList(u.id).length;

  List<Post> postsOf(String id) => posts.where((p) => p.userId == id).toList();
  List<Reel> reelsOf(String userId) => reels.where((r) => r.userId == userId).toList();
  List<Comment> commentsOf(String postId) => comments.where((c) => c.postId == postId).toList();

  int commentLikes(Comment c) => _likeCounts[c.id] ?? 0;
  int reelCommentLikes(ReelComment c) => _likeCounts[c.id] ?? 0;

  Post? postById(String? id) {
    if (id == null) return null;
    for (final p in posts) {
      if (p.id == id) return p;
    }
    return null;
  }

  Reel? reelById(String id) {
    for (final r in reels) {
      if (r.id == id) return r;
    }
    return null;
  }

  String notifText(Notif n) =>
      n.type == 'follow' && requests.contains(n.userId) ? 'requested to follow you' : n.text;

  // ---------------------------------------------------------------------------
  // Startup, sign-in and sign-out
  // ---------------------------------------------------------------------------

  /// Runs at launch, in parallel with the Supabase connection. It does not wait
  /// for the network: the last saved data appears as soon as it is read.
  Future<void> start() async {
    final sw = Stopwatch()..start();
    Native.init();
    await MediaCache.init();
    final uid = await LocalCache.lastUid();
    if (uid != null) await _loadCache(uid);
    debugPrint('Intly startup: native ${Native.initTime.inMilliseconds} ms '
        '(ok=${Native.ok}), cache ready after ${sw.elapsedMilliseconds} ms');
  }

  /// Called when someone signs in: keep showing what is already here, then fetch.
  Future<void> onSignedIn() async {
    final uid = IntlyRepo.currentUid;
    if (uid == null) return;
    unawaited(LocalCache.setLastUid(uid));
    if (_snap == null) await _loadCache(uid);
    await refresh();
  }

  /// Called when the user signs out: clear what this phone keeps for them.
  Future<void> onSignedOut() async {
    final uid = _snap?.uid;
    _snap = null;
    _resetMemory();
    notifyListeners();
    if (uid != null) await LocalCache.clear(uid);
    await LocalCache.clearLastUid();
    await MediaCache.clear();
  }

  /// Clears this phone's copy and downloads everything again. Nothing on the
  /// server is deleted.
  Future<void> reset() async {
    final uid = IntlyRepo.currentUid;
    if (uid != null) await LocalCache.clear(uid);
    _snap = null;
    await refresh();
  }

  Future<void> _loadCache(String uid) async {
    final data = await LocalCache.load(uid);
    if (data == null || _snap != null) return; // a fresher snapshot may have arrived
    _snap = RemoteSnapshot(data);
    _apply(_snap!);
    notifyListeners();
  }

  /// Fetches the latest data from Supabase. Overlapping calls share one request.
  Future<void> refresh() => _inFlight ??= _doRefresh().whenComplete(() => _inFlight = null);

  Future<void> _doRefresh() async {
    if (!IntlyRepo.signedIn) return;
    final startSeq = _writeSeq;
    try {
      final snap = await IntlyRepo.fetchSnapshot();
      _snap = snap;
      _apply(snap);
      // Changes confirmed before this fetch started are now part of the server data.
      _ov.removeWhere((_, e) => e.settled != null && e.settled! <= startSeq);
      syncError.value = null;
      notifyListeners();
      _scheduleSave(snap);
      unawaited(_downloadMissing(snap));
    } catch (e) {
      debugPrint('Intly refresh failed: $e');
      syncError.value = IntlyRepo.describe(e);
    }
  }

  void _scheduleSave(RemoteSnapshot snap) {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 1200), () {
      LocalCache.save(snap.uid, snap.data);
    });
  }

  void _resetMemory() {
    users.clear();
    posts.clear();
    comments.clear();
    notifs.clear();
    following.clear();
    reported.clear();
    likedComments.clear();
    _pendingOut.clear();
    _followersOf.clear();
    _followingOf.clear();
    incoming.clear();
    _likeCounts.clear();
    _reelCommentIds.clear();
    reels.clear();
    reelComments.clear();
    drafts.clear();
    _idMap.clear();
    _reelReady.clear();
    _ov.clear();
    flags
      ..clear()
      ..addAll(_defaults);
    mode.value = 'system';
    me.name = 'You';
    me.handle = 'you';
    me.bio = 'Hello Intly 👋';
  }

  // ---------------------------------------------------------------------------
  // Writes
  // ---------------------------------------------------------------------------

  /// Sends one quick write to Supabase, in order. When [key] is given, the
  /// change [value] is shown on screen until the server confirms it.
  Future<void> _send(Future<void> Function() op, {String? key, bool? value}) {
    final entry = key == null ? null : (_ov[key] = _Pending(value!));
    _chain = _chain.then((_) async {
      try {
        await op();
        if (entry != null && identical(_ov[key], entry)) entry.settled = ++_writeSeq;
      } catch (e) {
        debugPrint('Intly write failed: $e');
        if (entry != null && identical(_ov[key], entry)) _ov.remove(key);
        notice.value = IntlyRepo.describe(e);
        await refresh(); // re-read the server, which puts the screen back to the truth
      }
    });
    return _chain;
  }

  /// Sends an upload (photo or video) in the background, one at a time. The
  /// "Posting…" pill shows while it runs. Quick writes are not blocked by it.
  void _sendUpload(Future<void> Function() op, {VoidCallback? onFail}) {
    uploads.value++;
    _uploadChain = _uploadChain.then((_) async {
      try {
        await op();
      } catch (e) {
        debugPrint('Intly upload failed: $e');
        onFail?.call();
        notice.value = IntlyRepo.describe(e);
        notifyListeners();
      } finally {
        uploads.value--;
      }
    });
  }

  String? _real(String? id) => id == null ? null : (_idMap[id] ?? id);

  /// The server id of a reel. A reel still uploading has a temporary id; this
  /// waits for the upload. Returns null if the upload failed.
  Future<String?> _reelServerId(String id) async {
    final pending = _reelReady[id];
    if (pending == null) return id;
    try {
      return await pending;
    } catch (_) {
      return null;
    }
  }

  /// Runs a write against the reel's server id, after its upload if needed.
  Future<void> _onReel(String id, Future<void> Function(String realId) op) async {
    final real = await _reelServerId(id);
    if (real != null) await op(real);
  }

  void setTab(int i) {
    if (tab == i) return;
    tab = i;
    notifyListeners();
  }

  void setMode(String v) {
    mode.value = v;
    _send(() => IntlyRepo.updateSettings({'theme': v}));
  }

  void setFlag(String k, bool v) {
    flags[k] = v;
    notifyListeners();
    _send(() => k == 'private'
        ? IntlyRepo.setPrivate(v)
        : IntlyRepo.updateSettings({_flagColumns[k]!: v}));
  }

  /// Saves the profile form. Throws a readable message when the server refuses
  /// (a 7-day cooldown still running, or a taken @username). Nothing changes on
  /// screen in that case.
  Future<void> saveProfile({required String name, required String bio, String? username}) async {
    final cleanName = name.trim().isEmpty ? 'You' : name.trim();
    final cleanBio = bio.trim();
    await IntlyRepo.updateProfile(name: cleanName, bio: cleanBio, username: username);
    me.name = cleanName;
    me.bio = cleanBio;
    if (username != null) me.handle = username;
    notifyListeners();
    await refresh(); // pulls the new cooldown timestamps from the server
  }

  /// Shows the new profile photo at once, uploads it in the background, and
  /// puts the old photo back if the upload fails.
  void updateAvatar(String localFile) {
    final before = me.avatar;
    final oldPath = _avatarPath;
    me.avatar = localFile;
    notifyListeners();
    _sendUpload(() async {
      final path = await IntlyRepo.uploadAvatar(localFile);
      await IntlyRepo.setAvatarPath(path);
      if (oldPath != null) unawaited(IntlyRepo.removeAvatarFile(oldPath));
      await refresh();
    }, onFail: () {
      me.avatar = before;
      notifyListeners();
    });
  }

  // Posts ----------------------------------------------------------------------

  void toggleLike(Post p) {
    p.liked = !p.liked;
    notifyListeners();
    final on = p.liked;
    _send(() => IntlyRepo.setPostLike(p.id, on), key: 'pl:${p.id}', value: on);
  }

  void toggleSave(Post p) {
    p.saved = !p.saved;
    notifyListeners();
    final on = p.saved;
    _send(() => IntlyRepo.setPostSave(p.id, on), key: 'ps:${p.id}', value: on);
  }

  void reportPost(Post p) {
    reported.add(p.id);
    notifyListeners();
    _send(() => IntlyRepo.reportPost(p.id));
  }

  /// Creates a new post, or updates [edit] when editing. Local media files are
  /// uploaded in the background; the post is shown at once.
  void publish({
    Post? edit,
    required String text,
    required int bg,
    required int font,
    required int tcolor,
    String? image,
    String? video,
    required List<Sticker> stickers,
  }) {
    final mediaChanged = edit == null || image != edit.image || video != edit.video;
    final Post p;
    if (edit != null) {
      p = edit;
    } else {
      p = Post('new${DateTime.now().microsecondsSinceEpoch}', 'me', text, 0, -1, 0, 0, 0);
      posts.insert(0, p);
    }
    p.text = text;
    p.bg = bg;
    p.font = font;
    p.tcolor = tcolor;
    p.stickers = stickers;
    if (mediaChanged) {
      p.image = image;
      p.video = video;
    }
    notifyListeners();

    final editId = edit?.id;
    final stickerRows = <Map<String, dynamic>>[
      for (final s in stickers)
        {
          'emoji': s.e,
          'position_x': _between(s.x, 0, 1),
          'position_y': _between(s.y, 0, 1),
          'scale': _between(s.s, 0.1, 10),
        },
    ];
    Future<void> op() async {
      await IntlyRepo.savePost(
        id: editId,
        body: text,
        bg: bg,
        font: font,
        tcolor: tcolor,
        stickers: stickerRows,
        imageLocal: mediaChanged ? image : null,
        videoLocal: mediaChanged ? video : null,
        replaceMedia: mediaChanged,
      );
      await refresh();
    }

    void undo() {
      if (edit == null) {
        posts.remove(p);
        notifyListeners();
      }
    }

    if (mediaChanged && (image != null || video != null)) {
      _sendUpload(op, onFail: undo);
    } else {
      _send(op);
    }
  }

  void deletePost(Post p) {
    posts.remove(p);
    comments.removeWhere((c) => c.postId == p.id);
    notifyListeners();
    _send(() => IntlyRepo.deletePost(p.id));
  }

  // Comments -------------------------------------------------------------------

  void addComment(Post p, String text, {String? parent, String? replyToUser}) {
    final t = text.trim();
    if (t.isEmpty) return;
    final temp = 'n${DateTime.now().microsecondsSinceEpoch}';
    comments.add(Comment(temp, p.id, 'me', t, 0, parent, replyToUser));
    p.commentCount++;
    notifyListeners();
    _send(() async {
      final real = await IntlyRepo.addComment(
        p.id,
        t,
        parentId: _real(parent),
        replyTo: replyToUser,
      );
      _idMap[temp] = real;
      final i = comments.indexWhere((c) => c.id == temp);
      if (i >= 0) {
        comments[i] = Comment(real, p.id, 'me', t, 0, _real(parent), replyToUser);
      }
    });
  }

  void toggleCommentLike(Comment c) => _toggleCommentLike(c.id);
  void toggleCommentLikeId(String id) => _toggleCommentLike(id);

  void _toggleCommentLike(String id) {
    final on = !likedComments.contains(id);
    if (on) {
      likedComments.add(id);
    } else {
      likedComments.remove(id);
    }
    _likeCounts[id] = (_likeCounts[id] ?? 0) + (on ? 1 : -1);
    notifyListeners();
    final realId = _real(id) ?? id;
    final isReel = _reelCommentIds.contains(id);
    _send(
      () => isReel
          ? IntlyRepo.setReelCommentLike(realId, on)
          : IntlyRepo.setCommentLike(realId, on),
      key: 'cl:$id',
      value: on,
    );
  }

  // Reels ----------------------------------------------------------------------

  void toggleReelLike(Reel r) {
    r.liked = !r.liked;
    notifyListeners();
    final on = r.liked;
    _send(() => _onReel(r.id, (rid) => IntlyRepo.setReelLike(rid, on)), key: 'rl:${r.id}', value: on);
  }

  void toggleReelSave(Reel r) {
    r.saved = !r.saved;
    notifyListeners();
    final on = r.saved;
    _send(() => _onReel(r.id, (rid) => IntlyRepo.setReelSave(rid, on)), key: 'rs:${r.id}', value: on);
  }

  void toggleReelRepost(Reel r) {
    r.reposted = !r.reposted;
    notifyListeners();
    final on = r.reposted;
    _send(() => _onReel(r.id, (rid) => IntlyRepo.setReelRepost(rid, on)), key: 'rr:${r.id}', value: on);
  }

  void shareReel(Reel r) {
    r.shares++;
    notifyListeners();
    _send(() => _onReel(r.id, IntlyRepo.shareReel));
  }

  void addReelComment(Reel r, String text, {String? parent, String? replyToUser}) {
    final t = text.trim();
    if (t.isEmpty) return;
    final temp = 'rc${DateTime.now().microsecondsSinceEpoch}';
    _reelCommentIds.add(temp);
    r.comments++;
    (reelComments[r.id] ??= []).insert(
      0,
      ReelComment(temp, r.id, 'me', t, 0, parent: parent, replyToUser: replyToUser),
    );
    notifyListeners();
    _send(() async {
      final rid = await _reelServerId(r.id);
      if (rid == null) throw StateError('Your reel is still uploading. Try again in a moment.');
      final real = await IntlyRepo.addReelComment(
        rid,
        t,
        parentId: _real(parent),
        replyTo: replyToUser,
      );
      _idMap[temp] = real;
      _reelCommentIds.add(real);
      final list = reelComments[r.id];
      final i = list?.indexWhere((c) => c.id == temp) ?? -1;
      if (list != null && i >= 0) {
        list[i] = ReelComment(real, r.id, 'me', t, 0,
            parent: _real(parent), replyToUser: replyToUser);
      }
    });
  }

  /// Uploads a new reel in the background and shows it at once.
  void addReel({
    required String video,
    String? audio,
    String audioName = 'Original audio',
    String caption = '',
    double speed = 1,
    int fx = 0,
    double touch = 0,
    String? poster,
    String? id, // kept for compatibility; the server assigns ids
  }) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final tmp = Reel(
      id: 'new$ts',
      userId: 'me',
      caption: caption,
      video: video,
      audio: audio,
      poster: poster,
      audioName: audioName,
      speed: speed,
      touch: touch,
      fx: fx,
    );
    reels.insert(0, tmp);
    notifyListeners();
    final ready = Completer<String>();
    _reelReady[tmp.id] = ready.future;
    ready.future.ignore();
    _sendUpload(
      () async {
        final folder = '$ts';
        final vp = await IntlyRepo.uploadReelFile(video, folder, 'video');
        final ap = audio == null ? null : await IntlyRepo.uploadReelFile(audio, folder, 'audio');
        final pp = poster == null ? null : await IntlyRepo.uploadReelFile(poster, folder, 'poster');
        final real = await IntlyRepo.insertReel(
          videoPath: vp,
          audioPath: ap,
          posterPath: pp,
          audioName: audioName,
          caption: caption,
          speed: speed,
          touch: touch,
          fx: fx,
        );
        _idMap[tmp.id] = real;
        ready.complete(real);
        await refresh();
      },
      onFail: () {
        if (!ready.isCompleted) ready.completeError(StateError('upload failed'));
        reels.remove(tmp);
        notifyListeners();
      },
    );
  }

  void deleteReel(Reel r) {
    reels.remove(r);
    notifyListeners();
    _send(() => _onReel(r.id, IntlyRepo.deleteReel));
  }

  /// Saves a reel as a draft. Only you can see it.
  void addDraft({
    required String video,
    String? audio,
    String audioName = 'Original audio',
    String caption = '',
    double speed = 1,
    int fx = 0,
    double touch = 0,
    String? poster,
  }) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final d = ReelDraft(
      id: 'newdraft$ts',
      video: video,
      audio: audio,
      poster: poster,
      audioName: audioName,
      caption: caption,
      speed: speed,
      touch: touch,
      fx: fx,
      ts: ts,
    );
    drafts.insert(0, d);
    notifyListeners();
    _sendUpload(
      () async {
        final folder = 'drafts/$ts';
        d.videoPath = await IntlyRepo.uploadReelFile(video, folder, 'video');
        d.audioPath = audio == null ? null : await IntlyRepo.uploadReelFile(audio, folder, 'audio');
        d.posterPath = poster == null ? null : await IntlyRepo.uploadReelFile(poster, folder, 'poster');
        d.id = await IntlyRepo.insertDraft(
          videoPath: d.videoPath!,
          audioPath: d.audioPath,
          posterPath: d.posterPath,
          audioName: audioName,
          caption: caption,
          speed: speed,
          touch: touch,
          fx: fx,
        );
        await refresh();
      },
      onFail: () {
        drafts.remove(d);
        notifyListeners();
      },
    );
  }

  void deleteDraft(ReelDraft d) {
    drafts.removeWhere((x) => x.id == d.id);
    notifyListeners();
    _send(() => IntlyRepo.deleteDraft(d.id));
  }

  /// Turns a draft into a posted reel. The uploaded files are reused, not copied.
  void postDraft(ReelDraft d) {
    drafts.removeWhere((x) => x.id == d.id);
    reels.insert(0, d.toReel());
    notifyListeners();
    _send(() async {
      final vp = d.videoPath;
      if (vp == null) return;
      await IntlyRepo.insertReel(
        videoPath: vp,
        audioPath: d.audioPath,
        posterPath: d.posterPath,
        audioName: d.audioName,
        caption: d.caption,
        speed: d.speed,
        touch: d.touch,
        fx: d.fx,
      );
      await IntlyRepo.deleteDraft(d.id);
      await refresh();
    });
  }

  /// Downloads a reel's video when it comes near the screen (not all at once).
  void ensureReel(Reel r) {
    final path = r.videoPath;
    if (r.video != null || path == null) return;
    final key = 'v:$path';
    if (!_downloading.add(key)) return;
    unawaited(MediaCache.fetch(IntlyRepo.reelBucket, path).then((_) {
      _scheduleReapply();
    }).catchError((Object e) {
      debugPrint('Video download failed: $e');
    }).whenComplete(() {
      _downloading.remove(key);
    }));
  }

  // Follows and notifications ----------------------------------------------------

  /// Follow state of [id] for the screens: 'following', 'requested' (a private
  /// account is waiting for approval) or 'none'.
  String followStatus(String id) {
    if (following.contains(id)) return 'following';
    if (_pendingOut.contains(id)) return 'requested';
    return 'none';
  }

  /// Follow or unfollow [id]. The button changes at once; the server confirms
  /// it in the background, and a refusal puts the button back.
  void toggleFollow(String id) {
    final turningOn = followStatus(id) == 'none';
    if (turningOn) {
      // A private account shows "Requested" straight away, not "Following".
      if (users[id]?.isPrivate == true) {
        _pendingOut.add(id);
      } else {
        following.add(id);
      }
    } else {
      following.remove(id);
      _pendingOut.remove(id);
    }
    notifyListeners();
    _send(() async {
      if (turningOn) {
        final status = await IntlyRepo.follow(id);
        following.remove(id);
        _pendingOut.remove(id);
        if (status == 'pending') {
          _pendingOut.add(id);
        } else {
          following.add(id);
        }
        notifyListeners();
      } else {
        await IntlyRepo.unfollow(id);
      }
    }, key: 'f:$id', value: turningOn);
  }

  void confirmRequest(String id) {
    incoming.remove(id);
    (_followersOf['me'] ??= []).add(id);
    notifyListeners();
    _send(() => IntlyRepo.acceptFollower(id));
  }

  void declineRequest(String id) {
    incoming.remove(id);
    notifyListeners();
    _send(() => IntlyRepo.removeFollower(id));
  }

  void removeFollower(String id) {
    (_followersOf['me'] ??= []).remove(id);
    notifyListeners();
    _send(() => IntlyRepo.removeFollower(id));
  }

  void markRead(Notif n) {
    if (n.read) return;
    n.read = true;
    notifyListeners();
    _send(() => IntlyRepo.markNotificationRead(n.id));
  }

  void markAllRead() {
    for (final n in notifs) {
      n.read = true;
    }
    notifyListeners();
    _send(IntlyRepo.markAllNotificationsRead);
  }

  // ---------------------------------------------------------------------------
  // Reads: turn one server snapshot into the objects the screens use.
  // ---------------------------------------------------------------------------

  /// Reads one pending change, falling back to what the server says.
  bool _pendingOr(String key, bool serverValue) => _ov[key]?.value ?? serverValue;

  /// Applies a comment or reply like count, with any pending change on top.
  void _commentLike(String id, int total, Set<String> serverLiked) {
    final server = serverLiked.contains(id);
    final liked = _pendingOr('cl:$id', server);
    _likeCounts[id] = (total - (server ? 1 : 0)) + (liked ? 1 : 0);
    if (liked) likedComments.add(id);
  }

  void _apply(RemoteSnapshot s) {
    final uid = s.uid;
    String local(String id) => id == uid ? 'me' : id;

    // Profiles
    users.clear();
    for (final p in s.rows('profiles')) {
      final id = p['id'] as String;
      final avatarPath = p['avatar_path'] as String?;
      final avatar = avatarPath == null ? null : MediaCache.peek(IntlyRepo.avatarBucket, avatarPath);
      if (id == uid) {
        me.handle = (p['username'] as String?) ?? me.handle;
        me.name = (p['display_name'] as String?) ?? 'You';
        me.bio = (p['bio'] as String?) ?? '';
        me.avatar = avatar;
        me.isPrivate = p['is_private'] == true;
        me.nameChangedAt = _ts(p['name_changed_at']);
        me.usernameChangedAt = _ts(p['username_changed_at']);
        _avatarPath = avatarPath;
        flags['private'] = p['is_private'] == true;
        continue;
      }
      users[id] = User(
        id,
        (p['display_name'] as String?) ?? 'Intly user',
        (p['username'] as String?) ?? 'user',
        (p['bio'] as String?) ?? '',
        (p['accent_hue'] as int?) ?? 262,
        0,
        0,
      )
        ..avatar = avatar
        ..isPrivate = p['is_private'] == true;
    }
    users['me'] = me;

    // Settings
    final settings = s.rows('settings');
    if (settings.isNotEmpty) {
      final r = settings.first;
      mode.value = (r['theme'] as String?) ?? 'system';
      flags['push'] = r['push_notifications'] != false;
      flags['likes'] = r['notify_likes'] != false;
      flags['follows'] = r['notify_follows'] != false;
      flags['activity'] = r['show_activity'] != false;
    }

    // Follows: accepted edges build the followers and following lists;
    // pending edges are follow requests (sent by you or to you).
    following.clear();
    _pendingOut.clear();
    incoming.clear();
    _followersOf.clear();
    _followingOf.clear();
    for (final f in s.rows('follows')) {
      final from = f['follower_id'] as String;
      final to = f['following_id'] as String;
      final accepted = f['status'] == 'accepted';
      if (accepted) {
        (_followersOf[local(to)] ??= []).add(local(from));
        (_followingOf[local(from)] ??= []).add(local(to));
      }
      if (from == uid) {
        if (accepted) {
          following.add(to);
        } else {
          _pendingOut.add(to);
        }
      }
      if (to == uid && !accepted) incoming.add(from);
    }
    for (final e in _ov.entries) {
      if (!e.key.startsWith('f:')) continue;
      final id = e.key.substring(2);
      if (e.value.value) {
        if (!following.contains(id) && !_pendingOut.contains(id)) {
          if (users[id]?.isPrivate == true) {
            _pendingOut.add(id);
          } else {
            following.add(id);
          }
        }
      } else {
        following.remove(id);
        _pendingOut.remove(id);
      }
    }

    // Posts
    final postLiked = s.ids('postLiked');
    final postSaved = s.ids('postSaved');
    posts.clear();
    for (final r in s.rows('posts')) {
      final id = r['id'] as String;
      final serverLiked = postLiked.contains(id);
      final p = Post(
        id,
        local(r['user_id'] as String),
        (r['body'] as String?) ?? '',
        _ageMinutes(r['created_at'] as String),
        -1,
        _minus(r['like_count'], serverLiked),
        (r['comment_count'] as int?) ?? 0,
        (r['share_count'] as int?) ?? 0,
      );
      p.liked = _pendingOr('pl:$id', serverLiked);
      p.saved = _pendingOr('ps:$id', postSaved.contains(id));
      p.bg = (r['background_index'] as int?) ?? -1;
      p.font = (r['font_index'] as int?) ?? 0;
      p.tcolor = (r['text_color_index'] as int?) ?? -1;

      final media = (r['post_media'] as List? ?? const []).cast<Map<String, dynamic>>().toList()
        ..sort((a, b) => (a['sort_order'] as int).compareTo(b['sort_order'] as int));
      if (media.isNotEmpty) {
        final m = media.first;
        final path = m['storage_path'] as String;
        if (m['media_type'] == 'video') {
          p.video = MediaCache.peek(IntlyRepo.postBucket, path);
          final poster = m['poster_path'] as String?;
          p.image = poster == null ? null : MediaCache.peek(IntlyRepo.postBucket, poster);
        } else {
          p.image = MediaCache.peek(IntlyRepo.postBucket, path);
        }
      }

      final stickers = (r['post_stickers'] as List? ?? const []).cast<Map<String, dynamic>>().toList()
        ..sort((a, b) => (a['sort_order'] as int).compareTo(b['sort_order'] as int));
      p.stickers = [
        for (final e in stickers)
          Sticker(
            e['emoji'] as String,
            (e['position_x'] as num).toDouble(),
            (e['position_y'] as num).toDouble(),
            (e['scale'] as num).toDouble(),
          ),
      ];
      posts.add(p);
    }
    posts.sort((a, b) => a.minutes.compareTo(b.minutes));

    // Comments and likes
    comments.clear();
    _likeCounts.clear();
    _reelCommentIds.clear();
    likedComments.clear();
    final commentLiked = s.ids('commentLiked');
    final reelCommentLiked = s.ids('reelCommentLiked');
    for (final c in s.rows('comments')) {
      final id = c['id'] as String;
      comments.add(Comment(
        id,
        c['post_id'] as String,
        local(c['user_id'] as String),
        c['body'] as String,
        _ageMinutes(c['created_at'] as String),
        c['parent_id'] as String?,
        c['reply_to_user_id'] == null ? null : local(c['reply_to_user_id'] as String),
      ));
      _commentLike(id, (c['like_count'] as int?) ?? 0, commentLiked);
    }
    reelComments.clear();
    for (final c in s.rows('reelComments')) {
      final id = c['id'] as String;
      final reelId = c['reel_id'] as String;
      (reelComments[reelId] ??= []).add(ReelComment(
        id,
        reelId,
        local(c['user_id'] as String),
        c['body'] as String,
        _ageMinutes(c['created_at'] as String),
        parent: c['parent_id'] as String?,
        replyToUser: c['reply_to_user_id'] == null ? null : local(c['reply_to_user_id'] as String),
      ));
      _reelCommentIds.add(id);
      _commentLike(id, (c['like_count'] as int?) ?? 0, reelCommentLiked);
    }

    // Notifications
    notifs.clear();
    for (final n in s.rows('notifs')) {
      notifs.add(Notif(
        id: n['id'] as String,
        type: n['notification_type'] as String,
        userId: n['actor_id'] == null ? '' : local(n['actor_id'] as String),
        text: (n['message'] as String?) ?? '',
        minutes: _ageMinutes(n['created_at'] as String),
        read: n['is_read'] == true,
        postId: n['post_id'] as String?,
        commentId: n['comment_id'] as String?,
      ));
    }

    // Reels
    final rLiked = s.ids('reelLiked');
    final rSaved = s.ids('reelSaved');
    final rReposted = s.ids('reelReposted');
    reels.clear();
    for (final r in s.rows('reels')) {
      final id = r['id'] as String;
      final serverLiked = rLiked.contains(id);
      final serverSaved = rSaved.contains(id);
      final serverReposted = rReposted.contains(id);
      final videoPath = r['video_path'] as String;
      final audioPath = r['audio_path'] as String?;
      // The grid shows the thumbnail; older rows fall back to the poster frame.
      final posterPath = (r['thumbnail_path'] as String?) ?? (r['poster_path'] as String?);
      final reel = Reel(
        id: id,
        userId: local(r['user_id'] as String),
        caption: (r['caption'] as String?) ?? '',
        video: MediaCache.peek(IntlyRepo.reelBucket, videoPath),
        audio: audioPath == null ? null : MediaCache.peek(IntlyRepo.reelBucket, audioPath),
        poster: posterPath == null ? null : MediaCache.peek(IntlyRepo.reelBucket, posterPath),
        audioName: (r['audio_name'] as String?) ?? 'Original audio',
        speed: (r['playback_speed'] as num).toDouble(),
        touch: (r['touch_strength'] as num).toDouble(),
        fx: (r['effect_index'] as int?) ?? 0,
        hue: (r['hue'] as int?) ?? 0,
        icon: (r['icon_index'] as int?) ?? 0,
        minutes: _ageMinutes(r['created_at'] as String),
        likes: _minus(r['like_count'], serverLiked),
        comments: (r['comment_count'] as int?) ?? 0,
        reposts: _minus(r['repost_count'], serverReposted),
        shares: (r['share_count'] as int?) ?? 0,
        saves: _minus(r['save_count'], serverSaved),
      )
        ..liked = _pendingOr('rl:$id', serverLiked)
        ..saved = _pendingOr('rs:$id', serverSaved)
        ..reposted = _pendingOr('rr:$id', serverReposted)
        ..videoPath = videoPath
        ..audioPath = audioPath
        ..posterPath = posterPath;
      reels.add(reel);
    }

    // Drafts (shown once their video is on this phone)
    drafts.clear();
    for (final d in s.rows('drafts')) {
      final videoPath = d['video_path'] as String;
      final localVideo = MediaCache.peek(IntlyRepo.reelBucket, videoPath);
      if (localVideo == null) continue;
      final audioPath = d['audio_path'] as String?;
      final posterPath = d['poster_path'] as String?;
      drafts.add(ReelDraft(
        id: d['id'] as String,
        video: localVideo,
        caption: (d['caption'] as String?) ?? '',
        audioName: (d['audio_name'] as String?) ?? 'Original audio',
        speed: (d['playback_speed'] as num).toDouble(),
        touch: (d['touch_strength'] as num).toDouble(),
        fx: (d['effect_index'] as int?) ?? 0,
        ts: DateTime.parse(d['created_at'] as String).millisecondsSinceEpoch,
        audio: audioPath == null ? null : MediaCache.peek(IntlyRepo.reelBucket, audioPath),
        poster: posterPath == null ? null : MediaCache.peek(IntlyRepo.reelBucket, posterPath),
        videoPath: videoPath,
        audioPath: audioPath,
        posterPath: posterPath,
      ));
    }
  }

  /// Downloads in the background: photos and posters first, the first few reel
  /// videos next, and the rest when they are scrolled to (see [ensureReel]).
  Future<void> _downloadMissing(RemoteSnapshot s) async {
    final light = <(String, String)>[];
    final heavy = <(String, String)>[];
    void want(String bucket, String? path, {bool video = false}) {
      if (path == null || MediaCache.peek(bucket, path) != null) return;
      (video ? heavy : light).add((bucket, path));
    }

    for (final p in s.rows('posts')) {
      for (final m in (p['post_media'] as List? ?? const []).cast<Map<String, dynamic>>()) {
        want(IntlyRepo.postBucket, m['storage_path'] as String, video: m['media_type'] == 'video');
        want(IntlyRepo.postBucket, m['poster_path'] as String?);
      }
    }
    for (final p in s.rows('profiles')) {
      want(IntlyRepo.avatarBucket, p['avatar_path'] as String?);
    }
    final reelRows = s.rows('reels');
    for (var i = 0; i < reelRows.length; i++) {
      final r = reelRows[i];
      want(IntlyRepo.reelBucket, (r['thumbnail_path'] ?? r['poster_path']) as String?);
      want(IntlyRepo.reelBucket, r['audio_path'] as String?);
      if (i < 3) want(IntlyRepo.reelBucket, r['video_path'] as String, video: true);
    }
    for (final d in s.rows('drafts')) {
      want(IntlyRepo.reelBucket, d['poster_path'] as String?);
      want(IntlyRepo.reelBucket, d['audio_path'] as String?);
      want(IntlyRepo.reelBucket, d['video_path'] as String, video: true);
    }

    for (final job in [...light, ...heavy]) {
      if (!IntlyRepo.signedIn) return;
      final key = '${job.$1}/${job.$2}';
      if (!_downloading.add(key)) continue;
      try {
        await MediaCache.fetch(job.$1, job.$2);
        _scheduleReapply();
      } catch (e) {
        debugPrint('Media download failed: $e');
      } finally {
        _downloading.remove(key);
      }
    }
  }

  /// Rebuilds the screens from the last snapshot, at most a few times a second
  /// while many files arrive (rebuilding for every file would be slow).
  void _scheduleReapply() {
    _reapplyTimer ??= Timer(const Duration(milliseconds: 500), () {
      _reapplyTimer = null;
      final s = _snap;
      if (s == null) return;
      _apply(s);
      notifyListeners();
    });
  }
}
