
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
      body: _TabStack(
        index: s.tab,
        children: const [
          HomeScreen(), // 0 home
          ExploreScreen(), // 1 explore
          SizedBox.shrink(), // 2 (unused: search lives inside Explore)
          SizedBox.shrink(), // 3 notifications: opened from the bell on the home screen
          ProfileScreen(userId: 'me', isTab: true), // 4 profile
          ReelsScreen(), // reelsTab (5)
        ],
      ),
      bottomNavigationBar: const _NavBar(),
    );
  }
}

/// Every tab stays alive (scroll position, playing videos). Switching fades the
/// new tab in and slides it up slightly; the old one fades out.
class _TabStack extends StatelessWidget {
  final int index;
  final List<Widget> children;
  const _TabStack({required this.index, required this.children});

  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        children: [
          for (var i = 0; i < children.length; i++)
            _Tab(active: i == index, child: children[i]),
        ],
      );
}

class _Tab extends StatelessWidget {
  final bool active;
  final Widget child;
  const _Tab({required this.active, required this.child});

  @override
  Widget build(BuildContext context) => IgnorePointer(
        ignoring: !active,
        child: AnimatedOpacity(
          opacity: active ? 1 : 0,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          child: AnimatedSlide(
            offset: active ? Offset.zero : const Offset(0, .025),
            duration: const Duration(milliseconds: 360),
            curve: Curves.easeOutCubic,
            child: TickerMode(enabled: active, child: child),
          ),
        ),
      );
}

class _NavBar extends StatelessWidget {
  const _NavBar();

  Widget _item(BuildContext c, IconData icon, int i) {
    final p = c.p;
    final on = c.s.tab == i;
    return Expanded(
      child: Tap(
        onTap: () => c.s.setTab(i),
        child: Center(
          child: AnimatedScale(
            scale: on ? 1.12 : 1,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutBack,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(icon, key: ValueKey(on), size: 24, color: on ? p.accent : p.sub),
            ),
          ),
        ),
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
          height: 48,
          child: Row(children: [
            _item(context, LucideIcons.home, 0),
            _item(context, LucideIcons.compass, 1),
            _item(context, LucideIcons.clapperboard, reelsTab),
            _item(context, LucideIcons.user, 4),
          ]),
        ),
      ),
    );
  }
}
