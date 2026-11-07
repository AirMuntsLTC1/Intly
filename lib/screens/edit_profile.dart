import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/intly_repository.dart';
import '../media_picker.dart';
import '../native.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

/// The name and the @username can each change once every 7 days. The database
/// enforces this too, so the app check is only there to explain it early.
const int kCooldownDays = 7;

/// Whole days until a change is allowed again, or null when it is allowed now.
int? cooldownDaysLeft(DateTime? changedAt) {
  if (changedAt == null) return null;
  final left = changedAt.add(const Duration(days: kCooldownDays)).difference(DateTime.now());
  if (left.inSeconds <= 0) return null;
  return (left.inHours / 24).ceil();
}

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditState();
}

class _EditState extends State<EditProfileScreen> {
  TextEditingController? _n, _u, _b;
  bool _init = false;
  bool _saving = false;
  Timer? _debounce;
  String _checked = ''; // the username the last availability answer is about
  bool? _available;
  bool _checking = false;
  bool _loadingIdeas = false;
  List<String> _ideas = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_init) {
      _init = true;
      final me = context.s.me;
      _n = TextEditingController(text: me.name);
      _u = TextEditingController(text: me.handle);
      _b = TextEditingController(text: me.bio);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _n?.dispose();
    _u?.dispose();
    _b?.dispose();
    super.dispose();
  }

  String get _userText =>
      (_u?.text ?? '').trim().toLowerCase().replaceFirst(RegExp(r'^@'), '');

  void _onUsernameChanged(String _) {
    _debounce?.cancel();
    final v = _userText;
    setState(() {
      _checked = '';
      _available = null;
      _checking = false;
    });
    if (!Native.validUsername(v) || v == context.s.me.handle) return;
    _debounce = Timer(const Duration(milliseconds: 380), () => _check(v));
  }

  Future<void> _check(String v) async {
    if (!mounted) return;
    setState(() => _checking = true);
    try {
      final ok = await IntlyRepo.isUsernameAvailable(v);
      if (!mounted || _userText != v) return;
      setState(() {
        _available = ok;
        _checked = v;
        _checking = false;
      });
      if (!ok) _loadIdeas(v);
    } catch (_) {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _loadIdeas(String base) async {
    if (!mounted) return;
    setState(() => _loadingIdeas = true);
    List<String> list;
    try {
      list = await IntlyRepo.suggestUsernames(base);
    } catch (_) {
      list = const [];
    }
    // Offline, or the server returned nothing: use the C++ generator.
    if (list.isEmpty) list = Native.usernameHints(base);
    if (!mounted) return;
    setState(() {
      _ideas = list;
      _loadingIdeas = false;
    });
  }

  void _useIdea(String idea) {
    _u!.value = TextEditingValue(
      text: idea,
      selection: TextSelection.collapsed(offset: idea.length),
    );
    _onUsernameChanged(idea);
  }

  Future<void> _pickAvatar(AppState s) async {
    final m = await pickMedia(context, lib: MediaLibrary.I);
    if (m == null || !mounted) return;
    if (m.video != null) {
      toast(context, 'Choose a photo for your profile picture');
      return;
    }
    s.updateAvatar(m.image);
  }

  Future<void> _save(AppState s) async {
    if (_saving) return;
    final name = _n!.text.trim();
    final user = _userText;
    final bio = _b!.text.trim();
    final nameChanged = (name.isEmpty ? 'You' : name) != s.me.name;
    final userChanged = user != s.me.handle;

    if (nameChanged) {
      final left = cooldownDaysLeft(s.me.nameChangedAt);
      if (left != null) {
        toast(context, 'You can change your name again in $left day${left == 1 ? '' : 's'}');
        return;
      }
    }
    if (userChanged) {
      if (!Native.validUsername(user)) {
        toast(context, 'Usernames use 3–30 letters, numbers, dots or underscores');
        return;
      }
      final left = cooldownDaysLeft(s.me.usernameChangedAt);
      if (left != null) {
        toast(context, 'You can change your username again in $left day${left == 1 ? '' : 's'}');
        return;
      }
      if (_checked != user || _available != true) {
        toast(context, 'Wait for the username check, or pick a suggestion');
        return;
      }
    }

    setState(() => _saving = true);
    try {
      await s.saveProfile(name: name, bio: bio, username: userChanged ? user : null);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) toast(context, IntlyRepo.describe(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field({
    required Pal p,
    required String label,
    required TextEditingController c,
    required int lines,
    required int maxLen,
    bool enabled = true,
    String? prefix,
    String? hint,
    ValueChanged<String>? onChanged,
    Widget? helper,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: ts(p.sub, 13, FontWeight.w700)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              if (prefix != null) ...[
                Text(prefix, style: ts(p.sub, 16, FontWeight.w600)),
                const SizedBox(width: 2),
              ],
              Expanded(
                child: TextField(
                  controller: c,
                  enabled: enabled,
                  maxLines: lines,
                  minLines: 1,
                  maxLength: maxLen,
                  onChanged: onChanged,
                  style: ts(enabled ? p.text : p.sub, 16),
                  cursorColor: p.accent,
                  buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                  decoration: InputDecoration.collapsed(hintText: hint),
                ),
              ),
            ]),
          ),
          if (helper != null) Padding(padding: const EdgeInsets.only(top: 6, left: 4), child: helper),
        ]),
      );

  Widget _note(Pal p, String text, {Color? color, bool bold = false}) => Text(text,
      style: ts(color ?? p.sub, 12, bold ? FontWeight.w700 : FontWeight.w400));

  Widget _usernameStatus(Pal p, AppState s) {
    final v = _userText;
    if (v.isEmpty) return _note(p, 'Letters, numbers, dots and underscores. 3–30 characters.');
    if (!Native.validUsername(v)) {
      return _note(p, 'Only letters, numbers, dots and underscores (3–30).', color: p.danger);
    }
    if (v == s.me.handle) return _note(p, 'This is your current username.');
    if (_checking || _checked != v) return _note(p, 'Checking…');
    if (_available == true) {
      return _note(p, '✓ @$v is available', color: const Color(0xFF2EC27E), bold: true);
    }
    return _note(p, '@$v is taken', color: p.danger, bold: true);
  }

  Widget _ideasBox(Pal p) {
    final typedName = _n?.text.trim() ?? '';
    final base = typedName.isNotEmpty ? typedName : _userText;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('Suggestions', style: ts(p.sub, 13, FontWeight.w700)),
        const Spacer(),
        Tap(
          onTap: base.isEmpty || _loadingIdeas ? null : () => _loadIdeas(base),
          child: Text(_loadingIdeas ? 'Loading…' : 'Get suggestions',
              style: ts(p.accent, 13, FontWeight.w700)),
        ),
      ]),
      if (_ideas.isNotEmpty) ...[
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final idea in _ideas)
            Tap(
              onTap: () => _useIdea(idea),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: p.card,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: p.line),
                ),
                child: Text('@$idea', style: ts(p.text, 13, FontWeight.w700)),
              ),
            ),
        ]),
      ],
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final s = context.s;
    final nameLeft = cooldownDaysLeft(s.me.nameChangedAt);
    final userLeft = cooldownDaysLeft(s.me.usernameChangedAt);
    return Scaffold(
      backgroundColor: p.bg,
      body: Column(children: [
        TopBar('Edit profile', back: true, actions: [
          GradBtn(_saving ? 'Saving…' : 'Save', _saving ? null : () => _save(s)),
          const SizedBox(width: 6),
        ]),
        Expanded(
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Center(
              child: Tap(
                onTap: () => _pickAvatar(s),
                child: Stack(clipBehavior: Clip.none, children: [
                  Avatar(s.me, 96),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        gradient: p.grad,
                        shape: BoxShape.circle,
                        border: Border.all(color: p.bg, width: 2),
                      ),
                      child: const Icon(LucideIcons.camera, size: 15, color: Colors.white),
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Tap(
                onTap: () => _pickAvatar(s),
                child: Text('Change profile photo', style: ts(p.accent, 14, FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 22),
            _field(
              p: p,
              label: 'NAME',
              c: _n!,
              lines: 1,
              maxLen: 40,
              enabled: nameLeft == null,
              helper: _note(
                p,
                nameLeft == null
                    ? 'You can change your name once every 7 days.'
                    : 'Name locked. You can change it again in $nameLeft day${nameLeft == 1 ? '' : 's'}.',
              ),
            ),
            _field(
              p: p,
              label: 'USERNAME',
              c: _u!,
              lines: 1,
              maxLen: 30,
              prefix: '@',
              enabled: userLeft == null,
              onChanged: _onUsernameChanged,
              helper: userLeft == null
                  ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _usernameStatus(p, s),
                      const SizedBox(height: 10),
                      _ideasBox(p),
                    ])
                  : _note(
                      p,
                      'Username locked. You can change it again in $userLeft day${userLeft == 1 ? '' : 's'}.',
                    ),
            ),
            _field(p: p, label: 'BIO', c: _b!, lines: 4, maxLen: 160),
          ]),
        ),
      ]),
    );
  }
}
