
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'native.dart';
import 'styles.dart';

class User {
  final String id;
  String name, handle, bio;
  final int hue, followers, following;
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
  String? image; // photo, or the poster frame when [video] is set
  String? video; // local video file
  List<Sticker> stickers = [];
  Post(this.id, this.userId, this.text, this.minutes, this.media, this.likes,
      this.commentCount, this.shares);
  int get likeCount => likes + (liked ? 1 : 0);
}

class Comment {
  final String id, postId, userId, text;
  final int minutes;
  final String? parent; // id of top-level comment when this is a reply
  final String? replyToUser; // set when replying to a reply
  Comment(this.id, this.postId, this.userId, this.text, this.minutes, this.parent,
      [this.replyToUser]);
}

class Notif {
  final String type, userId, text;
  final int minutes;
  final String? postId; // post this notification is about
  final String? commentId; // comment to highlight when the post opens
  bool read;
  Notif(this.type, this.userId, this.text, this.minutes, this.read,
      {this.postId, this.commentId});
}

class Reel {
  final String id, userId, audioName, caption;
  final String? video; // local file; null = demo reel drawn as animated art
  final String? audio; // optional sound track played with the video
  final String? poster; // cover image (when known) for profile grids
  final double speed, touch; // playback speed, touch-up strength 0..1
  final int fx, hue, icon, minutes, likes, reposts, saves;
  int comments, shares;
  bool liked = false, saved = false, reposted = false;
  Reel({
    required this.id, required this.userId, required this.caption, this.video, this.audio, this.poster,
    this.audioName = 'Original audio', this.speed = 1, this.touch = 0, this.fx = 0,
    this.hue = 0, this.icon = 0, this.minutes = 0, this.likes = 0, this.comments = 0,
    this.reposts = 0, this.shares = 0, this.saves = 0,
  });
  int get likeCount => likes + (liked ? 1 : 0);
  int get repostCount => reposts + (reposted ? 1 : 0);
  int get saveCount => saves + (saved ? 1 : 0);
}

/// A reel saved to drafts: only its author can see it, and it is not in any feed.
class ReelDraft {
  final String id, video, audioName, caption;
  final String? audio, poster;
  final double speed, touch;
  final int fx, ts;
  const ReelDraft({
    required this.id, required this.video, required this.caption, required this.audioName,
    required this.speed, required this.touch, required this.fx, required this.ts,
    this.audio, this.poster,
  });
  Reel toReel() => Reel(
        id: id, userId: 'me', caption: caption, video: video, audio: audio, poster: poster,
        audioName: audioName, speed: speed, touch: touch, fx: fx,
      );
  Map<String, dynamic> toJson() => {
        'id': id, 'video': video, 'audio': audio, 'poster': poster, 'audioName': audioName,
        'caption': caption, 'speed': speed, 'touch': touch, 'fx': fx, 'ts': ts,
      };
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

class AppState extends ChangeNotifier {
  /// 'system' (default, follows the phone), 'light' or 'dark'.
  final mode = ValueNotifier<String>('system');
  int tab = 0;
  final Map<String, User> users = {};
  final List<Post> posts = [];
  final List<Comment> comments = [];
  final List<Notif> notifs = [];
  final Set<String> following = {};
  final Set<String> reported = {};
  final Set<String> likedComments = {};
  // social graph (seed) + follow requests
  final Map<String, List<String>> _follows = {}; // user -> users they follow
  final Map<String, List<String>> _followers = {}; // user -> users following them
  final List<String> _meFollowers = [];
  final List<String> incoming = []; // people who newly followed / requested to follow you
  final Set<String> confirmed = {}, declined = {};
  // reels
  final List<Reel> reels = [];
  final Map<String, List<ReelComment>> reelComments = {};
  List<dynamic> _myReels = [];
  List<dynamic> _myDrafts = [];
  final List<ReelDraft> drafts = []; // newest first, private to me
  List<dynamic> _myReelComments = [];
  final Map<String, bool> flags = {};
  static const _defaults = {
    'push': true, 'likes': true, 'follows': true, 'private': false, 'activity': true,
  };
  late User me;
  SharedPreferences? _p;
  Timer? _saveTimer;
  List<dynamic> _mine = [];

  User user(String id) => users[id] ?? me;
  int get unread => notifs.where((n) => !n.read).length;
  bool get isPrivate => flags['private'] ?? false;

