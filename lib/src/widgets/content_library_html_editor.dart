import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'content_library_visual_editor_stub.dart'
    if (dart.library.html) 'content_library_visual_editor_web.dart';

/// Content Library CMS editor — visual edit + HTML source.
class ContentLibraryHtmlEditor extends StatefulWidget {
  const ContentLibraryHtmlEditor({
    super.key,
    required this.controller,
    this.minHeight = 320,
  });

  final TextEditingController controller;
  final double minHeight;

  @override
  State<ContentLibraryHtmlEditor> createState() =>
      _ContentLibraryHtmlEditorState();
}

class _ContentLibraryHtmlEditorState extends State<ContentLibraryHtmlEditor>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  bool _htmlFromVisual = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this, initialIndex: 0);
    _tabs.addListener(_onTabChanged);
    widget.controller.addListener(_onHtmlChanged);
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChanged);
    widget.controller.removeListener(_onHtmlChanged);
    _tabs.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabs.indexIsChanging) return;
    setState(() {});
    if (_tabs.index == 1) {
      // Entering visual tab — iframe will receive latest html via active prop.
    } else {
      _focusNode.requestFocus();
    }
  }

  void _onHtmlChanged() {
    if (_tabs.index == 1 && !_htmlFromVisual) {
      setState(() {});
    }
  }

  void _onVisualHtmlChanged(String html) {
    if (widget.controller.text == html) return;
    _htmlFromVisual = true;
    widget.controller.text = html;
    _htmlFromVisual = false;
  }

  void _insertSnippet(String snippet) {
    final controller = widget.controller;
    final text = controller.text;
    final selection = controller.selection;
    final start = selection.start >= 0 ? selection.start : text.length;
    final end = selection.end >= 0 ? selection.end : text.length;
    final updated = text.replaceRange(start, end, snippet);
    controller.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: start + snippet.length),
    );
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final mono = GoogleFonts.robotoMono(fontSize: 13, height: 1.45);
    final visualActive = _tabs.index == 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Text(
            'Use Visual edit to change content on the page (like a document). '
            'Use Edit HTML to paste or fine-tune raw HTML. Publish saves to Firestore.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF616161),
                ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: TabBar(
            controller: _tabs,
            labelStyle: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: GoogleFonts.poppins(fontSize: 13),
            tabs: const [
              Tab(text: 'Edit HTML'),
              Tab(text: 'Visual edit'),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SnippetToolbar(onInsert: _insertSnippet),
                    const SizedBox(height: 8),
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE0E0E0)),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.white,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Scrollbar(
                            controller: _scrollController,
                            thumbVisibility: true,
                            child: TextField(
                              controller: widget.controller,
                              focusNode: _focusNode,
                              scrollController: _scrollController,
                              maxLines: null,
                              expands: true,
                              keyboardType: TextInputType.multiline,
                              textInputAction: TextInputAction.newline,
                              style: mono,
                              decoration: const InputDecoration(
                                hintText: '<p>Paste or edit HTML source…</p>',
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.all(14),
                                isDense: true,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE0E0E0)),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: ContentLibraryVisualEditor(
                      html: widget.controller.text,
                      active: visualActive,
                      onHtmlChanged: _onVisualHtmlChanged,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SnippetToolbar extends StatelessWidget {
  const _SnippetToolbar({required this.onInsert});

  final void Function(String snippet) onInsert;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF5F5F5),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Wrap(
          spacing: 2,
          runSpacing: 2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _tool(Icons.title, 'Heading 2', () => onInsert('<h2>Heading</h2>\n')),
            _tool(Icons.title_outlined, 'Heading 3', () => onInsert('<h3>Subheading</h3>\n')),
            _tool(Icons.format_bold, 'Bold', () => onInsert('<strong>text</strong>')),
            _tool(Icons.format_italic, 'Italic', () => onInsert('<em>text</em>')),
            _tool(Icons.format_underlined, 'Underline', () => onInsert('<u>text</u>')),
            _tool(Icons.format_list_bulleted, 'Bullet list', () {
              onInsert('<ul>\n  <li>Item</li>\n</ul>\n');
            }),
            _tool(Icons.format_list_numbered, 'Numbered list', () {
              onInsert('<ol>\n  <li>Item</li>\n</ol>\n');
            }),
            _tool(Icons.link, 'Link', () {
              onInsert('<a href="https://">link text</a>');
            }),
            _tool(Icons.table_chart_outlined, 'Table', () {
              onInsert(
                '<table>\n'
                '  <thead><tr><th>Column</th></tr></thead>\n'
                '  <tbody><tr><td>Cell</td></tr></tbody>\n'
                '</table>\n',
              );
            }),
            _tool(Icons.horizontal_rule, 'Divider', () => onInsert('<hr />\n')),
            _tool(Icons.notes, 'Paragraph', () => onInsert('<p>Paragraph</p>\n')),
          ],
        ),
      ),
    );
  }

  Widget _tool(IconData icon, String tooltip, VoidCallback onPressed) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    );
  }
}
