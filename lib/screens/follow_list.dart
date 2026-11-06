import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

/// Opens the followers / following screen of [userId] (0 = followers, 1 = following,
/// 2 = flagged requests, only for your own account). Never stacks the same screen twice.
void openFollowList(BuildContext c, String userId, int tab) =>
    pushOnce(c, 'follows:$userId', FollowListScreen(userId: userId, initialTab: tab));

class FollowListScreen extends StatefulWidget {
  final String userId;
  final int initialTab;
  const FollowListScreen({super.key, required this.userId, this.initialTab = 0});
  @override
  State<FollowListScreen> createState() => _FollowListState();
}

class _FollowListState extends State<FollowListScreen> {
  late int _tab = widget.initialTab;
  final _q = TextEditingController();
  int _sort = 0;
  static const _sorts = ['Default', 'Name (A–Z)', 'Latest first'];

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  bool get _own => widget.userId == 'me';

  List<User> _prepare(AppState s, List<String> ids) {
    final query = _q.text.trim().toLowerCase();
    var list = ids.map(s.user).toList();
    if (query.isNotEmpty) {
      list = list.where((u) => u.name.toLowerCase().contains(query) || u.handle.contains(query)).toList();
    }
    if (_sort == 1) {
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } else if (_sort == 2) {
      list = list.reversed.toList();
    }
    return list;
  }

