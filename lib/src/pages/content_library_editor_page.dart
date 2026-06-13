import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../content_library/content_library_published_service.dart';
import '../content_library/content_library_remote_content_service.dart';
import '../content_library/content_library_tree.dart';
import '../services/firestore_db.dart';
import '../widgets/content_library_html_editor.dart';

/// CMS editor: tree from API 1 import → write HTML → publish to Firestore for the app.
class ContentLibraryEditorPage extends StatefulWidget {
  const ContentLibraryEditorPage({super.key});

  @override
  State<ContentLibraryEditorPage> createState() =>
      _ContentLibraryEditorPageState();
}

class _ContentLibraryEditorPageState extends State<ContentLibraryEditorPage> {
  String? _selectedWebsiteId;
  String _selectedTitle = '';
  String _selectedType = '';
  String _status = 'draft';
  bool _loadingDoc = false;
  bool _saving = false;
  String? _message;
  String? _error;
  int _editorMountGeneration = 0;

  final _htmlController = TextEditingController();

  static Future<String> _buildStamp() async {
    if (!kIsWeb) return '';
    try {
      final uri = Uri.base.resolve('version.json');
      final res = await http.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode != 200) return 'version.json missing on server';
      final body = res.body.trim();
      if (body.length > 120) return '${body.substring(0, 120)}…';
      return body;
    } catch (e) {
      return '';
    }
  }

  @override
  void dispose() {
    _htmlController.dispose();
    super.dispose();
  }

  Future<void> _selectNode(ContentLibraryTreeNode node) async {
    final id = node.websiteId;
    if (id == null) {
      setState(() {
        _error = 'This row has no website id — import the tree with API ids first.';
        _message = null;
      });
      return;
    }
    setState(() {
      _selectedWebsiteId = id;
      _selectedTitle = node.title;
      _selectedType = node.type;
      _loadingDoc = true;
      _error = null;
      _message = null;
      _htmlController.text = '';
    });
    try {
      final data = await ContentLibraryPublishedService.load(id);
      if (!mounted) return;

      var html = (data?['contentSource'] ?? '').toString().trim();
      var loadedFrom = 'firestore';

      if (html.isEmpty) {
        html = await ContentLibraryRemoteContentService.fetchWebsiteContentHtml(
          id,
        );
        if (html.isNotEmpty) {
          loadedFrom = 'website';
        }
      }

      _htmlController.text = html;
      setState(() {
        _status = (data?['status'] ?? 'draft').toString();
        _loadingDoc = false;
        _editorMountGeneration++;
        if (html.isEmpty) {
          _message =
              'No content in Firestore or website API for this section. '
              'Import the tree and check API 2 in Content Library Import.';
        } else if (loadedFrom == 'website') {
          _message =
              'Loaded from website API (same as mobile). Edit and Publish to save to CMS.';
        } else {
          _message = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingDoc = false;
        _error = 'Could not load: $e';
      });
    }
  }

  Future<void> _save(String status) async {
    final id = _selectedWebsiteId;
    if (id == null) return;
    setState(() {
      _saving = true;
      _error = null;
      _message = null;
    });
    try {
      await ContentLibraryPublishedService.save(
        nodeId: id,
        title: _selectedTitle,
        type: _selectedType,
        contentHtml: _htmlController.text,
        status: status,
      );
      if (!mounted) return;
      setState(() {
        _status = status;
        _saving = false;
        _message = status == 'published'
            ? 'Published — mobile app will show this content for this section.'
            : 'Draft saved.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Save failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Content Library Editor',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          FutureBuilder<String>(
            future: _buildStamp(),
            builder: (context, snap) {
              final stamp = snap.data;
              if (stamp == null || stamp.isEmpty) return const SizedBox.shrink();
              return Text(
                'Build: $stamp',
                style: GoogleFonts.robotoMono(
                  fontSize: 10,
                  color: Colors.grey.shade500,
                ),
              );
            },
          ),
          const SizedBox(height: 4),
          Text(
            'Select a unit, chapter, topic, or sub-topic. Edit visually on the page or paste HTML in the source tab, then Publish.',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: const Color(0xFF616161),
            ),
          ),
          if (_message != null) ...[
            const SizedBox(height: 10),
            _banner(_message!, const Color(0xFF2E7D32), Icons.check_circle_outline),
          ],
          if (_error != null) ...[
            const SizedBox(height: 10),
            _banner(_error!, const Color(0xFFC62828), Icons.error_outline),
          ],
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 300,
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: _TreePanel(
                      selectedId: _selectedWebsiteId,
                      onSelect: _selectNode,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: _selectedWebsiteId == null
                        ? Center(
                            child: Text(
                              'Select a section from the tree',
                              style: GoogleFonts.poppins(
                                color: Colors.grey.shade600,
                              ),
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  14,
                                  16,
                                  8,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _selectedTitle,
                                            style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 16,
                                            ),
                                          ),
                                          Text(
                                            '${_selectedType} · id: $_selectedWebsiteId',
                                            style: GoogleFonts.poppins(
                                              fontSize: 11,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Chip(
                                      label: Text(
                                        _status == 'published'
                                            ? 'Published'
                                            : 'Draft',
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      backgroundColor: _status == 'published'
                                          ? const Color(0xFFC8E6C9)
                                          : const Color(0xFFECEFF1),
                                    ),
                                    const SizedBox(width: 8),
                                    OutlinedButton(
                                      onPressed: _saving
                                          ? null
                                          : () => _save('draft'),
                                      child: const Text('Save draft'),
                                    ),
                                    const SizedBox(width: 8),
                                    FilledButton(
                                      onPressed: _saving
                                          ? null
                                          : () => _save('published'),
                                      child: Text(
                                        _saving ? 'Saving…' : 'Publish',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_loadingDoc)
                                const LinearProgressIndicator(minHeight: 2),
                              Expanded(
                                child: _loadingDoc
                                    ? const Center(
                                        child: Text('Loading content…'),
                                      )
                                    : ContentLibraryHtmlEditor(
                                        key: ValueKey(
                                          '$_selectedWebsiteId-$_editorMountGeneration',
                                        ),
                                        controller: _htmlController,
                                      ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _banner(String text, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _TreePanel extends StatelessWidget {
  const _TreePanel({
    required this.selectedId,
    required this.onSelect,
  });

  final String? selectedId;
  final void Function(ContentLibraryTreeNode node) onSelect;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirestoreDb.instance
          .collection('content_library_imports')
          .doc('main')
          .snapshots(),
      builder: (context, mainSnap) {
        if (mainSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final importId = mainSnap.data?.data()?['importId']?.toString();
        if (importId == null || importId.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Import the content tree first (Content Library Import → Fetch & Import).',
            ),
          );
        }
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirestoreDb.instance
              .collection('content_library_import_nodes')
              .where('importId', isEqualTo: importId)
              .snapshots(),
          builder: (context, nodesSnap) {
            if (nodesSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final flat = (nodesSnap.data?.docs ?? [])
                .map((d) => ContentLibraryFlatNode.fromMap(d.data()))
                .toList();
            var roots = ContentLibraryTreeBuilder.buildHierarchy(flat);
            roots = ContentLibraryTreeBuilder.unwrapPlanningShell(roots);
            if (roots.isEmpty) {
              return const Center(child: Text('No tree nodes in this import.'));
            }
            return ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                for (final unit in roots)
                  _TreeTile(
                    node: unit,
                    depth: 0,
                    selectedId: selectedId,
                    onSelect: onSelect,
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _TreeTile extends StatelessWidget {
  const _TreeTile({
    required this.node,
    required this.depth,
    required this.selectedId,
    required this.onSelect,
  });

  final ContentLibraryTreeNode node;
  final int depth;
  final String? selectedId;
  final void Function(ContentLibraryTreeNode node) onSelect;

  @override
  Widget build(BuildContext context) {
    final id = node.websiteId;
    final selected = id != null && id == selectedId;
    final hasChildren = node.children.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: id != null ? () => onSelect(node) : null,
          child: Container(
            padding: EdgeInsets.fromLTRB(12 + depth * 14.0, 8, 8, 8),
            color: selected ? const Color(0xFFE8EAF6) : null,
            child: Row(
              children: [
                Icon(
                  id == null ? Icons.link_off : Icons.description_outlined,
                  size: 16,
                  color: id == null ? Colors.grey : const Color(0xFF5E35B1),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    node.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                if (hasChildren)
                  Icon(Icons.folder_outlined, size: 14, color: Colors.grey.shade600),
              ],
            ),
          ),
        ),
        for (final child in node.children)
          _TreeTile(
            node: child,
            depth: depth + 1,
            selectedId: selectedId,
            onSelect: onSelect,
          ),
      ],
    );
  }
}