  /// Everyone who follows [id]. For you: confirmed requests count, and when the
  /// account is public new followers are added automatically.
  List<String> followersList(String id) {
    if (id == 'me') {
      final out = <String>{..._meFollowers, ...confirmed};
      if (!isPrivate) out.addAll(incoming);
      out.removeAll(declined);
      return out.toList();
    }
    return [...(_followers[id] ?? const <String>[]), if (following.contains(id)) 'me'];
  }

  List<String> followingList(String id) {
    if (id == 'me') return following.toList();
    return [...(_follows[id] ?? const <String>[]), if (followersList('me').contains(id)) 'me'];
  }

  /// Pending follow requests (only exist while the account is private).
  List<String> get requests => !isPrivate
      ? const []
      : incoming
          .where((x) => !confirmed.contains(x) && !declined.contains(x) && !_meFollowers.contains(x))
          .toList();

  int followersOf(User u) => followersList(u.id).length;
  int followingOf(User u) => followingList(u.id).length;

  void confirmRequest(String id) {
    declined.remove(id);
    confirmed.add(id);
    _commit();
  }

  void declineRequest(String id) {
    confirmed.remove(id);
    declined.add(id);
    _commit();
  }

  void removeFollower(String id) => declineRequest(id);

  String notifText(Notif n) =>
      n.type == 'follow' && requests.contains(n.userId) ? 'requested to follow you' : n.text;
  List<Post> postsOf(String id) => posts.where((p) => p.userId == id).toList();
  /// Heart count of a comment/reply (stable demo base + your own heart).
  /// Stable demo heart count for a seeded comment id.
  int _baseHearts(String id) {
    var h = 7;
    for (final u in id.codeUnits) {
      h = (h * 31 + u) & 0x7fffffff;
    }
    return h % 41;
  }

  int commentLikes(Comment c) {
    final mine = likedComments.contains(c.id) ? 1 : 0;
    if (c.id.startsWith('n')) return mine; // comments written in the app start at 0
    return _baseHearts(c.id) + mine;
  }

  /// Heart count of a reel comment (your own comments start at 0).
  int reelCommentLikes(ReelComment c) =>
      (c.userId == 'me' ? 0 : _baseHearts(c.id)) + (likedComments.contains(c.id) ? 1 : 0);

  void toggleCommentLikeId(String id) {
    if (!likedComments.remove(id)) likedComments.add(id);
    _commit();
  }

  void toggleCommentLike(Comment c) {
    if (!likedComments.remove(c.id)) likedComments.add(c.id);
    _commit();
  }

