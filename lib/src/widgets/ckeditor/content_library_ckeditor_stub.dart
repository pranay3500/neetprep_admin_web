import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Fallback when not running on web (CKEditor is web-only).
class ContentLibraryCkEditorView extends StatelessWidget {
  const ContentLibraryCkEditorView({
    super.key,
    required this.controller,
    this.minHeight = 320,
  });

  final TextEditingController controller;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            'CKEditor is available in the web admin (Chrome). Run: flutter run -d chrome',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: const Color(0xFF616161),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: TextField(
              controller: controller,
              maxLines: null,
              expands: true,
              style: GoogleFonts.robotoMono(fontSize: 13),
              decoration: const InputDecoration(
                hintText: '<p>HTML fallback…</p>',
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
