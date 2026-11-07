import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

/// A person Intly suggests, with the people you follow who also follow them.
class Suggestion {
  final User user;
  final List<User> mutuals;
  const Suggestion(this.user, this.mutuals);
  int get mutualCount => mutuals.length;
}

/// Everyone you could follow, most mutual connections first, then by name.
/// Skips yourself and anyone you already follow or have requested.
List<Suggestion> suggestionsFor(AppState s) {
  final mine = s.followingList('me').toSet();
  final out = <Suggestion>[];
  for (final u in s.users.values) {
    if (u.id == 'me') continue;
    if (s.followStatus(u.id) != 'none') continue;
    final theirFollowers = s.followersList(u.id).toSet();
    final shared = mine.where(theirFollowers.contains);
    out.add(Suggestion(u, [for (final id in shared) s.user(id)]));
  }
  out.sort((a, b) {
    final byMutuals = b.mutualCount.compareTo(a.mutualCount);
    if (byMutuals != 0) return byMutuals;
    return a.user.name.toLowerCase().compareTo(b.user.name.toLowerCase());
  });
  return out;
}

String _mutualLabel(int n) => n == 0 ? 'Suggested for you' : '$n mutual${n == 1 ? '' : 's'}';

/// Up to three overlapping small photos of the mutual connections.
class _MutualFaces extends StatelessWidget {
  final List<User> users;
  const _MutualFaces(this.users);

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final shown = users.take(3).toList();
    return SizedBox(
      width: 22 + (shown.length - 1) * 12.0,
      height: 22,
      child: Stack(children: [
        for (var i = 0; i < shown.length; i++)
          Positioned(
            left: i * 12.0,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: p.bg, width: 1.5),
              ),
              child: Avatar(shown[i], 22),
            ),
          ),
      ]),
    );
  }
}

/// Profile section under Posts / Reels / Followers / Following: the first 10
/// suggestions, scrollable sideways, with a See all link.
class SuggestionsStrip extends StatelessWidget {
  const SuggestionsStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final top = suggestionsFor(context.s).take(10).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
        child: Row(children: [
          Expanded(child: Text('Suggestions People', style: ts(p.text, 17, FontWeight.w800))),
          Tap(
            onTap: () => Navigator.of(context).push(slide(const SuggestionsScreen(), name: 'suggestions')),
            child: Text('See all', style: ts(p.accent, 14, FontWeight.w700)),
          ),
        ]),
      ),
      if (top.isEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text('No suggestions yet. Follow people to see more.', style: ts(p.sub, 14)),
        )
      else
        SizedBox(
          height: 206,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: top.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) => _SuggestionCard(top[i]),
          ),
        ),
      const SizedBox(height: 6),
    ]);
  }
}

class _SuggestionCard extends StatelessWidget {
  final Suggestion sg;
  const _SuggestionCard(this.sg);

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final u = sg.user;
    return Tap(
      onTap: () => openProfile(context, u.id),
      child: Container(
        width: 150,
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: p.line),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Avatar(u, 72),
          const SizedBox(height: 10),
          Text(u.handle,
              maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
              style: ts(p.text, 14, FontWeight.w800)),
          const SizedBox(height: 2),
          Text(_mutualLabel(sg.mutualCount),
              maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
              style: ts(p.sub, 12)),
          const SizedBox(height: 10),
          FollowBtn(u.id, small: true),
        ]),
      ),
    );
  }
}

/// Full-screen list. Mutuals come first, then everyone else.
class SuggestionsScreen extends StatelessWidget {
  const SuggestionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final all = suggestionsFor(context.s);
    final mutuals = all.where((x) => x.mutualCount > 0).toList();
    final others = all.where((x) => x.mutualCount == 0).toList();
    return Scaffold(
      backgroundColor: p.bg,
      body: Column(children: [
        const TopBar('Discover people', back: true),
        Expanded(
          child: all.isEmpty
              ? const Empty(LucideIcons.users, 'No suggestions yet. Follow people to see more.')
              : ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    if (mutuals.isNotEmpty) ...[
                      _SectionHead(p, 'Mutuals'),
                      for (final sg in mutuals) _SuggestionRow(sg),
                    ],
                    if (others.isNotEmpty) ...[
                      _SectionHead(p, 'Suggested for you'),
                      for (final sg in others) _SuggestionRow(sg),
                    ],
                  ],
                ),
        ),
      ]),
    );
  }
}

class _SectionHead extends StatelessWidget {
  final Pal p;
  final String label;
  const _SectionHead(this.p, this.label);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
        child: Text(label, style: ts(p.sub, 13, FontWeight.w800)),
      );
}

class _SuggestionRow extends StatelessWidget {
  final Suggestion sg;
  const _SuggestionRow(this.sg);

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final u = sg.user;
    return Tap(
      onTap: () => openProfile(context, u.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          Avatar(u, 56),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(u.handle,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: ts(p.text, 15, FontWeight.w700)),
              Text(u.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(p.sub, 14)),
              const SizedBox(height: 4),
              Row(children: [
                if (sg.mutualCount > 0) ...[
                  _MutualFaces(sg.mutuals),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(_mutualLabel(sg.mutualCount),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: ts(p.sub, 13)),
                ),
              ]),
            ]),
          ),
          const SizedBox(width: 8),
          FollowBtn(u.id, small: true),
        ]),
      ),
    );
  }
}
