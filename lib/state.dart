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
  final Map<String, bool> flags = {};
  static const _defaults = {
    'push': true, 'likes': true, 'follows': true, 'private': false, 'activity': true,
  };
  late User me;
  SharedPreferences? _p;
  List<dynamic> _mine = [];

  User user(String id) => users[id] ?? me;
  int get unread => notifs.where((n) => !n.read).length;
  int followersOf(User u) =>
      u.id == 'me' ? u.followers : u.followers + (following.contains(u.id) ? 1 : 0);
  int followingOf(User u) => u.id == 'me' ? following.length : u.following;
  List<Post> postsOf(String id) => posts.where((p) => p.userId == id).toList();
  /// Heart count of a comment/reply (stable demo base + your own heart).
  int commentLikes(Comment c) {
    final mine = likedComments.contains(c.id) ? 1 : 0;
    if (c.id.startsWith('n')) return mine; // comments written in the app start at 0
    var h = 7;
    for (final u in c.id.codeUnits) {
      h = (h * 31 + u) & 0x7fffffff;
    }
    return h % 41 + mine;
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
    _p = await SharedPreferences.getInstance();
    final sp = _p!;
    mode.value = sp.getString('theme') ?? 'system';
    me.name = sp.getString('name') ?? me.name;
    me.bio = sp.getString('bio') ?? me.bio;
    following.addAll(sp.getStringList('following') ?? const []);
    reported.addAll(sp.getStringList('reported') ?? const []);
    likedComments.addAll(sp.getStringList('cliked') ?? const []);
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
    await sp.setStringList('liked', posts.where((p) => p.liked).map((p) => p.id).toList());
    await sp.setStringList('saved', posts.where((p) => p.saved).map((p) => p.id).toList());
    await sp.setString('mine', jsonEncode(_mine));
    for (final e in flags.entries) {
      await sp.setBool('f_${e.key}', e.value);
    }
  }

  void _commit() {
    notifyListeners();
    _save();
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

