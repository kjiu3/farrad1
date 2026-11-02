import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../l10n.dart';

/// شاشة الدخول/الجلسة (قرار المالك 2026-11-02، فق ADR-0009 §1).
///
/// مستخدِم مسجّل: الحالة وزر الخروج. مجهول: نموذج دخول/تسجيل
/// بكلمة مرور، والتبديل بينهما زر نصي. المفاتيح كلها مركّبة
/// (`Key('auth_…')`) ليثبتها الاختبار بلا مواضع مشتقة هشّة.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.strings, required this.service});

  final AppStrings strings;
  final AuthService service;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _signUpMode = false;
  bool _busy = false;
  String? _errorKey;

  String _s(String key) => widget.strings.get(key);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() => _errorKey = null);
    if (!email.contains('@') || email.isEmpty) {
      setState(() => _errorKey = 'authInvalidEmail');
      return;
    }
    // الحد الأدنى نفسه في Supabase (gotrue) — نطابق الواجهة والخدمة.
    if (password.length < 6) {
      setState(() => _errorKey = 'authPasswordTooShort');
      return;
    }

    setState(() => _busy = true);
    final outcome = _signUpMode
        ? await widget.service.signUp(email, password)
        : await widget.service.signIn(email, password);
    if (!mounted) return;
    if (outcome.ok) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _busy = false;
      _errorKey = outcome.errorKey ?? 'authFailed';
    });
  }

  Future<void> _signOut() async {
    setState(() => _busy = true);
    await widget.service.signOut();
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    // تُقرأ من الخدمة في كل بناء؛ الدخول/الخروج يعيد بناء الجلسة بعد pop.
    final signedIn = widget.service.userId != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _s(signedIn
              ? 'authSignedIn'
              : (_signUpMode ? 'authSignUp' : 'authSignIn')),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: signedIn
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(_s('authSignedIn')),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    key: const Key('auth_signout'),
                    onPressed: _busy ? null : _signOut,
                    icon: const Icon(Icons.logout),
                    label: Text(_s('authSignOut')),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    key: const Key('auth_email'),
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(labelText: _s('authEmail')),
                  ),
                  TextField(
                    key: const Key('auth_password'),
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: _s('authPassword'),
                    ),
                  ),
                  if (_errorKey != null)
                    Padding(
                      key: const Key('auth_error'),
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _s(_errorKey!),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  FilledButton(
                    key: const Key('auth_submit'),
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _s(_signUpMode ? 'authSignUp' : 'authSignIn'),
                          ),
                  ),
                  TextButton(
                    key: const Key('auth_switch'),
                    onPressed: () => setState(() {
                      _signUpMode = !_signUpMode;
                      _errorKey = null;
                    }),
                    child: Text(
                      _s(_signUpMode ? 'authSwitchToSignIn' : 'authSwitchToSignUp'),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
