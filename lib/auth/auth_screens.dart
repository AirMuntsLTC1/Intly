import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme.dart';
import '../widgets.dart';
import 'auth_service.dart';

final _emailRx = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
final _userRx = RegExp(r'^[a-z0-9_.]{3,30}$');
final _codeRx = RegExp(r'^\d{6}$');

bool _emailOk(String e) => e.length <= 254 && _emailRx.hasMatch(e);

// ---------------------------------------------------------------------------
// Shared pieces. No logo or icon badges: the wordmark and plain text do the work.
// ---------------------------------------------------------------------------

/// Layout for every form screen: a back arrow, a large title, a friendly line,
/// then the fields.
class AuthPage extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;

  const AuthPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
            child: Row(children: [
              IconBtn(LucideIcons.arrowLeft, () => Navigator.of(context).maybePop()),
            ]),
          ),
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(title, style: ts(p.text, 30, FontWeight.w900)),
                const SizedBox(height: 8),
                Text(subtitle, style: ts(p.sub, 15, FontWeight.w500, 1.45)),
                const SizedBox(height: 28),
                ...children,
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Rounded input. The label floats above the text, and the border turns to the
/// brand colour while the field is focused.
class AuthField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final bool password;
  final TextInputType keyboard;
  final TextInputAction? action;
  final ValueChanged<String>? onSubmitted;
  final int? maxLength;

  const AuthField({
    super.key,
    required this.controller,
    required this.label,
    this.password = false,
    this.keyboard = TextInputType.text,
    this.action,
    this.onSubmitted,
    this.maxLength,
  });

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  bool _hidden = true;
  final _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (mounted) setState(() => _focused = _focus.hasFocus);
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _focused ? p.accent : p.line, width: _focused ? 1.6 : 1),
      ),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: widget.controller,
            focusNode: _focus,
            obscureText: widget.password && _hidden,
            keyboardType: widget.keyboard,
            textInputAction: widget.action,
            onSubmitted: widget.onSubmitted,
            maxLength: widget.maxLength,
            autocorrect: false,
            enableSuggestions: !widget.password,
            style: ts(p.text, 16),
            cursorColor: p.accent,
            decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              counterText: '',
              labelText: widget.label,
              labelStyle: ts(p.sub, 15),
              floatingLabelStyle: ts(p.accent, 13, FontWeight.w700),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        if (widget.password)
          Tap(
            onTap: () => setState(() => _hidden = !_hidden),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(_hidden ? LucideIcons.eye : LucideIcons.eyeOff, size: 20, color: p.sub),
            ),
          ),
      ]),
    );
  }
}

/// Main action: a filled pill in the brand gradient.
class AuthButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool busy;

  const AuthButton(this.label, this.onTap, {super.key, this.busy = false});

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final enabled = onTap != null && !busy;
    return Opacity(
      opacity: enabled ? 1 : .6,
      child: Tap(
        onTap: enabled ? onTap : null,
        child: Container(
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: p.grad,
            borderRadius: BorderRadius.circular(27),
            boxShadow: [
              BoxShadow(color: p.accent.withAlpha(60), blurRadius: 18, offset: const Offset(0, 8)),
            ],
          ),
          child: busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                )
              : Text(label, style: ts(Colors.white, 16, FontWeight.w800)),
        ),
      ),
    );
  }
}

/// Secondary action: an outlined pill.
class AuthOutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const AuthOutlineButton(this.label, this.onTap, {super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Tap(
      onTap: onTap,
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: p.bg,
          borderRadius: BorderRadius.circular(27),
          border: Border.all(color: p.accent, width: 1.6),
        ),
        child: Text(label, style: ts(p.accent, 16, FontWeight.w800)),
      ),
    );
  }
}

class AuthLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const AuthLink(this.label, this.onTap, {super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Tap(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Text(label, style: ts(p.accent, 14, FontWeight.w700)),
      ),
    );
  }
}

/// A calm message above a form: red for errors, brand colour for information.
class AuthNotice extends StatelessWidget {
  final String text;
  final bool error;

  const AuthNotice(this.text, {super.key, this.error = false});

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final color = error ? p.danger : p.accent;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(text, style: ts(color, 14, FontWeight.w600, 1.35)),
    );
  }
}

