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

int _ageMinutes(String iso) {
  final m = DateTime.now().toUtc().difference(DateTime.parse(iso).toUtc()).inMinutes;
  return m < 0 ? 0 : m;
}

class User {
  final String id;
  String name, handle, bio;
  int hue, followers, following;
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
  final String? video; // local file; null until the video is on this phone
  final String? audio; // optional sound track played with the video
  final String? poster; // cover image for profile grids
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

/// The app's state. Screens read it synchronously and call its methods. Each
/// change shows at once, then goes to Supabase in order. If the server
/// refuses a change, the app re-reads the server so the screen is correct again.
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

  /// Set when the last server call failed; cleared when one succeeds.
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
  RemoteSnapshot? _snap;
  Future<void>? _inFlight;
  Future<void> _chain = Future.value();
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

  /// Called once at launch by AppBootstrap.
  Future<void> start() async {
    Native.init();
    await MediaCache.init();
    await _loadCache();
  }

  /// Called when someone signs in: show their cache, then fetch fresh data.
  Future<void> onSignedIn() async {
    await _loadCache();
    await refresh();
  }

  /// Called when the user signs out: clear what this phone keeps for them.
  Future<void> onSignedOut() async {
    final uid = _snap?.uid;
    _snap = null;
    _resetMemory();
    notifyListeners();
    if (uid != null) await LocalCache.clear(uid);
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

  Future<void> _loadCache() async {
    final uid = IntlyRepo.currentUid;
    if (uid == null) return;
    final data = await LocalCache.load(uid);
    if (data == null) return;
    _snap = RemoteSnapshot(data);
    _apply(_snap!);
    notifyListeners();
  }

  /// Fetches the latest data from Supabase. Overlapping calls share one request.
  Future<void> refresh() => _inFlight ??= _doRefresh().whenComplete(() => _inFlight = null);

  Future<void> _doRefresh() async {
    if (!IntlyRepo.signedIn) return;
    try {
      final snap = await IntlyRepo.fetchSnapshot();
      _snap = snap;
      _apply(snap);
      syncError.value = null;
      notifyListeners();
      unawaited(LocalCache.save(snap.uid, snap.data));
      unawaited(_downloadMissing(snap));
    } catch (e) {
      debugPrint('Intly refresh failed: $e');
      syncError.value = IntlyRepo.describe(e);
    }
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
    flags
      ..clear()
      ..addAll(_defaults);
    mode.value = 'system';
    me.name = 'You';
    me.handle = 'you';
    me.bio = 'Hello Intly 👋';
  }

  // ---------------------------------------------------------------------------
  // Writes: every change goes through _send, one at a time, in order.
  // ---------------------------------------------------------------------------

  Future<void> _send(Future<void> Function() op) {
    _chain = _chain.then((_) => op()).catchError((Object e) async {
      debugPrint('Intly write failed: $e');
      syncError.value = IntlyRepo.describe(e);
      await refresh();
    });
    return _chain;
  }

  String? _real(String? id) => id == null ? null : (_idMap[id] ?? id);

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

  void updateProfile(String name, String bio) {
    me.name = name.trim().isEmpty ? 'You' : name.trim();
    me.bio = bio.trim();
    notifyListeners();
    _send(() => IntlyRepo.updateProfile(name: me.name, bio: me.bio));
  }

  // Posts -----------------------------------------------------------------------

  void toggleLike(Post p) {
    p.liked = !p.liked;
    notifyListeners();
    final on = p.liked;
    _send(() => IntlyRepo.setPostLike(p.id, on));
  }

  void toggleSave(Post p) {
    p.saved = !p.saved;
    notifyListeners();
    final on = p.saved;
    _send(() => IntlyRepo.setPostSave(p.id, on));
  }

  void reportPost(Post p) {
    reported.add(p.id);
    notifyListeners();
    _send(() => IntlyRepo.reportPost(p.id));
  }

  /// Creates a new post, or updates [edit] when editing. Local media files are
  /// uploaded to Storage; the screen gets the post back on the next refresh.
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
    _send(() async {
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
    });
  }

  void deletePost(Post p) {
    posts.remove(p);
    comments.removeWhere((c) => c.postId == p.id);
    notifyListeners();
    _send(() => IntlyRepo.deletePost(p.id));
  }

