import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../native.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});
  @override
  State<ExploreScreen> createState() => _ExploreState();
}

class _ExploreState extends State<ExploreScreen> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _section(Pal p, IconData icon, String t) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Row(children: [
          Icon(icon, size: 20, color: p.accent),
          const SizedBox(width: 8),
          Text(t, style: ts(p.text, 18, FontWeight.w800)),
        ]),
      );

  List<Widget> _discover(Pal p, AppState s) {
    final counts = <String, int>{};
    for (final post in s.posts) {
      for (final t in Native.tags(post.text)) {
        counts[t] = (counts[t] ?? 0) + 1;
      }
    }
    final tags = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final people = s.users.values.where((u) => u.id != 'me').take(10).toList();
    final hot = [...s.posts]..sort((a, b) => Native.hot(b.likeCount, b.commentCount, b.shares, b.minutes / 60.0)
        .compareTo(Native.hot(a.likeCount, a.commentCount, a.shares, a.minutes / 60.0)));
    return [
      _section(p, LucideIcons.trendingUp, 'Trending'),
      for (int i = 0; i < tags.length && i < 6; i++)
        Tap(
          onTap: () => setState(() => _c.text = '#${tags[i].key}'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              SizedBox(width: 28, child: Text('${i + 1}', style: ts(p.sub, 15, FontWeight.w700))),
              Expanded(child: Text('#${tags[i].key}', style: ts(p.text, 16, FontWeight.w700))),
              Text('${tags[i].value} posts', style: ts(p.sub, 13)),
            ]),
          ),
        ),
      _section(p, LucideIcons.userPlus, 'Who to follow'),
      SizedBox(
        height: 168,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: people.length,
          itemBuilder: (c, i) => _UserCard(people[i]),
        ),
      ),
      _section(p, LucideIcons.flame, 'Hot right now'),
      for (final post in hot.take(8)) PostCard(post, key: ValueKey('h${post.id}')),
    ];
  }

  List<Widget> _results(Pal p, AppState s, String raw) {
    final tag = raw.startsWith('#');
    final q = raw.replaceFirst(RegExp(r'^[#@]'), '').toLowerCase();
    final people = tag
        ? <User>[]
        : s.users.values
            .where((u) => u.name.toLowerCase().contains(q) || u.handle.contains(q))
            .toList();
    final posts = s.posts.where((x) => x.text.toLowerCase().contains(tag ? '#$q' : q)).take(30).toList();
    if (people.isEmpty && posts.isEmpty) {
      return [const Empty(LucideIcons.search, 'No results. Try another name, word or #tag.')];
    }
    return [
      if (people.isNotEmpty) _section(p, LucideIcons.users, 'People'),
      for (final u in people)
        Tap(
          onTap: () => openProfile(context, u.id),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              Avatar(u, 46),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(u.name, style: ts(p.text, 15, FontWeight.w700)),
                  Text('@${u.handle}', style: ts(p.sub, 13)),
                ]),
              ),
              if (u.id != 'me') FollowBtn(u.id, small: true),
            ]),
          ),
        ),
      if (posts.isNotEmpty) _section(p, LucideIcons.fileText, 'Posts'),
      for (final post in posts) PostCard(post, key: ValueKey('r${post.id}')),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final s = context.s;
    final q = _c.text.trim();
    final items = q.isEmpty ? _discover(p, s) : _results(p, s, q);
    return Scaffold(
      backgroundColor: p.bg,
      body: Column(children: [
        Container(
          decoration: BoxDecoration(color: p.bg, border: Border(bottom: BorderSide(color: p.line))),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(22)),
                child: Row(children: [
                  Icon(LucideIcons.search, size: 20, color: p.sub),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _c,
                      onChanged: (_) => setState(() {}),
                      style: ts(p.text, 15),
                      cursorColor: p.accent,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration.collapsed(
                        hintText: 'Search people, posts, #tags',
                        hintStyle: ts(p.sub, 15),
                      ),
                    ),
                  ),
                  if (q.isNotEmpty)
                    Tap(
                      onTap: () => setState(() => _c.clear()),
                      child: Icon(LucideIcons.x, size: 20, color: p.sub),
                    ),
                ]),
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            cacheExtent: 800,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            itemCount: items.length,
            itemBuilder: (c, i) => items[i],
          ),
        ),
      ]),
    );
  }
}

class _UserCard extends StatelessWidget {
  final User u;
  const _UserCard(this.u);
  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Tap(
      onTap: () => openProfile(context, u.id),
      child: Container(
        width: 138,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: p.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: p.line)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Avatar(u, 56),
          const SizedBox(height: 8),
          Text(u.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(p.text, 14, FontWeight.w700)),
          Text('@${u.handle}', maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(p.sub, 12)),
          const SizedBox(height: 10),
          FollowBtn(u.id, small: true),
        ]),
      ),
    );
  }
}
