
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
// Shared pieces
// ---------------------------------------------------------------------------

/// Common layout for login, sign-up and password reset.
class AuthScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool back;
  final List<Widget> children;

  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.children,
    this.back = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Scaffold(
      backgroundColor: p.bg,
      body: Column(children: [
        if (back) TopBar(title, back: true),
        Expanded(
          child: SafeArea(
            top: !back,
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Center(
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(gradient: p.grad, shape: BoxShape.circle),
                    child: Icon(icon, size: 34, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 20),
                if (!back) ...[
                  Text(title, textAlign: TextAlign.center, style: ts(p.text, 24, FontWeight.w800)),
                  const SizedBox(height: 6),
                ],
                Text(subtitle,
                    textAlign: TextAlign.center, style: ts(p.sub, 15, FontWeight.w500, 1.4)),
                const SizedBox(height: 26),
                ...children,
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Rounded input with a Lucide icon on the left and an eye toggle for passwords.
class AuthField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool password;
  final TextInputType keyboard;
  final TextInputAction? action;
  final ValueChanged<String>? onSubmitted;
  final int? maxLength;

  const AuthField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
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

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.line),
      ),
      child: Row(children: [
        Icon(widget.icon, size: 20, color: p.sub),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: widget.controller,
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
              hintText: widget.label,
              hintStyle: ts(p.sub, 16),
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
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
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(gradient: p.grad, borderRadius: BorderRadius.circular(16)),
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

/// Error (red) or info (accent) box above a form.
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        Icon(error ? LucideIcons.info : LucideIcons.mail, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: ts(color, 14, FontWeight.w600, 1.3))),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Log in
// ---------------------------------------------------------------------------

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginState();
}

class _LoginState extends State<LoginScreen> {
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
    if (mounted) {
      setState(() {
        _busy = false;
        _error = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Welcome back',
      subtitle: 'Log in to continue to Intly.',
      icon: LucideIcons.logIn,
      children: [
        if (_error != null) AuthNotice(_error!, error: true),
        AuthField(
          controller: _email,
          label: 'Email',
          icon: LucideIcons.mail,
          keyboard: TextInputType.emailAddress,
          action: TextInputAction.next,
        ),
        AuthField(
          controller: _pass,
          label: 'Password',
          icon: LucideIcons.keyRound,
          password: true,
          action: TextInputAction.done,
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 6),
        AuthButton('Log in', _submit, busy: _busy),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          AuthLink('Forgot password?', () => Navigator.of(context).push(slide(const ForgotScreen()))),
          AuthLink('Create account', () => Navigator.of(context).push(slide(const RegisterScreen()))),
        ]),
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
        AuthField(
          controller: _user,
          label: 'Username',
          icon: LucideIcons.atSign,
          action: TextInputAction.next,
        ),
        AuthField(
          controller: _name,
          label: 'Display name',
          icon: LucideIcons.user,
          action: TextInputAction.next,
        ),
        AuthField(
          controller: _email,
          label: 'Email',
          icon: LucideIcons.mail,
          keyboard: TextInputType.emailAddress,
          action: TextInputAction.next,
        ),
        AuthField(
          controller: _pass,
          label: 'Password (8+ characters)',
          icon: LucideIcons.keyRound,
          password: true,
          action: TextInputAction.next,
        ),
        AuthField(
          controller: _pass2,
          label: 'Confirm password',
          icon: LucideIcons.keyRound,
          password: true,
          action: TextInputAction.done,
          onSubmitted: (_) => _sendCode(),
        ),
        const SizedBox(height: 6),
        AuthButton('Send verification code', _sendCode, busy: _busy),
        const SizedBox(height: 10),
        Center(
          child: AuthLink('Already have an account? Log in', () => Navigator.of(context).pop()),
        ),
      ];

  List<Widget> _codeChildren() => [
        if (_info != null) AuthNotice(_info!),
        if (_error != null) AuthNotice(_error!, error: true),
        AuthField(
          controller: _code,
          label: '6-digit code',
          icon: LucideIcons.hash,
          keyboard: TextInputType.number,
          maxLength: 6,
          action: TextInputAction.done,
          onSubmitted: (_) => _verify(),
        ),
        const SizedBox(height: 6),
        AuthButton('Verify and create account', _verify, busy: _busy),
        const SizedBox(height: 10),
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
    return AuthScaffold(
      back: true,
      title: _codeStep ? 'Verify your email' : 'Create account',
      subtitle: _codeStep
          ? 'Enter the code we emailed you to finish creating your account.'
          : 'Pick a username and password to get started.',
      icon: _codeStep ? LucideIcons.mail : LucideIcons.userPlus,
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
          icon: LucideIcons.mail,
          keyboard: TextInputType.emailAddress,
          action: TextInputAction.done,
          onSubmitted: (_) => _sendCode(),
        ),
        const SizedBox(height: 6),
        AuthButton('Send reset code', _sendCode, busy: _busy),
        const SizedBox(height: 10),
        Center(child: AuthLink('Back to log in', () => Navigator.of(context).pop())),
      ];

  List<Widget> _resetChildren() => [
        if (_info != null) AuthNotice(_info!),
        if (_error != null) AuthNotice(_error!, error: true),
        AuthField(
          controller: _code,
          label: '6-digit code',
          icon: LucideIcons.hash,
          keyboard: TextInputType.number,
          maxLength: 6,
          action: TextInputAction.next,
        ),
        AuthField(
          controller: _pass,
          label: 'New password (8+ characters)',
          icon: LucideIcons.keyRound,
          password: true,
          action: TextInputAction.next,
        ),
        AuthField(
          controller: _pass2,
          label: 'Confirm new password',
          icon: LucideIcons.keyRound,
          password: true,
          action: TextInputAction.done,
          onSubmitted: (_) => _reset(),
        ),
        const SizedBox(height: 6),
        AuthButton('Set new password', _reset, busy: _busy),
        const SizedBox(height: 10),
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
    return AuthScaffold(
      back: true,
      title: 'Reset password',
      subtitle: _codeStep
          ? 'Enter the code we emailed you and choose a new password.'
          : 'Enter your account email and we will send you a code.',
      icon: _codeStep ? LucideIcons.keyRound : LucideIcons.mail,
      children: _codeStep ? _resetChildren() : _emailChildren(),
    );
  }
}
