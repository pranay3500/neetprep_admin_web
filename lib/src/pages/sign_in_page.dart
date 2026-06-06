import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/admin_auth_eligibility.dart';
import '../services/admin_login_security_service.dart';
import '../widgets/admin_captcha_field.dart';
import '../widgets/testprepkart_logo.dart';
import 'forgot_password_page.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _captchaKey = GlobalKey<AdminCaptchaFieldState>();
  bool _loading = false;
  bool _checkingLock = false;
  String? _lockMessage;

  @override
  void initState() {
    super.initState();
    _email.addListener(_onEmailChanged);
  }

  @override
  void dispose() {
    _email.removeListener(_onEmailChanged);
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _onEmailChanged() {
    final email = _email.text.trim();
    if (email.isEmpty) {
      if (_lockMessage != null) setState(() => _lockMessage = null);
      return;
    }
    _refreshLockStatus(email);
  }

  Future<void> _refreshLockStatus(String email) async {
    setState(() => _checkingLock = true);
    try {
      final status = await AdminLoginSecurityService.checkLockout(email);
      if (!mounted) return;
      setState(() {
        _lockMessage = status.isLocked
            ? AdminLoginSecurityService.lockoutMessage(status)
            : null;
        _checkingLock = false;
      });
    } catch (_) {
      if (mounted) setState(() => _checkingLock = false);
    }
  }

  Future<void> _signIn() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final email = AdminAuthEligibility.normalizeEmail(_email.text);

    final lock = await AdminLoginSecurityService.checkLockout(email);
    if (lock.isLocked) {
      _showMessage(AdminLoginSecurityService.lockoutMessage(lock), isError: true);
      setState(() => _lockMessage = AdminLoginSecurityService.lockoutMessage(lock));
      return;
    }

    if (!(_captchaKey.currentState?.validate() ?? false)) {
      _showMessage('Please complete the security check correctly.', isError: true);
      return;
    }

    final registered = await AdminAuthEligibility.isRegisteredAdminEmail(email);
    if (!registered) {
      await AdminLoginSecurityService.recordFailedAttempt(email);
      _showMessage(
        'This email is not authorized for admin access. '
        'Register on the mobile app first, then ask the owner to grant moderator access on App Users.',
        isError: true,
      );
      await _refreshLockStatus(email);
      return;
    }

    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: _password.text,
      );
      await AdminLoginSecurityService.clearFailures(email);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' ||
          e.code == 'invalid-credential' ||
          e.code == 'user-not-found' ||
          e.code == 'invalid-email') {
        await AdminLoginSecurityService.recordFailedAttempt(email);
        await _refreshLockStatus(email);
        final afterLock = await AdminLoginSecurityService.checkLockout(email);
        if (afterLock.isLocked) {
          _showMessage(
            AdminLoginSecurityService.lockoutMessage(afterLock),
            isError: true,
          );
        } else {
          _showMessage('Invalid email or password.', isError: true);
        }
      } else if (e.code == 'too-many-requests') {
        _showMessage(
          'Too many attempts. Please wait and try again later.',
          isError: true,
        );
      } else {
        _showMessage(e.message ?? 'Sign-in failed.', isError: true);
      }
    } catch (e) {
      _showMessage('Sign-in failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMessage(String text, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? const Color(0xFFC62828) : null,
      ),
    );
  }

  void _openForgotPassword() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ForgotPasswordPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locked = _lockMessage != null;

    return Scaffold(
      body: Stack(
        children: [
          const Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: TestprepKartLogo(height: 36, maxWidth: 180),
            ),
          ),
          Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Admin Sign In',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Use the same email and password as the mobile app — not a Firebase UID.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (kIsWeb) ...[
                        Material(
                          color: const Color(0xFFE3F2FD),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Text(
                              'Local dev: Chrome often opens http://127.0.0.1:PORT — '
                              'add 127.0.0.1 under Firebase → Authentication → '
                              'Settings → Authorized domains (in addition to localhost).',
                              style: TextStyle(
                                fontSize: 11,
                                height: 1.35,
                                color: Colors.blue.shade900,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (_lockMessage != null) ...[
                        Material(
                          color: const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.lock_clock_rounded,
                                  color: Color(0xFFC62828),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _lockMessage!,
                                    style: const TextStyle(
                                      color: Color(0xFFB71C1C),
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextFormField(
                        controller: _email,
                        enabled: !_loading,
                        decoration: const InputDecoration(labelText: 'Email'),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          final value = v?.trim() ?? '';
                          if (value.isEmpty) return 'Email is required';
                          if (!value.contains('@')) return 'Enter a valid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _password,
                        enabled: !_loading && !locked,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Password'),
                        validator: (v) {
                          if ((v ?? '').isEmpty) return 'Password is required';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      AdminCaptchaField(key: _captchaKey),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: (_loading || locked || _checkingLock)
                            ? null
                            : _signIn,
                        child: Text(_loading ? 'Signing in...' : 'Sign in'),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _loading ? null : _openForgotPassword,
                          child: const Text('Forgot password?'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
          ),
        ],
      ),
    );
  }
}