  // Comments ----------------------------------------------------------------------

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
    _send(() => isReel
        ? IntlyRepo.setReelCommentLike(realId, on)
        : IntlyRepo.setCommentLike(realId, on));
  }

  // Reels -------------------------------------------------------------------------

  void toggleReelLike(Reel r) {
    r.liked = !r.liked;
    notifyListeners();
    final on = r.liked;
    _send(() => IntlyRepo.setReelLike(r.id, on));
  }

  void toggleReelSave(Reel r) {
    r.saved = !r.saved;
    notifyListeners();
    final on = r.saved;
    _send(() => IntlyRepo.setReelSave(r.id, on));
  }

  void toggleReelRepost(Reel r) {
    r.reposted = !r.reposted;
    notifyListeners();
    final on = r.reposted;
    _send(() => IntlyRepo.setReelRepost(r.id, on));
  }

  void shareReel(Reel r) {
    r.shares++;
    notifyListeners();
    _send(() => IntlyRepo.shareReel(r.id));
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
      final real = await IntlyRepo.addReelComment(
        r.id,
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

  /// Uploads a new reel and its files, then shows it in the feed.
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
    reels.insert(
      0,
      Reel(
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
      ),
    );
    notifyListeners();
    _send(() async {
      final folder = '$ts';
      final vp = await IntlyRepo.uploadReelFile(video, folder, 'video');
      final ap = audio == null ? null : await IntlyRepo.uploadReelFile(audio, folder, 'audio');
      final pp = poster == null ? null : await IntlyRepo.uploadReelFile(poster, folder, 'poster');
      await IntlyRepo.insertReel(
        videoPath: vp,
        audioPath: ap,
        posterPath: pp,
        audioName: audioName,
        caption: caption,
        speed: speed,
        touch: touch,
        fx: fx,
      );
      await refresh();
    });
  }

  void deleteReel(Reel r) {
    reels.remove(r);
    notifyListeners();
    _send(() => IntlyRepo.deleteReel(r.id));
  }

  /// Saves a reel as a draft. Only you can see it. The file is uploaded to your
  /// private folder in Storage.
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
    _send(() async {
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
    });
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

  // Follows and notifications -----------------------------------------------------

  void toggleFollow(String id) {
    if (following.contains(id) || _pendingOut.contains(id)) {
      following.remove(id);
      _pendingOut.remove(id);
      notifyListeners();
      _send(() => IntlyRepo.unfollow(id));
    } else {
      following.add(id);
      notifyListeners();
      _send(() async {
        final status = await IntlyRepo.follow(id);
        if (status == 'pending') {
          following.remove(id);
          _pendingOut.add(id);
          notifyListeners();
        }
      });
    }
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

  void _apply(RemoteSnapshot s) {
    final uid = s.uid;
    String local(String id) => id == uid ? 'me' : id;

    // Profiles
    users.clear();
    for (final p in s.rows('profiles')) {
      final id = p['id'] as String;
      if (id == uid) {
        me.handle = (p['username'] as String?) ?? me.handle;
        me.name = (p['display_name'] as String?) ?? 'You';
        me.bio = (p['bio'] as String?) ?? '';
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
      );
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

    // Posts
    final postLiked = s.ids('postLiked');
    final postSaved = s.ids('postSaved');
    posts.clear();
    for (final r in s.rows('posts')) {
      final id = r['id'] as String;
      final liked = postLiked.contains(id);
      final p = Post(
        id,
        local(r['user_id'] as String),
        (r['body'] as String?) ?? '',
        _ageMinutes(r['created_at'] as String),
        -1,
        _minus(r['like_count'], liked),
        (r['comment_count'] as int?) ?? 0,
        (r['share_count'] as int?) ?? 0,
      );
      p.liked = liked;
      p.saved = postSaved.contains(id);
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
      _likeCounts[id] = (c['like_count'] as int?) ?? 0;
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
      _likeCounts[id] = (c['like_count'] as int?) ?? 0;
      _reelCommentIds.add(id);
    }
    likedComments
      ..clear()
      ..addAll(s.ids('commentLiked'))
      ..addAll(s.ids('reelCommentLiked'));

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
      final liked = rLiked.contains(id);
      final saved = rSaved.contains(id);
      final reposted = rReposted.contains(id);
      final audioPath = r['audio_path'] as String?;
      final posterPath = r['poster_path'] as String?;
      final reel = Reel(
        id: id,
        userId: local(r['user_id'] as String),
        caption: (r['caption'] as String?) ?? '',
        video: MediaCache.peek(IntlyRepo.reelBucket, r['video_path'] as String),
        audio: audioPath == null ? null : MediaCache.peek(IntlyRepo.reelBucket, audioPath),
        poster: posterPath == null ? null : MediaCache.peek(IntlyRepo.reelBucket, posterPath),
        audioName: (r['audio_name'] as String?) ?? 'Original audio',
        speed: (r['playback_speed'] as num).toDouble(),
        touch: (r['touch_strength'] as num).toDouble(),
        fx: (r['effect_index'] as int?) ?? 0,
        hue: (r['hue'] as int?) ?? 0,
        icon: (r['icon_index'] as int?) ?? 0,
        minutes: _ageMinutes(r['created_at'] as String),
        likes: _minus(r['like_count'], liked),
        comments: (r['comment_count'] as int?) ?? 0,
        reposts: _minus(r['repost_count'], reposted),
        shares: (r['share_count'] as int?) ?? 0,
        saves: _minus(r['save_count'], saved),
      )
        ..liked = liked
        ..saved = saved
        ..reposted = reposted;
      reels.add(reel);
    }

    // Drafts (shown once their video is on this phone)
    drafts.clear();
    for (final d in s.rows('drafts')) {
      final videoPath = d['video_path'] as String;
      final local0 = MediaCache.peek(IntlyRepo.reelBucket, videoPath);
      if (local0 == null) continue;
      final audioPath = d['audio_path'] as String?;
      final posterPath = d['poster_path'] as String?;
      drafts.add(ReelDraft(
        id: d['id'] as String,
        video: local0,
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

  /// Downloads photos first, then videos, one at a time, into the media cache.
  /// Each finished file refreshes the screens.
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
    for (final r in s.rows('reels')) {
      want(IntlyRepo.reelBucket, r['poster_path'] as String?);
      want(IntlyRepo.reelBucket, r['audio_path'] as String?);
      want(IntlyRepo.reelBucket, r['video_path'] as String, video: true);
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
        _reapply();
      } catch (e) {
        debugPrint('Media download failed: $e');
      } finally {
        _downloading.remove(key);
      }
    }
  }

  void _reapply() {
    final s = _snap;
    if (s == null) return;
    _apply(s);
    notifyListeners();
  }
}
