import 'dart:math';

import 'package:flutter/material.dart';

/// Simple human verification (no third-party API keys required).
class AdminCaptchaField extends StatefulWidget {
  const AdminCaptchaField({
    super.key,
    this.onValidated,
    this.onChallengeChanged,
  });

  /// Called when the answer matches the current challenge.
  final VoidCallback? onValidated;

  /// Called whenever a new challenge is generated (clears prior validation).
  final VoidCallback? onChallengeChanged;

  @override
  State<AdminCaptchaField> createState() => AdminCaptchaFieldState();
}

class AdminCaptchaFieldState extends State<AdminCaptchaField> {
  final _answer = TextEditingController();
  final _random = Random();
  late int _a;
  late int _b;
  bool _validated = false;

  @override
  void initState() {
    super.initState();
    _newChallenge();
  }

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  void _newChallenge() {
    _a = 10 + _random.nextInt(40);
    _b = 1 + _random.nextInt(9);
    _answer.clear();
    _validated = false;
    widget.onChallengeChanged?.call();
  }

  bool get isValidated => _validated;

  bool validate() {
    final expected = _a + _b;
    final entered = int.tryParse(_answer.text.trim());
    final ok = entered == expected;
    setState(() => _validated = ok);
    if (ok) widget.onValidated?.call();
    return ok;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Security check: What is $_a + $_b?',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              tooltip: 'New challenge',
              onPressed: _newChallenge,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _answer,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Answer',
            errorText: _validated || _answer.text.isEmpty
                ? null
                : 'Incorrect answer',
          ),
          onChanged: (_) {
            if (_validated) setState(() => _validated = false);
          },
          onSubmitted: (_) => validate(),
        ),
      ],
    );
  }
}