// ---------------------------------------------------------------------------
// Welcome: the first screen a signed-out person sees
// ---------------------------------------------------------------------------

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _WelcomeState();
}

class _WelcomeState extends State<LoginScreen> {
  static const _slides = <(String, String)>[
    ('Share your moments', 'Post photos and videos, and let the people you care about see them.'),
    ('Follow people you love', 'Build your circle and see what they share first.'),
    ('Watch and make reels', 'Short videos from friends, made with a few taps.'),
  ];

  final _pages = PageController();
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // Moves to the next tagline on its own; swiping still works.
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_pages.hasClients) return;
      _pages.animateToPage(
        (_index + 1) % _slides.length,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Scaffold(
      backgroundColor: p.bg,
      body: Stack(children: [
        Positioned.fill(child: _Backdrop(p: p)),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(children: [
              const Spacer(flex: 2),
              ShaderMask(
                shaderCallback: (r) => p.grad.createShader(r),
                child: Text(
                  'Intly',
                  textAlign: TextAlign.center,
                  style: ts(Colors.white, 72, FontWeight.w900).copyWith(letterSpacing: -2),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 120,
                child: PageView.builder(
                  controller: _pages,
                  itemCount: _slides.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (_, i) => Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_slides[i].$1,
                          textAlign: TextAlign.center, style: ts(p.text, 22, FontWeight.w800)),
                      const SizedBox(height: 8),
                      Text(_slides[i].$2,
                          textAlign: TextAlign.center, style: ts(p.sub, 15, FontWeight.w500, 1.4)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (var i = 0; i < _slides.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _index ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _index ? p.accent : p.line,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ]),
              const Spacer(flex: 3),
              AuthButton('Create account', () => Navigator.of(context).push(slide(const RegisterScreen()))),
              const SizedBox(height: 12),
              AuthOutlineButton('Sign in', () => Navigator.of(context).push(slide(const SignInScreen()))),
              const SizedBox(height: 28),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// Soft brand-coloured background with a few faded shapes. Drop a photo in
/// here later if you want one behind the wordmark.
class _Backdrop extends StatelessWidget {
  final Pal p;
  const _Backdrop({required this.p});

  Widget _blob(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );

  @override
  Widget build(BuildContext context) => Stack(children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [p.accent.withAlpha(60), p.accent2.withAlpha(40), p.bg],
              stops: const [0, .45, 1],
            ),
          ),
        ),
        Positioned(top: -90, right: -70, child: _blob(260, p.accent2.withAlpha(55))),
        Positioned(top: 170, left: -110, child: _blob(230, p.accent.withAlpha(45))),
      ]);
}

// ---------------------------------------------------------------------------
// Sign in
// ---------------------------------------------------------------------------

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInState();
}

class _SignInState extends State<SignInScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final pass = _pass.text;
    if (!_emailOk(email)) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    if (pass.isEmpty) {
      setState(() => _error = 'Enter your password.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    String? err;
    try {
      await AuthService.signIn(email: email, password: pass);
    } on AuthFailure catch (e) {
      err = e.message;
    } catch (_) {
      err = 'Could not log in. Please try again.';
    }
    if (!mounted) return;
    if (err == null) {
      // Signed in: close the login pages and show home.
      Navigator.of(context).popUntil((r) => r.isFirst);
      return;
    }
    setState(() {
      _busy = false;
      _error = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AuthPage(
      title: 'Welcome back',
      subtitle: 'Good to see you again. Log in to keep going.',
      children: [
        if (_error != null) AuthNotice(_error!, error: true),
        AuthField(
          controller: _email,
          label: 'Email',
          keyboard: TextInputType.emailAddress,
          action: TextInputAction.next,
        ),
        AuthField(
          controller: _pass,
          label: 'Password',
          password: true,
          action: TextInputAction.done,
          onSubmitted: (_) => _submit(),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: AuthLink('Forgot password?', () => Navigator.of(context).push(slide(const ForgotScreen()))),
        ),
        const SizedBox(height: 10),
        AuthButton('Log in', _submit, busy: _busy),
        const SizedBox(height: 22),
        Center(
          child: AuthLink(
            'New to Intly? Create an account',
            () => Navigator.of(context).pushReplacement(slide(const RegisterScreen())),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Create account: details, then the 6-digit email code
// ---------------------------------------------------------------------------

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterState();
}

class _RegisterState extends State<RegisterScreen> {
  final _user = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();
  final _code = TextEditingController();
  bool _codeStep = false;
  bool _busy = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    for (final c in [_user, _name, _email, _pass, _pass2, _code]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Runs [action] and returns true when it worked. Errors appear under the form.
  Future<bool> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    String? err;
    var ok = false;
    try {
      await action();
      ok = true;
    } on AuthFailure catch (e) {
      err = e.message;
    } catch (_) {
      err = 'Something went wrong. Please try again.';
    }
    if (mounted) {
      setState(() {
        _busy = false;
        _error = err;
      });
    }
    return ok;
  }

  Future<void> _sendCode() async {
    final username = _user.text.trim().toLowerCase();
    final name = _name.text.trim();
    final email = _email.text.trim();
    final pass = _pass.text;
    String? problem;
    if (!_userRx.hasMatch(username)) {
      problem = 'Username: 3 to 30 letters, numbers, dots or underscores.';
    } else if (name.isEmpty) {
      problem = 'Enter a display name.';
    } else if (!_emailOk(email)) {
      problem = 'Enter a valid email address.';
    } else if (pass.length < 8) {
      problem = 'Password must be at least 8 characters.';
    } else if (pass != _pass2.text) {
      problem = 'The passwords do not match.';
    }
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    final ok = await _run(() => AuthService.requestSignupCode(
          username: username,
          displayName: name,
          email: email,
        ));
    if (ok && mounted) {
      setState(() {
        _codeStep = true;
        _info = 'We sent a 6-digit code to $email.';
      });
    }
  }

  Future<void> _resend() async {
    if (_busy) return;
    final email = _email.text.trim();
    final ok = await _run(() => AuthService.requestSignupCode(
          username: _user.text.trim().toLowerCase(),
          displayName: _name.text.trim(),
          email: email,
        ));
    if (ok && mounted) setState(() => _info = 'A new code was sent to $email.');
  }

  Future<void> _verify() async {
    final code = _code.text.trim();
    if (!_codeRx.hasMatch(code)) {
      setState(() => _error = 'Enter the 6-digit code from your email.');
      return;
    }
    final ok = await _run(() => AuthService.confirmSignup(
          email: _email.text.trim(),
          code: code,
          password: _pass.text,
        ));
    // Logged in: the app shows the feed underneath, so close these pages.
    if (ok && mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  List<Widget> _formChildren() => [
        if (_error != null) AuthNotice(_error!, error: true),
        AuthField(controller: _user, label: 'Username', action: TextInputAction.next),
        AuthField(controller: _name, label: 'Display name', action: TextInputAction.next),
        AuthField(
          controller: _email,
          label: 'Email',
          keyboard: TextInputType.emailAddress,
          action: TextInputAction.next,
        ),
        AuthField(
          controller: _pass,
          label: 'Password (8+ characters)',
          password: true,
          action: TextInputAction.next,
        ),
        AuthField(
          controller: _pass2,
          label: 'Confirm password',
          password: true,
          action: TextInputAction.done,
          onSubmitted: (_) => _sendCode(),
        ),
        const SizedBox(height: 8),
        AuthButton('Send verification code', _sendCode, busy: _busy),
        const SizedBox(height: 18),
        Center(
          child: AuthLink(
            'Already have an account? Log in',
            () => Navigator.of(context).pushReplacement(slide(const SignInScreen())),
          ),
        ),
      ];

  List<Widget> _codeChildren() => [
        if (_info != null) AuthNotice(_info!),
        if (_error != null) AuthNotice(_error!, error: true),
        AuthField(
          controller: _code,
          label: '6-digit code',
          keyboard: TextInputType.number,
          maxLength: 6,
          action: TextInputAction.done,
          onSubmitted: (_) => _verify(),
        ),
        const SizedBox(height: 8),
        AuthButton('Verify and create account', _verify, busy: _busy),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          AuthLink('Resend code', _resend),
          AuthLink('Change details', () {
            setState(() {
              _codeStep = false;
              _info = null;
              _error = null;
            });
          }),
        ]),
      ];

  @override
  Widget build(BuildContext context) {
    return AuthPage(
      title: _codeStep ? 'Check your email' : 'Create your account',
      subtitle: _codeStep
          ? 'Enter the code we just sent you to finish creating your account.'
          : 'It only takes a minute. We will email you a code to confirm it is you.',
      children: _codeStep ? _codeChildren() : _formChildren(),
    );
  }
}

// ---------------------------------------------------------------------------
// Forgot password: email code, then a new password
// ---------------------------------------------------------------------------

class ForgotScreen extends StatefulWidget {
  const ForgotScreen({super.key});

  @override
  State<ForgotScreen> createState() => _ForgotState();
}

class _ForgotState extends State<ForgotScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();
  bool _codeStep = false;
  bool _busy = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    for (final c in [_email, _code, _pass, _pass2]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<bool> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    String? err;
    var ok = false;
    try {
      await action();
      ok = true;
    } on AuthFailure catch (e) {
      err = e.message;
    } catch (_) {
      err = 'Something went wrong. Please try again.';
    }
    if (mounted) {
      setState(() {
        _busy = false;
        _error = err;
      });
    }
    return ok;
  }

  Future<void> _sendCode() async {
    final email = _email.text.trim();
    if (!_emailOk(email)) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    final ok = await _run(() async {
      _info = await AuthService.requestResetCode(email);
    });
    if (ok && mounted) setState(() => _codeStep = true);
  }

  Future<void> _resend() async {
    if (_busy) return;
    final ok = await _run(() async {
      _info = await AuthService.requestResetCode(_email.text.trim());
    });
    if (ok && mounted) setState(() {});
  }

  Future<void> _reset() async {
    final code = _code.text.trim();
    final pass = _pass.text;
    String? problem;
    if (!_codeRx.hasMatch(code)) {
      problem = 'Enter the 6-digit code from your email.';
    } else if (pass.length < 8) {
      problem = 'New password must be at least 8 characters.';
    } else if (pass != _pass2.text) {
      problem = 'The passwords do not match.';
    }
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    final email = _email.text.trim();
    final ok = await _run(() async {
      _info = await AuthService.confirmReset(email: email, code: code, password: pass);
    });
    if (ok && mounted) {
      toast(context, 'Password updated.');
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  List<Widget> _emailChildren() => [
        if (_error != null) AuthNotice(_error!, error: true),
        AuthField(
          controller: _email,
          label: 'Email',
          keyboard: TextInputType.emailAddress,
          action: TextInputAction.done,
          onSubmitted: (_) => _sendCode(),
        ),
        const SizedBox(height: 8),
        AuthButton('Send reset code', _sendCode, busy: _busy),
        const SizedBox(height: 18),
        Center(child: AuthLink('Back to log in', () => Navigator.of(context).pop())),
      ];

  List<Widget> _resetChildren() => [
        if (_info != null) AuthNotice(_info!),
        if (_error != null) AuthNotice(_error!, error: true),
        AuthField(
          controller: _code,
          label: '6-digit code',
          keyboard: TextInputType.number,
          maxLength: 6,
          action: TextInputAction.next,
        ),
        AuthField(
          controller: _pass,
          label: 'New password (8+ characters)',
          password: true,
          action: TextInputAction.next,
        ),
        AuthField(
          controller: _pass2,
          label: 'Confirm new password',
          password: true,
          action: TextInputAction.done,
          onSubmitted: (_) => _reset(),
        ),
        const SizedBox(height: 8),
        AuthButton('Set new password', _reset, busy: _busy),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          AuthLink('Resend code', _resend),
          AuthLink('Change email', () {
            setState(() {
              _codeStep = false;
              _info = null;
              _error = null;
            });
          }),
        ]),
      ];

  @override
  Widget build(BuildContext context) {
    return AuthPage(
      title: _codeStep ? 'Choose a new password' : 'Forgot your password?',
      subtitle: _codeStep
          ? 'Enter the code we emailed you, then pick a new password.'
          : 'No worries. Enter your email and we will send you a code.',
      children: _codeStep ? _resetChildren() : _emailChildren(),
    );
  }
}
