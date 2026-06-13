import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Non-web fallback — visual editing is web-only.
class ContentLibraryVisualEditor extends StatelessWidget {
  const ContentLibraryVisualEditor({
    super.key,
    required this.html,
    required this.onHtmlChanged,
    this.active = true,
  });

  final String html;
  final void Function(String html) onHtmlChanged;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Visual editing is available in the web admin (Chrome). '
          'Use the Edit HTML tab, or run: flutter run -d chrome',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: Colors.grey.shade700,
          ),
        ),
      ),
    );
  }
}
