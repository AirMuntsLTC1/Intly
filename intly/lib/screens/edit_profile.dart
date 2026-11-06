import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditState();
}

class _EditState extends State<EditProfileScreen> {
  late final TextEditingController _n, _b;
  bool _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_init) {
      _init = true;
      final me = context.s.me;
      _n = TextEditingController(text: me.name);
      _b = TextEditingController(text: me.bio);
    }
  }

  @override
  void dispose() {
    _n.dispose();
    _b.dispose();
    super.dispose();
  }

  Widget _field(Pal p, String label, TextEditingController c, int lines, int maxLen) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: ts(p.sub, 13, FontWeight.w700)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(14)),
            child: TextField(
              controller: c,
              maxLines: lines,
              minLines: 1,
              maxLength: maxLen,
              style: ts(p.text, 16),
              cursorColor: p.accent,
              buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
              decoration: const InputDecoration.collapsed(hintText: ''),
            ),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final s = context.s;
    return Scaffold(
      backgroundColor: p.bg,
      body: Column(children: [
        TopBar('Edit profile', back: true, actions: [
          GradBtn('Save', () {
            s.updateProfile(_n.text, _b.text);
            Navigator.of(context).pop();
          }),
          const SizedBox(width: 6),
        ]),
        Expanded(
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Center(child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Avatar(s.me, 92),
            )),
            _field(p, 'NAME', _n, 1, 40),
            _field(p, 'BIO', _b, 4, 160),
          ]),
        ),
      ]),
    );
  }
}

