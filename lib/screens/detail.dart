import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

class PostDetail extends StatefulWidget {
  final Post post;
  const PostDetail(this.post, {super.key});
  @override
  State<PostDetail> createState() => _PostDetailState();
}

class _PostDetailState extends State<PostDetail> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final s = context.s;
    final list = s.commentsOf(widget.post.id);
    final can = _c.text.trim().isNotEmpty;
    return Scaffold(
      backgroundColor: p.bg,
      body: Column(children: [
        const TopBar('Post', back: true),
        Expanded(
          child: ListView.builder(
            itemCount: list.length + 1,
            itemBuilder: (c, i) {
              if (i == 0) return PostCard(widget.post, detail: true);
              final cm = list[i - 1];
              final u = s.user(cm.userId);
              return Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.line))),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Tap(onTap: () => openProfile(context, u.id), child: Avatar(u, 36)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text(u.name, style: ts(p.text, 14, FontWeight.w700)),
                        const SizedBox(width: 6),
                        Text(timeAgo(cm.minutes), style: ts(p.sub, 12)),
                      ]),
                      const SizedBox(height: 2),
                      Text(cm.text, style: ts(p.text, 15, FontWeight.w400, 1.35)),
                    ]),
                  ),
                ]),
              );
            },
          ),
        ),
        Container(
          decoration: BoxDecoration(color: p.bg, border: Border(top: BorderSide(color: p.line))),
          padding: const EdgeInsets.fromLTRB(16, 8, 10, 8),
          child: SafeArea(
            top: false,
            child: Row(children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(22)),
                  child: TextField(
                    controller: _c,
                    onChanged: (_) => setState(() {}),
                    style: ts(p.text, 15),
                    cursorColor: p.accent,
                    decoration: InputDecoration.collapsed(
                        hintText: 'Write a comment...', hintStyle: ts(p.sub, 15)),
                  ),
                ),
              ),
              IconBtn(LucideIcons.send, () {
                if (!can) return;
                s.addComment(widget.post, _c.text.trim());
                _c.clear();
                setState(() {});
              }, color: can ? p.accent : p.sub),
            ]),
          ),
        ),
      ]),
    );
  }
}
