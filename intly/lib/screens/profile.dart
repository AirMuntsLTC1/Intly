import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'edit_profile.dart';
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

  Widget _stat(Pal p, String n, String l) => Padding(
        padding: const EdgeInsets.only(right: 22),
        child: Row(children: [
          Text(n, style: ts(p.text, 16, FontWeight.w800)),
          const SizedBox(width: 5),
          Text(l, style: ts(p.sub, 14)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final s = context.s;
    final u = s.user(widget.userId);
    final me = u.id == 'me';
    final tabs = me ? ['Posts', 'Media', 'Saved', 'Likes'] : ['Posts', 'Media'];
    final mine = s.postsOf(u.id);
    final List<Post> list = switch (_tab) {
      0 => mine,
      1 => mine.where((x) => x.media >= 0).toList(),
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
              Stack(clipBehavior: Clip.none, children: [
                Container(
                  height: 160,
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
                Positioned(
                  left: 16, bottom: -42,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: p.bg, shape: BoxShape.circle),
                    child: Avatar(u, 88),
                  ),
                ),
                Positioned(
                  right: 16, bottom: -46,
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
              const SizedBox(height: 54),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(u.name, style: ts(p.text, 22, FontWeight.w800)),
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
                    _stat(p, '${mine.length}', 'Posts'),
                    _stat(p, compact(s.followersOf(u)), 'Followers'),
                    _stat(p, compact(s.followingOf(u)), 'Following'),
                  ]),
                ]),
              ),
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
          if (list.isEmpty)
            SliverToBoxAdapter(
              child: Empty(LucideIcons.inbox, const [
                'No posts yet',
                'No photos yet',
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