  Post? postById(String? id) {
    if (id == null) return null;
    for (final p in posts) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<void> load() async {
    Native.init();
    final raw = jsonDecode(await rootBundle.loadString('assets/seed.json')) as Map<String, dynamic>;
    for (final u in raw['users']) {
      users[u['id']] = User(u['id'], u['name'], u['handle'], u['bio'], u['hue'],
          u['followers'], u['following']);
    }
    me = User('me', 'You', 'you', 'Hello Intly 👋', 262, 128, 0);
    users['me'] = me;
    for (final p in raw['posts']) {
      posts.add(Post(p['id'], p['user'], p['text'], p['minutes'], p['media'],
          p['likes'], p['comments'], p['shares']));
    }
    for (final c in raw['comments']) {
      comments.add(Comment(c['id'], c['post'], c['user'], c['text'], c['minutes'], c['parent']));
    }
    int i = 0;
    for (final n in raw['notifs']) {
      notifs.add(Notif(n['type'], n['user'], n['text'], n['minutes'], i++ >= 4,
          postId: n['post'] as String?, commentId: n['comment'] as String?));
    }
    ((raw['follows'] as Map<String, dynamic>?) ?? const {}).forEach((k, v) {
      final l = (v as List).cast<String>();
      _follows[k] = l;
      for (final t in l) {
        (_followers[t] ??= []).add(k);
      }
    });
    _meFollowers.addAll(((raw['meFollowers'] as List?) ?? const []).cast<String>());
    incoming.addAll(((raw['incoming'] as List?) ?? const []).cast<String>());
    for (final r in (raw['reels'] as List? ?? const [])) {
      reels.add(Reel(
        id: r['id'], userId: r['user'], caption: r['caption'], audioName: r['audio'],
        hue: r['hue'], icon: r['icon'], minutes: r['minutes'], likes: r['likes'],
        comments: r['comments'], reposts: r['reposts'], shares: r['shares'], saves: r['saves'],
      ));
    }
    var rcN = 0;
    for (final c in (raw['reelComments'] as List? ?? const [])) {
      (reelComments[c['reel']] ??= []).add(ReelComment(
        (c['id'] as String?) ?? 'rs${rcN++}', c['reel'], c['user'], c['text'], c['minutes'],
        parent: c['parent'] as String?, replyToUser: c['replyTo'] as String?,
      ));
    }
    _p = await SharedPreferences.getInstance();
    final sp = _p!;
    mode.value = sp.getString('theme') ?? 'system';
    me.name = sp.getString('name') ?? me.name;
    me.bio = sp.getString('bio') ?? me.bio;
    following.addAll(sp.getStringList('following') ?? const []);
    reported.addAll(sp.getStringList('reported') ?? const []);
    likedComments.addAll(sp.getStringList('cliked') ?? const []);
    confirmed.addAll(sp.getStringList('confirmed') ?? const []);
    declined.addAll(sp.getStringList('declined') ?? const []);
    final liked = (sp.getStringList('liked') ?? const []).toSet();
    final saved = (sp.getStringList('saved') ?? const []).toSet();
    _mine = jsonDecode(sp.getString('mine') ?? '[]') as List<dynamic>;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final m in _mine) {
      final p = Post(m['id'], 'me', m['text'], ((now - (m['ts'] as int)) / 60000).floor(), -1, 0, 0, 0);
      p.bg = (m['bg'] ?? -1) as int;
      p.font = (m['font'] ?? 0) as int;
      p.tcolor = (m['tc'] ?? -1) as int;
      final img = m['img'] as String?;
      p.image = (img != null && File(img).existsSync()) ? img : null;
      final vid = m['vid'] as String?;
      p.video = (vid != null && File(vid).existsSync()) ? vid : null;
      p.stickers = ((m['st'] ?? []) as List).map((e) => Sticker.fromJson(e as List)).toList();
      posts.add(p);
    }
    for (final p in posts) {
      p.liked = liked.contains(p.id);
      p.saved = saved.contains(p.id);
    }
    // my own reels (recorded in the app) + my reel comments
    _myReels = jsonDecode(sp.getString('myreels') ?? '[]') as List<dynamic>;
    final mineReels = <Reel>[];
    for (final m in _myReels) {
      final v = m['video'] as String?;
      if (v == null || !File(v).existsSync()) continue;
      final a = m['audio'] as String?;
      final po = m['poster'] as String?;
      mineReels.add(Reel(
        id: m['id'], userId: 'me', caption: (m['caption'] ?? '') as String, video: v,
        poster: (po != null && File(po).existsSync()) ? po : null,
        audio: (a != null && File(a).existsSync()) ? a : null,
        audioName: (m['audioName'] ?? 'Original audio') as String,
        speed: ((m['speed'] ?? 1) as num).toDouble(), touch: ((m['touch'] ?? 0) as num).toDouble(),
        fx: (m['fx'] ?? 0) as int, minutes: ((now - (m['ts'] as int)) / 60000).floor(),
      ));
    }
    reels.insertAll(0, mineReels.reversed);
    _myDrafts = jsonDecode(sp.getString('mydrafts') ?? '[]') as List<dynamic>;
    drafts.clear();
    _myDrafts.removeWhere((m) {
      final v = m['video'] as String?;
      return v == null || !File(v).existsSync();
    });
    for (final m in _myDrafts) {
      final a = m['audio'] as String?;
      final po = m['poster'] as String?;
      drafts.add(ReelDraft(
        id: m['id'], video: m['video'], caption: (m['caption'] ?? '') as String,
        audioName: (m['audioName'] ?? 'Original audio') as String,
        speed: ((m['speed'] ?? 1) as num).toDouble(), touch: ((m['touch'] ?? 0) as num).toDouble(),
        fx: (m['fx'] ?? 0) as int, ts: m['ts'] as int,
        audio: (a != null && File(a).existsSync()) ? a : null,
        poster: (po != null && File(po).existsSync()) ? po : null,
      ));
    }
    drafts.sort((a, b) => b.ts.compareTo(a.ts));
    _myReelComments = jsonDecode(sp.getString('myrc') ?? '[]') as List<dynamic>;
    for (final m in _myReelComments) {
      final r = reelById(m['reel'] as String);
      if (r == null) continue;
      r.comments++;
      (reelComments[r.id] ??= []).insert(
          0,
          ReelComment(
            (m['id'] as String?) ?? 'rc${m['ts']}', r.id, 'me', m['text'] as String,
            ((now - (m['ts'] as int)) / 60000).floor(),
            parent: m['parent'] as String?, replyToUser: m['replyTo'] as String?,
          ));
    }
    final rl = (sp.getStringList('rl') ?? const []).toSet();
    final rs = (sp.getStringList('rs') ?? const []).toSet();
    final rr = (sp.getStringList('rr') ?? const []).toSet();
    for (final r in reels) {
      r.liked = rl.contains(r.id);
      r.saved = rs.contains(r.id);
      r.reposted = rr.contains(r.id);
    }
    _defaults.forEach((k, v) => flags[k] = sp.getBool('f_$k') ?? v);
    posts.sort((a, b) => a.minutes.compareTo(b.minutes));
  }

