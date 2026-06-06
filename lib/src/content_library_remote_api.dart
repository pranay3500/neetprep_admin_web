/// Remote Content Library endpoints (TestprepKart self-study CMS).
///
/// **API 1 — hierarchy / tree** (mobile + admin importer):
/// Full URL example:
/// `https://www.testprepkart.com/self-study/api/tree/content/neet/neet-planning`
/// Stored in admin Firestore `content_library_imports/config` as `apiUrl`.
///
/// **API 2 — node reading body** (mobile section detail + admin node preview):
/// Default is a **path template** relative to API 1’s origin (scheme + host + port).
/// Placeholder: `{nodeId}` (URL-encoded when built). Alias `{id}` is accepted.
///
/// To point API 2 at another host later, save a **full URL** template in admin, e.g.
/// `https://other-host.example/api/v2/node/{nodeId}`.
const String kDefaultContentLibraryNodeContentPathTemplate =
    '/self-study/api/content/{nodeId}';

/// Builds the HTTP GET URI for API 2 from the tree list [contentTreeListUri] and template.
///
/// [pathTemplate] should include `{nodeId}` or `{id}` once, or be empty (then
/// [kDefaultContentLibraryNodeContentPathTemplate] is used).
Uri buildContentLibraryNodeContentUri({
  required Uri contentTreeListUri,
  required String nodeId,
  String? pathTemplate,
}) {
  final encoded = Uri.encodeComponent(nodeId.trim());
  var resolved = (pathTemplate ?? '').trim();
  if (resolved.isEmpty) {
    resolved = kDefaultContentLibraryNodeContentPathTemplate;
  }
  resolved = resolved
      .replaceAll('{nodeId}', encoded)
      .replaceAll('{id}', encoded);
  if (resolved.startsWith('http://') || resolved.startsWith('https://')) {
    return Uri.parse(resolved);
  }
  if (!resolved.startsWith('/')) {
    resolved = '/$resolved';
  }
  return contentTreeListUri.resolve(resolved);
}
