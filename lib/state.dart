import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'native.dart';

class User {
  final String id;
  String name, handle, bio;
  final int hue, followers, following;
  User(this.id, this.name, this.handle, this.bio, this.hue, this.followers, this.following);
}

class Post {
  final String id, userId;
  final String text;
  int minutes;
  final int media, likes, shares;
  int commentCount;
  bool liked = false, saved = false;
  Post(this.id, this.userId, this.text, this.minutes, this.media, this.likes,
      this.commentCount, this.shares);
  int get likeCount => likes + (liked ? 1 : 0);
}

class Comment {
  final String postId, userId, text;
  final int minutes;
  Comment(this.postId, this.userId, this.text, this.minutes);
}

class Notif {
  final String type, userId, text;
  final int minutes;
  bool read;
  Notif(this.type, this.userId, this.text, this.minutes, this.read);
}

class Scope extends InheritedNotifier<AppState> {
  const Scope({super.key, required AppState state, required super.child})
      : super(notifier: state);
  static AppState of(BuildContext c) =>
      c.dependOnInheritedWidgetOfExactType<Scope>()!.notifier!;
}

class AppState extends ChangeNotifier {
  final dark = ValueNotifier<bool>(true);
  int tab = 0;
  final Map<String, User> users = {};
  final List<Post> posts = [];
  final List<Comment> comments = [];
  final List<Notif> notifs = [];
  final Set<String> following = {};
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
      comments.add(Comment(c['post'], c['user'], c['text'], c['minutes']));
    }
    int i = 0;
    for (final n in raw['notifs']) {
      notifs.add(Notif(n['type'], n['user'], n['text'], n['minutes'], i++ >= 4));
    }
    _p = await SharedPreferences.getInstance();
    final sp = _p!;
    dark.value = sp.getBool('dark') ?? true;
    me.name = sp.getString('name') ?? me.name;
    me.bio = sp.getString('bio') ?? me.bio;
    following.addAll(sp.getStringList('following') ?? const []);
    final liked = (sp.getStringList('liked') ?? const []).toSet();
    final saved = (sp.getStringList('saved') ?? const []).toSet();
    _mine = jsonDecode(sp.getString('mine') ?? '[]') as List<dynamic>;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final m in _mine) {
      posts.add(Post(m['id'], 'me', m['text'], ((now - (m['ts'] as int)) / 60000).floor(), -1, 0, 0, 0));
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
    await sp.setBool('dark', dark.value);
    await sp.setString('name', me.name);
    await sp.setString('bio', me.bio);
    await sp.setStringList('following', following.toList());
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

  void setDark(bool v) {
    dark.value = v;
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

  void toggleFollow(String id) {
    if (!following.remove(id)) following.add(id);
    _commit();
  }

  void addPost(String text) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final id = 'm$ts';
    _mine.insert(0, {'id': id, 'text': text, 'ts': ts});
    posts.insert(0, Post(id, 'me', text, 0, -1, 0, 0, 0));
    _commit();
  }

  List<Comment> commentsOf(String postId) =>
      comments.where((c) => c.postId == postId).toList();

  void addComment(Post p, String text) {
    comments.add(Comment(p.id, 'me', text, 0));
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
    _mine = [];
    posts.removeWhere((p) => p.userId == 'me');
    for (final p in posts) {
      p.liked = false;
      p.saved = false;
    }
    me.name = 'You';
    me.bio = 'Hello Intly 👋';
    _defaults.forEach((k, v) => flags[k] = v);
    dark.value = true;
    for (final n in notifs.take(4)) {
      n.read = false;
    }
    notifyListeners();
  }
}
