import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../native.dart';
import '../theme.dart';
import '../widgets.dart';
import 'edit_profile.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Widget _head(Pal p, String t) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 6),
        child: Text(t.toUpperCase(), style: ts(p.sub, 12, FontWeight.w800).copyWith(letterSpacing: 1)),
      );

  Widget _row(Pal p, IconData icon, String title, {String? sub, Widget? trailing, VoidCallback? onTap, bool danger = false}) {
    final c = danger ? p.danger : p.text;
    return Tap(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, size: 20, color: danger ? p.danger : p.accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: ts(c, 16, FontWeight.w600)),
              if (sub != null) Text(sub, style: ts(p.sub, 13)),
            ]),
          ),
          if (trailing != null) trailing,
        ]),
      ),
    );
  }

  Future<void> _confirm(BuildContext context) async {
    final p = context.p;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => Dialog(
        backgroundColor: p.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Reset Intly?', style: ts(p.text, 20, FontWeight.w800)),
            const SizedBox(height: 8),
            Text('This clears your posts, follows, likes, saves and settings on this device.',
                style: ts(p.sub, 15, FontWeight.w400, 1.4)),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              Tap(
                onTap: () => Navigator.pop(d, false),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Text('Cancel', style: ts(p.text, 15, FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 6),
              Tap(
                onTap: () => Navigator.pop(d, true),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(color: p.danger, borderRadius: BorderRadius.circular(18)),
                  child: Text('Reset', style: ts(Colors.white, 15, FontWeight.w700)),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
    if (ok == true && context.mounted) {
      await context.s.reset();
      if (context.mounted) toast(context, 'Intly was reset');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final s = context.s;
    Widget flag(IconData i, String t, String k, String sub) => _row(p, i, t,
        sub: sub, trailing: Toggle(s.flags[k] ?? false, (v) => s.setFlag(k, v)), onTap: () => s.setFlag(k, !(s.flags[k] ?? false)));
    return Scaffold(
      backgroundColor: p.bg,
      body: Column(children: [
        const TopBar('Settings', back: true),
        Expanded(
          child: ListView(padding: EdgeInsets.zero, children: [
            _head(p, 'Theme (System follows your phone)'),
            ValueListenableBuilder<String>(
              valueListenable: s.mode,
              builder: (c, m, _) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(children: [
                  for (final o in const [
                    ['system', 'System', 0],
                    ['light', 'Light', 1],
                    ['dark', 'Dark', 2],
                  ])
                    Expanded(
                      child: Tap(
                        onTap: () => s.setMode(o[0] as String),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: m == o[0] ? p.accent : p.card,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(children: [
                            Icon(
                              o[2] == 0 ? LucideIcons.smartphone : (o[2] == 1 ? LucideIcons.sun : LucideIcons.moon),
                              size: 20, color: m == o[0] ? Colors.white : p.sub),
                            const SizedBox(height: 4),
                            Text(o[1] as String,
                                style: ts(m == o[0] ? Colors.white : p.text, 13, FontWeight.w700)),
                          ]),
                        ),
                      ),
                    ),
                ]),
              ),
            ),
            _head(p, 'Notifications'),
            flag(LucideIcons.bell, 'Push notifications', 'push', 'Allow alerts from Intly'),
            flag(LucideIcons.heart, 'Likes', 'likes', 'When someone likes your post'),
            flag(LucideIcons.userPlus, 'New followers', 'follows', 'When someone follows you'),
            _head(p, 'Privacy'),
            flag(LucideIcons.lock, 'Private account', 'private', 'Only followers see your posts'),
            flag(LucideIcons.eye, 'Show activity', 'activity', 'Let others see when you are active'),
            _head(p, 'Account'),
            _row(p, LucideIcons.user, 'Edit profile',
                trailing: Icon(LucideIcons.chevronRight, size: 20, color: p.sub),
                onTap: () => Navigator.of(context).push(slide(const EditProfileScreen()))),
            _row(p, LucideIcons.trash2, 'Reset app data', danger: true, onTap: () => _confirm(context)),
            _head(p, 'About'),
            _row(p, LucideIcons.info, 'Intly', sub: 'Version 1.0.0'),
            _row(p, LucideIcons.cpu, 'C++ core', sub: Native.ok ? 'Active (native)' : 'Fallback (Dart)'),
            const SizedBox(height: 40),
          ]),
        ),
      ]),
    );
  }
}
