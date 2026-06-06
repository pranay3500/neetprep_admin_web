import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/account_deletion_request_service.dart';
import '../widgets/admin_captcha_field.dart';
import '../widgets/testprepkart_logo.dart';

/// Public page (no admin login) for Google Play account-deletion URL requirement.
class UnsubscribePage extends StatefulWidget {
  const UnsubscribePage({super.key});

  @override
  State<UnsubscribePage> createState() => _UnsubscribePageState();
}

class _UnsubscribePageState extends State<UnsubscribePage> {
  final _email = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _captchaKey = GlobalKey<AdminCaptchaFieldState>();
  bool _submitting = false;
  bool _submitted = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!(_captchaKey.currentState?.validate() ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete the verification check.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await AccountDeletionRequestService.submitPublicRequest(_email.text);
      if (!mounted) return;
      setState(() => _submitted = true);
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.code == 'permission-denied'
                ? 'Unable to submit right now. Please email support@testprepkart.com.'
                : 'Unable to submit. Please try again later.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to submit. Please try again later.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const purple = Color(0xFF5E35B1);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F3FA),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Material(
                elevation: 2,
                shadowColor: Colors.black12,
                borderRadius: BorderRadius.circular(16),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 32, 28, 36),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(
                        child: TestprepKartLogo(height: 40, maxWidth: 220),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Account deletion request',
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: purple,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'TestprepKart NEET Admission & Counseling App',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _sectionTitle('How to request account deletion'),
                      const SizedBox(height: 8),
                      ...const [
                        'Enter the email address you used to register in the app.',
                        'Tap Submit request. Our team will verify your identity and process deletion within 30 days.',
                        'You may also sign in to the app and use Profile → Security → Sign out, then contact support if you need help.',
                      ].map(
                        (s) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('• ', style: TextStyle(height: 1.45)),
                              Expanded(
                                child: Text(
                                  s,
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    height: 1.45,
                                    color: const Color(0xFF424242),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _sectionTitle('Data deleted or retained'),
                      const SizedBox(height: 8),
                      Text(
                        'When your account is deleted, we remove or anonymize your profile '
                        '(name, email, phone, grade, country, visa type), app preferences, '
                        'favourites, message threads, demo and subscription requests tied to your account, '
                        'and eligibility attempts linked to your user ID.',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          height: 1.5,
                          color: const Color(0xFF424242),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'We may retain minimal records where required by law (for example payment '
                        'or tax records) or anonymized analytics for up to 90 days, after which they '
                        'are deleted or aggregated without personal identifiers.',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          height: 1.5,
                          color: const Color(0xFF616161),
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (_submitted) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFA5D6A7)),
                          ),
                          child: Text(
                            'Your request has been received. If an account exists for this email, '
                            'our team will contact you to confirm deletion. You do not need to submit again.',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              height: 1.45,
                              color: const Color(0xFF2E7D32),
                            ),
                          ),
                        ),
                      ] else ...[
                        Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextFormField(
                                controller: _email,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.done,
                                decoration: InputDecoration(
                                  labelText: 'Registered email address',
                                  hintText: 'you@example.com',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                validator: (v) {
                                  final value = (v ?? '').trim();
                                  if (value.isEmpty) {
                                    return 'Email is required';
                                  }
                                  if (!AccountDeletionRequestService
                                      .isValidEmail(value)) {
                                    return 'Enter a valid email address';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              AdminCaptchaField(key: _captchaKey),
                              const SizedBox(height: 20),
                              FilledButton(
                                onPressed: _submitting ? null : _submit,
                                style: FilledButton.styleFrom(
                                  backgroundColor: purple,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _submitting
                                    ? const SizedBox(
                                        height: 22,
                                        width: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        'Submit request',
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ],
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

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF5E35B1),
      ),
    );
  }
}
