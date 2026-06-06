/// Tree nodes from Content Library API 1 import (`content_library_import_nodes`).
class ContentLibraryFlatNode {
  const ContentLibraryFlatNode({
    required this.nodeId,
    required this.importId,
    required this.parentId,
    required this.title,
    required this.type,
    required this.depth,
    required this.siblingIndex,
    this.sourceId,
  });

  final String nodeId;
  final String importId;
  final String? parentId;
  final String title;
  final String type;
  final int depth;
  final int siblingIndex;
  final String? sourceId;

  String? get websiteId => sourceId?.trim().isEmpty == true ? null : sourceId?.trim();

  factory ContentLibraryFlatNode.fromMap(Map<String, dynamic> map) {
    return ContentLibraryFlatNode(
      nodeId: (map['nodeId'] ?? '').toString(),
      importId: (map['importId'] ?? '').toString(),
      parentId: map['parentId']?.toString(),
      title: (map['title'] ?? 'Untitled').toString(),
      type: (map['type'] ?? 'item').toString(),
      depth: (map['depth'] as num?)?.toInt() ?? 0,
      siblingIndex: (map['siblingIndex'] as num?)?.toInt() ?? 0,
      sourceId: map['sourceId']?.toString(),
    );
  }
}

class ContentLibraryTreeNode {
  const ContentLibraryTreeNode({
    required this.title,
    required this.type,
    required this.children,
    this.sourceId,
  });

  final String title;
  final String type;
  final String? sourceId;
  final List<ContentLibraryTreeNode> children;

  String? get websiteId =>
      sourceId?.trim().isEmpty == true ? null : sourceId?.trim();
}

class ContentLibraryTreeBuilder {
  static List<ContentLibraryTreeNode> buildHierarchy(
    List<ContentLibraryFlatNode> flatNodes,
  ) {
    if (flatNodes.isEmpty) return const [];

    final byId = <String, _Mutable>{};
    final roots = <_Mutable>[];
    final sorted = [...flatNodes]
      ..sort((a, b) {
        final d = a.depth.compareTo(b.depth);
        if (d != 0) return d;
        return a.siblingIndex.compareTo(b.siblingIndex);
      });

    for (final node in sorted) {
      final m = _Mutable(
        title: node.title,
        type: node.type,
        siblingIndex: node.siblingIndex,
        sourceId: node.sourceId,
      );
      byId[node.nodeId] = m;
      if (node.parentId == null || !byId.containsKey(node.parentId)) {
        roots.add(m);
      } else {
        byId[node.parentId]!.children.add(m);
      }
    }

    void sortChildren(_Mutable n) {
      n.children.sort((a, b) => a.siblingIndex.compareTo(b.siblingIndex));
      for (final c in n.children) {
        sortChildren(c);
      }
    }

    roots.sort((a, b) => a.siblingIndex.compareTo(b.siblingIndex));
    for (final r in roots) {
      sortChildren(r);
    }
    return roots.map((e) => e.toTreeNode()).toList();
  }

  /// Skips a single "NEET Planning" shell so units are top-level in the editor.
  static List<ContentLibraryTreeNode> unwrapPlanningShell(
    List<ContentLibraryTreeNode> roots,
  ) {
    if (roots.length != 1) return roots;
    final sole = roots.first;
    final t = sole.title.trim().toLowerCase();
    if ((t.contains('neet planning') || t.contains('planning')) &&
        sole.children.isNotEmpty) {
      return sole.children;
    }
    return roots;
  }
}

class _Mutable {
  _Mutable({
    required this.title,
    required this.type,
    required this.siblingIndex,
    this.sourceId,
  });

  final String title;
  final String type;
  final int siblingIndex;
  final String? sourceId;
  final List<_Mutable> children = [];

  ContentLibraryTreeNode toTreeNode() {
    return ContentLibraryTreeNode(
      title: title,
      type: type,
      sourceId: sourceId,
      children: children.map((e) => e.toTreeNode()).toList(),
    );
  }
}