  Future<void> _save() async {
    final sp = _p;
    if (sp == null) return;
    await sp.setString('theme', mode.value);
    await sp.setString('name', me.name);
    await sp.setString('bio', me.bio);
    await sp.setStringList('following', following.toList());
    await sp.setStringList('reported', reported.toList());
    await sp.setStringList('cliked', likedComments.toList());
    await sp.setStringList('confirmed', confirmed.toList());
    await sp.setStringList('declined', declined.toList());
    await sp.setString('myreels', jsonEncode(_myReels));
    await sp.setString('mydrafts', jsonEncode(_myDrafts));
    await sp.setString('myrc', jsonEncode(_myReelComments));
    await sp.setStringList('rl', reels.where((r) => r.liked).map((r) => r.id).toList());
    await sp.setStringList('rs', reels.where((r) => r.saved).map((r) => r.id).toList());
    await sp.setStringList('rr', reels.where((r) => r.reposted).map((r) => r.id).toList());
    await sp.setStringList('liked', posts.where((p) => p.liked).map((p) => p.id).toList());
    await sp.setStringList('saved', posts.where((p) => p.saved).map((p) => p.id).toList());
    await sp.setString('mine', jsonEncode(_mine));
    for (final e in flags.entries) {
      await sp.setBool('f_${e.key}', e.value);
    }
  }

