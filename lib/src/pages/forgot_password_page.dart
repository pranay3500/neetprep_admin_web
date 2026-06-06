import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../admin_auth_constants.dart';
import '../services/admin_auth_eligibility.dart';
import '../widgets/admin_captcha_field.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _captchaKey = GlobalKey<AdminCaptchaFieldState>();
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _sendRecovery() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!(_captchaKey.currentState?.validate() ?? false)) {
      _showMessage('Please complete the security check correctly.');
      return;
    }

    final email = AdminAuthEligibility.normalizeEmail(_email.text);
    setState(() => _loading = true);
    try {
      final registered = await AdminAuthEligibility.isRegisteredAdminEmail(email);
      if (!registered) {
        _showMessage(
          'This email is not registered for admin access. No recovery email was sent.',
          isError: true,
        );
        return;
      }

      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: email,
        actionCodeSettings: ActionCodeSettings(
          url: AdminAuthConstants.passwordResetContinueUrl,
          handleCodeInApp: false,
        ),
      );

      _showMessage(
        'A password reset link was sent to your registered email address.',
      );
      if (mounted) Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      var msg = e.message ?? 'Unable to send recovery email.';
      if (e.code == 'invalid-email') {
        msg = 'Please enter a valid email address.';
      } else if (e.code == 'too-many-requests') {
        msg = 'Too many requests. Please wait and try again later.';
      }
      _showMessage(msg, isError: true);
    } catch (e) {
      _showMessage('Unable to send recovery email: $e', isError: true);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recover password')),
      body: Center(
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
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Reset admin password',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Recovery is only sent to emails registered for admin access. '
                        'If your email is not on file, no message is sent.',
                        style: TextStyle(color: Colors.black54, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _email,
                        decoration: const InputDecoration(
                          labelText: 'Admin email',
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          final value = v?.trim() ?? '';
                          if (value.isEmpty) return 'Email is required';
                          if (!value.contains('@')) return 'Enter a valid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      AdminCaptchaField(key: _captchaKey),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _loading ? null : _sendRecovery,
                        child: Text(
                          _loading ? 'Sending...' : 'Send recovery link',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _loading
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('Back to sign in'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
