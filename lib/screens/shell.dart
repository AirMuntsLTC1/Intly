import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme.dart';
import '../widgets.dart';
import 'explore.dart';
import 'home.dart';
import 'profile.dart';
import 'reels.dart';
import '../reel_fx.dart';

class Shell extends StatelessWidget {
  const Shell({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Scaffold(
      body: IndexedStack(
        index: s.tab,
        children: const [
          HomeScreen(), // 0 home
          ExploreScreen(), // 1 explore
          ExploreScreen(searchOnly: true), // 2 search
          SizedBox.shrink(), // 3 notifications: opened from the bell on the home screen
          ProfileScreen(userId: 'me', isTab: true), // 4 profile
          ReelsScreen(), // reelsTab (5)
        ],
      ),
      bottomNavigationBar: const _NavBar(),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar();

  Widget _item(BuildContext c, IconData icon, int i) {
    final p = c.p;
    final on = c.s.tab == i;
    return Expanded(
      child: Tap(
        onTap: () => c.s.setTab(i),
        child: Center(child: Icon(icon, size: 26, color: on ? p.accent : p.sub)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Container(
      decoration: BoxDecoration(color: p.bg, border: Border(top: BorderSide(color: p.line))),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(children: [
            _item(context, LucideIcons.home, 0),
            _item(context, LucideIcons.compass, 1),
            _item(context, LucideIcons.search, 2),
            _item(context, LucideIcons.clapperboard, reelsTab),
            _item(context, LucideIcons.user, 4),
          ]),
        ),
      ),
    );
  }
}