  void _sheet(Pal p, List<Widget> rows) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: p.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: p.line, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 10),
            ...rows,
          ]),
        ),
      ),
    );
  }

  Widget _opt(Pal p, IconData icon, String label, VoidCallback onTap, {bool danger = false, bool check = false}) => Tap(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          child: Row(children: [
            Icon(icon, size: 22, color: danger ? p.danger : p.text),
            const SizedBox(width: 16),
            Expanded(child: Text(label, style: ts(danger ? p.danger : p.text, 16, FontWeight.w600))),
            if (check) Icon(LucideIcons.check, size: 20, color: p.accent),
          ]),
        ),
      );

  void _sortSheet(Pal p) => _sheet(p, [
        for (int i = 0; i < _sorts.length; i++)
          _opt(p, LucideIcons.arrowUpDown, _sorts[i], () {
            Navigator.pop(context);
            setState(() => _sort = i);
          }, check: _sort == i),
      ]);

  void _menu(Pal p, AppState s, User u, bool followers) => _sheet(p, [
        if (followers)
          _opt(p, LucideIcons.userX, 'Remove follower', () {
            Navigator.pop(context);
            s.removeFollower(u.id);
            toast(context, '${u.name} was removed from your followers');
          }, danger: true)
        else
          _opt(p, LucideIcons.userMinus, 'Unfollow', () {
            Navigator.pop(context);
            s.toggleFollow(u.id);
          }, danger: true),
      ]);

  Widget _row(Pal p, AppState s, User u, {required bool followers}) {
    final isMe = u.id == 'me';
    return Tap(
      onTap: () => openProfile(context, u.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          Avatar(u, 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(u.handle, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(p.text, 15, FontWeight.w700)),
              Text(u.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(p.sub, 14)),
            ]),
          ),
          if (!isMe) FollowBtn(u.id, small: true),
          if (_own && !isMe)
            Tap(
              onTap: () => _menu(p, s, u, followers),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(LucideIcons.moreVertical, size: 20, color: p.sub),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _search(Pal p) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            Icon(LucideIcons.search, size: 20, color: p.sub),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _q,
                onChanged: (_) => setState(() {}),
                style: ts(p.text, 15),
                cursorColor: p.accent,
                decoration: InputDecoration.collapsed(hintText: 'Search', hintStyle: ts(p.sub, 15)),
              ),
            ),
            if (_q.text.isNotEmpty)
              Tap(
                onTap: () => setState(_q.clear),
                child: Icon(LucideIcons.x, size: 20, color: p.sub),
              ),
          ]),
        ),
      );

  Widget _sortBar(Pal p) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
        child: Row(children: [
          Expanded(
            child: Text.rich(TextSpan(children: [
              TextSpan(text: 'Sorted by ', style: ts(p.text, 15)),
              TextSpan(text: _sorts[_sort], style: ts(p.text, 15, FontWeight.w800)),
            ])),
          ),
          Tap(
            onTap: () => _sortSheet(p),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Icon(LucideIcons.arrowUpDown, size: 22, color: p.text),
            ),
          ),
        ]),
      );

  Widget _people(Pal p, AppState s, bool followers) {
    final ids = followers ? s.followersList(widget.userId) : s.followingList(widget.userId);
    final list = _prepare(s, ids);
    final suggested = (!followers && _q.text.trim().isEmpty)
        ? s.users.values
            .where((u) => u.id != 'me' && !s.following.contains(u.id) && !ids.contains(u.id))
            .take(6)
            .toList()
        : <User>[];
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      cacheExtent: 800,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        _search(p),
        _sortBar(p),
        if (list.isEmpty)
          Empty(
            _q.text.trim().isEmpty ? LucideIcons.users : LucideIcons.search,
            _q.text.trim().isEmpty
                ? (followers ? 'No followers yet' : 'Not following anyone yet')
                : 'No results for “${_q.text.trim()}”',
          )
        else
          for (final u in list) _row(p, s, u, followers: followers),
        if (suggested.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 6),
            child: Text('Suggested for you', style: ts(p.text, 18, FontWeight.w800)),
          ),
          for (final u in suggested) _row(p, s, u, followers: false),
        ],
      ],
    );
  }

  Widget _pill(Pal p, String label, bool filled, VoidCallback onTap) => Tap(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: filled ? p.grad : null,
            borderRadius: BorderRadius.circular(18),
            border: filled ? null : Border.all(color: p.line, width: 1.5),
          ),
          child: Text(label, style: ts(filled ? Colors.white : p.text, 13, FontWeight.w700)),
        ),
      );

  Widget _flagged(Pal p, AppState s) {
    final reqs = s.requests;
    if (reqs.isEmpty) {
      return Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 64, 32, 0),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('No flagged requests', textAlign: TextAlign.center, style: ts(p.text, 22, FontWeight.w800)),
            const SizedBox(height: 10),
            Text(
              'If profiles that are likely to be spam or irrelevant try to follow you, you can delete or confirm them here.',
              textAlign: TextAlign.center,
              style: ts(p.sub, 15, FontWeight.w400, 1.4),
            ),
            const SizedBox(height: 14),
            Text(
              s.isPrivate
                  ? 'New follow requests will show up here.'
                  : 'Your account is public, so new followers are added automatically. Turn on Private account in Settings to review them here.',
              textAlign: TextAlign.center,
              style: ts(p.accent, 14, FontWeight.w600, 1.4),
            ),
          ]),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      children: [
        for (final id in reqs)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              Tap(onTap: () => openProfile(context, id), child: Avatar(s.user(id), 48)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.user(id).handle, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(p.text, 15, FontWeight.w700)),
                  Text(s.user(id).name, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(p.sub, 14)),
                ]),
              ),
              _pill(p, 'Confirm', true, () => s.confirmRequest(id)),
              const SizedBox(width: 8),
              _pill(p, 'Delete', false, () => s.declineRequest(id)),
            ]),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final s = context.s;
    final u = s.user(widget.userId);
    final labels = [
      '${compact(s.followersList(u.id).length)} followers',
      '${compact(s.followingList(u.id).length)} following',
      if (_own) s.requests.isEmpty ? 'Flagged' : 'Flagged (${s.requests.length})',
    ];
    final tab = _tab.clamp(0, labels.length - 1);
    return Scaffold(
      backgroundColor: p.bg,
      body: Column(children: [
        TopBar(u.handle, back: true),
        Container(
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.line))),
          child: Row(children: [
            for (int i = 0; i < labels.length; i++)
              Expanded(
                child: Tap(
                  onTap: () => setState(() {
                    _tab = i;
                    _q.clear();
                    _sort = 0;
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: tab == i ? p.accent : Colors.transparent, width: 3)),
                    ),
                    child: Center(
                      child: Text(labels[i],
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: ts(tab == i ? p.text : p.sub, 14, FontWeight.w700)),
                    ),
                  ),
                ),
              ),
          ]),
        ),
        Expanded(
          child: tab == 2 ? _flagged(p, s) : _people(p, s, tab == 0),
        ),
      ]),
    );
  }
}
