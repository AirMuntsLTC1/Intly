import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme.dart';
import '../widgets.dart';
import 'compose.dart';
import 'explore.dart';
import 'home.dart';
import 'notifications.dart';
import 'profile.dart';

class Shell extends StatelessWidget {
  const Shell({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Scaffold(
      body: IndexedStack(
        index: s.tab,
        children: const [
          HomeScreen(),
          ExploreScreen(),
          SizedBox.shrink(),
          NotificationsScreen(),
          ProfileScreen(userId: 'me', isTab: true),
        ],
      ),
      bottomNavigationBar: const _NavBar(),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar();

  Widget _item(BuildContext c, IconData icon, int i, {int badge = 0}) {
    final p = c.p;
    final on = c.s.tab == i;
    return Expanded(
      child: Tap(
        onTap: () => c.s.setTab(i),
        child: Center(
          child: Stack(clipBehavior: Clip.none, children: [
            Icon(icon, size: 26, color: on ? p.accent : p.sub),
            if (badge > 0)
              Positioned(
                right: -9, top: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(color: p.danger, borderRadius: BorderRadius.circular(9)),
                  child: Text('$badge', style: ts(Colors.white, 10, FontWeight.w800)),
                ),
              ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final s = context.s;
    return Container(
      decoration: BoxDecoration(color: p.bg, border: Border(top: BorderSide(color: p.line))),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(children: [
            _item(context, LucideIcons.home, 0),
            _item(context, LucideIcons.compass, 1),
            Expanded(
              child: Tap(
                onTap: () async {
                  final ok = await Navigator.of(context)
                      .push<bool>(slide<bool>(const ComposeScreen()));
                  if (ok == true) s.setTab(0);
                },
                child: Center(
                  child: Container(
                    width: 46, height: 34,
                    decoration: BoxDecoration(gradient: p.grad, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(LucideIcons.plus, color: Colors.white, size: 22),
                  ),
                ),
              ),
            ),
            _item(context, LucideIcons.bell, 3, badge: s.unread),
            _item(context, LucideIcons.user, 4),
          ]),
        ),
      ),
    );
  }
}
