import 'package:flutter/material.dart';

import 'ckeditor/content_library_ckeditor_stub.dart'
    if (dart.library.html) 'ckeditor/content_library_ckeditor_web.dart';

/// Content Library CMS editor — CKEditor 5 on web, HTML textarea fallback elsewhere.
class ContentLibraryHtmlEditor extends StatelessWidget {
  const ContentLibraryHtmlEditor({
    super.key,
    required this.controller,
    this.minHeight = 320,
  });

  final TextEditingController controller;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    return ContentLibraryCkEditorView(
      controller: controller,
      minHeight: minHeight,
    );
  }
}
