

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'edit_profile.dart';
import 'follow_list.dart';
import 'reel_viewer.dart';
import 'suggestions.dart';
import 'settings.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;
  final bool isTab;
  const ProfileScreen({super.key, required this.userId, this.isTab = false});
  @override
  State<ProfileScreen> createState() => _ProfileState();
}

class _ProfileState extends State<ProfileScreen> {
  int _tab = 0;

  Widget _stat(Pal p, String n, String l, [VoidCallback? onTap]) => Tap(
        onTap: onTap ?? () {},
        child: Column(children: [
          Text(n, style: ts(p.text, 16, FontWeight.w800)),
          const SizedBox(height: 2),
          Text(l, style: ts(p.sub, 13)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final s = context.s;
    final u = s.user(widget.userId);
    final me = u.id == 'me';
    final tabs = me ? ['Posts', 'Reels', 'Saved', 'Likes'] : ['Posts', 'Reels'];
    final mine = s.postsOf(u.id);
    // Reels tab: only reels posted by this account (drafts are never in here)
    final reelList = s.reelsOf(u.id);
    final List<Post> list = switch (_tab) {
      0 => mine,
      1 => const <Post>[],
      2 => s.posts.where((x) => x.saved).toList(),
      _ => s.posts.where((x) => x.liked).toList(),
    };
    return Scaffold(
      backgroundColor: p.bg,
      body: CustomScrollView(
        cacheExtent: 800,
        slivers: [
          SliverToBoxAdapter(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                height: 216,
                child: Stack(clipBehavior: Clip.none, children: [
                  Positioned(
                    top: 0, left: 0, right: 0, height: 160,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [hsl(u.hue, .7, .45), hsl(u.hue + 80, .8, .35)],
                        ),
                      ),
                      child: SafeArea(
                        bottom: false,
                        child: Row(children: [
                          const SizedBox(width: 6),
                          if (!widget.isTab)
                            _Round(LucideIcons.arrowLeft, () => Navigator.of(context).maybePop()),
                          const Spacer(),
                          if (me)
                            _Round(LucideIcons.settings,
                                () => Navigator.of(context).push(slide(const SettingsScreen()))),
                          const SizedBox(width: 12),
                        ]),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16, top: 112,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: p.bg, shape: BoxShape.circle),
                      child: Avatar(u, 88),
                    ),
                  ),
                  Positioned(
                    right: 16, top: 176,
                    child: me
                        ? Tap(
                            onTap: () => Navigator.of(context).push(slide(const EditProfileScreen())),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                              decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: p.line, width: 1.5)),
                              child: Text('Edit profile', style: ts(p.text, 14, FontWeight.w700)),
                            ),
                          )
                        : FollowBtn(u.id),
                  ),
                ]),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(child: Text(u.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(p.text, 22, FontWeight.w800))),
                    if (me && s.isPrivate) ...[
                      const SizedBox(width: 8),
                      Icon(LucideIcons.lock, size: 18, color: p.sub),
                    ],
                  ]),
                  Text('@${u.handle}', style: ts(p.sub, 14)),
                  if (u.bio.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(u.bio, style: ts(p.text, 15, FontWeight.w400, 1.4)),
                  ],
                  const SizedBox(height: 10),
                  Row(children: [
                    Icon(LucideIcons.calendar, size: 15, color: p.sub),
                    const SizedBox(width: 6),
                    Text('Joined November 2026', style: ts(p.sub, 13)),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _stat(p, '${mine.length}', 'Posts')),
                    Expanded(child: _stat(p, '${reelList.length}', 'Reels')),
                    Expanded(child: _stat(p, compact(s.followersOf(u)), 'Followers',
                        () => openFollowList(context, u.id, 0))),
                    Expanded(child: _stat(p, compact(s.followingOf(u)), 'Following',
                        () => openFollowList(context, u.id, 1))),
                  ]),
                ]),
              ),
              if (me) const SuggestionsStrip(),
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.line))),
                child: Row(children: [
                  for (int i = 0; i < tabs.length; i++)
                    Expanded(
                      child: Tap(
                        onTap: () => setState(() => _tab = i),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(
                            border: Border(
                                bottom: BorderSide(
                                    color: _tab == i ? p.accent : Colors.transparent, width: 3)),
                          ),
                          child: Center(
                            child: Text(tabs[i],
                                style: ts(_tab == i ? p.text : p.sub, 14, FontWeight.w700)),
                          ),
                        ),
                      ),
                    ),
                ]),
              ),
            ]),
          ),
          if (_tab == 1) ...[
            // very first row of your own Reels tab: drafts (only you can see them)
            if (me) const SliverToBoxAdapter(child: DraftsRow()),
            if (reelList.isEmpty)
              const SliverToBoxAdapter(child: Empty(LucideIcons.clapperboard, 'No reels yet'))
            else
              SliverPadding(
                padding: const EdgeInsets.only(top: 2),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, mainAxisSpacing: 2, crossAxisSpacing: 2, childAspectRatio: .62,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (c, i) => ReelTile(
                      reelList[i],
                      key: ValueKey('rt_${reelList[i].id}'),
                      onTap: () => Navigator.of(context).push(
                          slide(ReelsViewer(userId: u.id, start: i), name: 'reels:${u.id}')),
                    ),
                    childCount: reelList.length,
                  ),
                ),
              ),
          ] else if (list.isEmpty)
            SliverToBoxAdapter(
              child: Empty(LucideIcons.inbox, const [
                'No posts yet',
                '',
                'Tap the bookmark on any post to save it here',
                'Posts you like will show up here',
              ][_tab]),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (c, i) => PostCard(list[i], key: ValueKey('${_tab}_${list[i].id}')),
                childCount: list.length,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

class _Round extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _Round(this.icon, this.onTap);
  @override
  Widget build(BuildContext context) => Tap(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(top: 6),
          width: 38, height: 38,
          decoration: const BoxDecoration(color: Color(0x66000000), shape: BoxShape.circle),
          child: Icon(icon, size: 20, color: Colors.white),
        ),
      );
}