  void _commit() {
    // the screen updates at once; the disk write follows a moment later in the background
    notifyListeners();
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 300), _save);
  }

  void setTab(int i) {
    if (tab == i) return;
    tab = i;
    notifyListeners();
  }

  void setMode(String v) {
    mode.value = v;
    _save();
  }

  void setFlag(String k, bool v) {
    flags[k] = v;
    _commit();
  }

  void toggleLike(Post p) {
    p.liked = !p.liked;
    _commit();
  }

  void toggleSave(Post p) {
    p.saved = !p.saved;
    _commit();
  }

  void reportPost(Post p) {
    reported.add(p.id);
    _commit();
  }

  Reel? reelById(String id) {
    for (final r in reels) {
      if (r.id == id) return r;
    }
    return null;
  }

  void toggleReelLike(Reel r) {
    r.liked = !r.liked;
    _commit();
  }

  void toggleReelSave(Reel r) {
    r.saved = !r.saved;
    _commit();
  }

  void toggleReelRepost(Reel r) {
    r.reposted = !r.reposted;
    _commit();
  }

  void shareReel(Reel r) {
    r.shares++;
    notifyListeners();
  }

  void addReelComment(Reel r, String text, {String? parent, String? replyToUser}) {
    final t = text.trim();
    if (t.isEmpty) return;
    final ts = DateTime.now().millisecondsSinceEpoch;
    final c = ReelComment('rc$ts', r.id, 'me', t, 0, parent: parent, replyToUser: replyToUser);
    r.comments++;
    (reelComments[r.id] ??= []).insert(0, c);
    _myReelComments.add({
      'id': c.id, 'reel': r.id, 'text': t, 'ts': ts, 'parent': parent, 'replyTo': replyToUser,
    });
    _commit();
  }

  void addReel({
    required String video, String? audio, String audioName = 'Original audio',
    String caption = '', double speed = 1, int fx = 0, double touch = 0, String? poster,
    String? id,
  }) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final rid = id ?? 'm$ts';
    _myReels.add({
      'id': rid, 'video': video, 'audio': audio, 'audioName': audioName, 'caption': caption,
      'speed': speed, 'fx': fx, 'touch': touch, 'ts': ts, 'poster': poster,
    });
    reels.insert(0, Reel(
      id: rid, userId: 'me', caption: caption, video: video, audio: audio, audioName: audioName,
      speed: speed, fx: fx, touch: touch, poster: poster,
    ));
    _commit();
  }

  /// Reels posted by [userId] (never drafts).
  List<Reel> reelsOf(String userId) => reels.where((r) => r.userId == userId).toList();

  /// Save a reel to drafts instead of posting it. Only visible to me.
  void addDraft({
    required String video, String? audio, String audioName = 'Original audio',
    String caption = '', double speed = 1, int fx = 0, double touch = 0, String? poster,
  }) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final d = ReelDraft(
      id: 'd$ts', video: video, audio: audio, poster: poster, audioName: audioName,
      caption: caption, speed: speed, touch: touch, fx: fx, ts: ts,
    );
    drafts.insert(0, d);
    _myDrafts.add(d.toJson());
    _commit();
  }

  void deleteDraft(ReelDraft d) {
    drafts.removeWhere((x) => x.id == d.id);
    _myDrafts.removeWhere((m) => m['id'] == d.id);
    try {
      final f = File(d.video);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
    _commit();
  }

  /// Turn a draft into a real posted reel (the video file is reused, not copied).
  void postDraft(ReelDraft d) {
    drafts.removeWhere((x) => x.id == d.id);
    _myDrafts.removeWhere((m) => m['id'] == d.id);
    addReel(
      video: d.video, audio: d.audio, audioName: d.audioName, caption: d.caption,
      speed: d.speed, fx: d.fx, touch: d.touch, poster: d.poster,
    );
  }

  void deleteReel(Reel r) {
    reels.remove(r);
    _myReels.removeWhere((m) => m['id'] == r.id);
    _commit();
  }

  void toggleFollow(String id) {
    if (!following.remove(id)) following.add(id);
    _commit();
  }

  /// Create a new post, or update [edit] when editing.
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
    final Post post;
    int ts = DateTime.now().millisecondsSinceEpoch;
    if (edit != null) {
      post = edit;
      final old = _mine.indexWhere((m) => m['id'] == edit.id);
      if (old >= 0) ts = _mine[old]['ts'] as int;
    } else {
      post = Post('m$ts', 'me', text, 0, -1, 0, 0, 0);
      posts.insert(0, post);
    }
    post.text = text;
    post.bg = bg;
    post.font = font;
    post.tcolor = tcolor;
    post.image = image;
    post.video = video;
    post.stickers = stickers;
    final map = {
      'id': post.id, 'text': text, 'ts': ts, 'bg': bg, 'font': font, 'tc': tcolor,
      'img': image, 'vid': video, 'st': stickers.map((e) => e.toJson()).toList(),
    };
    final idx = _mine.indexWhere((m) => m['id'] == post.id);
    if (idx >= 0) {
      _mine[idx] = map;
    } else {
      _mine.insert(0, map);
    }
    _commit();
  }

  void deletePost(Post p) {
    posts.remove(p);
    _mine.removeWhere((m) => m['id'] == p.id);
    comments.removeWhere((c) => c.postId == p.id);
    _commit();
  }

  List<Comment> commentsOf(String postId) =>
      comments.where((c) => c.postId == postId).toList();

  void addComment(Post p, String text, {String? parent, String? replyToUser}) {
    comments.add(Comment('n${DateTime.now().millisecondsSinceEpoch}', p.id, 'me', text, 0,
        parent, replyToUser));
    p.commentCount++;
    notifyListeners();
  }

  void markRead(Notif n) {
    if (n.read) return;
    n.read = true;
    notifyListeners();
  }

  void markAllRead() {
    for (final n in notifs) {
      n.read = true;
    }
    notifyListeners();
  }

  void updateProfile(String name, String bio) {
    me.name = name.trim().isEmpty ? 'You' : name.trim();
    me.bio = bio.trim();
    _commit();
  }

  Future<void> reset() async {
    await _p?.clear();
    following.clear();
    reported.clear();
    likedComments.clear();
    confirmed.clear();
    declined.clear();
    reels.removeWhere((r) => r.userId == 'me');
    for (final l in reelComments.values) {
      l.removeWhere((c) => c.userId == 'me');
    }
    for (final r in reels) {
      r.liked = false;
      r.saved = false;
      r.reposted = false;
    }
    _myReels = [];
    _myDrafts = [];
    drafts.clear();
    _myReelComments = [];
    _mine = [];
    posts.removeWhere((p) => p.userId == 'me');
    for (final p in posts) {
      p.liked = false;
      p.saved = false;
    }
    me.name = 'You';
    me.bio = 'Hello Intly 👋';
    _defaults.forEach((k, v) => flags[k] = v);
    mode.value = 'system';
    for (final n in notifs.take(4)) {
      n.read = false;
    }
    notifyListeners();
  }
}
