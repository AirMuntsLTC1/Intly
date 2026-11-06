import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../fx.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

class PostDetail extends StatefulWidget {
  final Post post;
  /// Comment to scroll to and highlight (set when opened from a notification).
  final String? highlightId;
  const PostDetail(this.post, {super.key, this.highlightId});
  @override
  State<PostDetail> createState() => _PostDetailState();
}

class _PostDetailState extends State<PostDetail> {
  final _c = TextEditingController();
  final _f = FocusNode();
  Comment? _replyTo;
  final _hlKey = GlobalKey();
  String? _hl;

  @override
  void initState() {
    super.initState();
    _hl = widget.highlightId;
    if (_hl != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealHighlight(0));
    }
  }

  void _revealHighlight(int tries) {
    if (!mounted) return;
    final ctx = _hlKey.currentContext;
    if (ctx == null) {
      if (tries < 10) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _revealHighlight(tries + 1));
      }
      return;
    }
    Scrollable.ensureVisible(ctx,
        alignment: 0.25, duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
    // let the tint fade away after a moment
    Future.delayed(const Duration(milliseconds: 2400), () {
      if (mounted) setState(() => _hl = null);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    _f.dispose();
    super.dispose();
  }

  void _reply(Comment c) {
    setState(() => _replyTo = c);
    _f.requestFocus();
  }

  void _send() {
    final text = _c.text.trim();
    if (text.isEmpty) return;
    final s = context.s;
    final r = _replyTo;
    if (r == null) {
      s.addComment(widget.post, text);
    } else if (r.parent == null) {
      s.addComment(widget.post, text, parent: r.id);
    } else {
      s.addComment(widget.post, text, parent: r.parent, replyToUser: r.userId);
    }
    _c.clear();
    setState(() => _replyTo = null);
    _f.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final s = context.s;
    final all = s.commentsOf(widget.post.id);
    final tops = all.where((c) => c.parent == null).toList()
      ..sort((a, b) => a.minutes.compareTo(b.minutes));
    final items = <Widget>[PostCard(widget.post, detail: true)];
    for (final t in tops) {
      items.add(_Tile(t, widget.post, 0, () => _reply(t),
          key: t.id == widget.highlightId ? _hlKey : null, highlight: t.id == _hl));
      final reps = all.where((c) => c.parent == t.id).toList()
        ..sort((a, b) => b.minutes.compareTo(a.minutes));
      for (final r in reps) {
        items.add(_Tile(r, widget.post, 1, () => _reply(r),
            key: r.id == widget.highlightId ? _hlKey : null, highlight: r.id == _hl));
      }
    }
    final can = _c.text.trim().isNotEmpty;
    return Scaffold(
      backgroundColor: p.bg,
      body: Column(children: [
        const TopBar('Post', back: true),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.zero,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            // build every comment up front when we need to scroll to one
            cacheExtent: widget.highlightId != null ? 4000 : null,
            itemCount: items.length,
            itemBuilder: (c, i) => items[i],
          ),
        ),
        Container(
          decoration: BoxDecoration(color: p.bg, border: Border(top: BorderSide(color: p.line))),
          child: SafeArea(
            top: false,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (_replyTo != null)
                Container(
                  color: p.card,
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                  child: Row(children: [
                    Icon(LucideIcons.reply, size: 16, color: p.accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Replying to ${s.user(_replyTo!.userId).name}',
                          style: ts(p.sub, 13, FontWeight.w600)),
                    ),
                    Tap(
                      onTap: () => setState(() => _replyTo = null),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(LucideIcons.x, size: 18, color: p.sub),
                      ),
                    ),
                  ]),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 10, 8),
                child: Row(children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(22)),
                      child: TextField(
                        controller: _c,
                        focusNode: _f,
                        onChanged: (_) => setState(() {}),
                        style: ts(p.text, 15),
                        cursorColor: p.accent,
                        decoration: InputDecoration.collapsed(
                            hintText: _replyTo == null ? 'Write a comment...' : 'Write a reply...',
                            hintStyle: ts(p.sub, 15)),
                      ),
                    ),
                  ),
                  IconBtn(LucideIcons.send, _send, color: can ? p.accent : p.sub),
                ]),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _Tile extends StatelessWidget {
  final Comment c;
  final Post post;
  final int depth;
  final VoidCallback onReply;
  final bool highlight;
  const _Tile(this.c, this.post, this.depth, this.onReply, {super.key, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final s = context.s;
    final u = s.user(c.userId);
    final isAuthor = c.userId == post.userId;
    final mention = c.replyToUser == null ? null : s.user(c.replyToUser!);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
      padding: EdgeInsets.fromLTRB(16 + depth * 44.0, 12, 16, 8),
      decoration: BoxDecoration(
        color: highlight ? p.accent.withAlpha(34) : Colors.transparent,
        border: depth == 0 ? Border(top: BorderSide(color: p.line)) : null,
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Tap(onTap: () => openProfile(context, u.id), child: Avatar(u, depth == 0 ? 36 : 30)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(u.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: ts(p.text, 14, FontWeight.w700))),
              if (isAuthor) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                      color: p.accent.withAlpha(36), borderRadius: BorderRadius.circular(8)),
                  child: Text('Author', style: ts(p.accent, 10, FontWeight.w800)),
                ),
              ],
              const SizedBox(width: 6),
              Text(timeAgo(c.minutes), style: ts(p.sub, 12)),
            ]),
            const SizedBox(height: 2),
            Text.rich(TextSpan(children: [
              if (mention != null)
                TextSpan(text: '@${mention.handle} ',
                    style: TextStyle(color: p.accent, fontWeight: FontWeight.w700)),
              TextSpan(text: c.text),
            ]), style: ts(p.text, 15, FontWeight.w400, 1.35)),
            Tap(
              onTap: onReply,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('Reply', style: ts(p.sub, 13, FontWeight.w700)),
              ),
            ),
          ]),
        ),
        ReactButton(
          shape: Shape.heart,
          icon: LucideIcons.heart,
          active: s.likedComments.contains(c.id),
          color: p.danger,
          idle: p.sub,
          count: s.commentLikes(c) > 0 ? s.commentLikes(c) : null,
          onTap: () => s.toggleCommentLike(c),
        ),
      ]),
    );
  }
}

