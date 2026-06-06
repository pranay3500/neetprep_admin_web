import 'dart:convert';

import 'package:http/http.dart' as http;

import '../content_library_remote_api.dart';
import '../services/firestore_db.dart';

/// Fetches reading HTML from website API 2 (same source as the mobile app fallback).
class ContentLibraryRemoteContentService {
  static Future<_ImportApiConfig?> _loadConfig() async {
    final snap = await FirestoreDb.instance
        .collection('content_library_imports')
        .doc('config')
        .get();
    final data = snap.data();
    if (data == null) return null;
    final apiUrl = (data['apiUrl'] ?? '').toString().trim();
    if (apiUrl.isEmpty) return null;
    return _ImportApiConfig(
      apiUrl: apiUrl,
      pathTemplate: (data['nodeContentPathTemplate'] ?? '').toString().trim(),
    );
  }

  /// Returns HTML from `/self-study/api/content/{nodeId}` or empty on failure.
  static Future<String> fetchWebsiteContentHtml(String nodeId) async {
    final id = nodeId.trim();
    if (id.isEmpty) return '';

    final config = await _loadConfig();
    if (config == null) return '';

    final treeUri = Uri.tryParse(config.apiUrl);
    if (treeUri == null || !treeUri.hasScheme || !treeUri.hasAuthority) {
      return '';
    }

    final detailUri = buildContentLibraryNodeContentUri(
      contentTreeListUri: treeUri,
      nodeId: id,
      pathTemplate: config.pathTemplate.isEmpty ? null : config.pathTemplate,
    );

    try {
      final resp = await http
          .get(detailUri, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 90));
      if (resp.statusCode < 200 || resp.statusCode > 299) {
        return '';
      }
      final ct = (resp.headers['content-type'] ?? '').toLowerCase();
      if (!ct.contains('application/json')) {
        return '';
      }
      final decoded = jsonDecode(resp.body);
      final normalized = _unwrapPayload(decoded);
      if (normalized is String) {
        return normalized.trim();
      }
      if (normalized is! Map) return '';
      return _pickContentString(Map<String, dynamic>.from(normalized));
    } catch (_) {
      return '';
    }
  }
}

class _ImportApiConfig {
  const _ImportApiConfig({
    required this.apiUrl,
    required this.pathTemplate,
  });

  final String apiUrl;
  final String pathTemplate;
}

dynamic _unwrapPayload(dynamic decoded) {
  var current = _tryDecodeJsonString(decoded);
  for (var i = 0; i < 8; i++) {
    current = _tryDecodeJsonString(current);
    if (current is! Map) {
      return current;
    }
    final m = Map<String, dynamic>.from(current);
    if (m.containsKey('contents')) {
      current = m['contents'];
      continue;
    }
    if (m.containsKey('body')) {
      current = m['body'];
      continue;
    }
    if (m.containsKey('data')) {
      current = m['data'];
      continue;
    }
    if (m.containsKey('result')) {
      current = m['result'];
      continue;
    }
    break;
  }
  return current;
}

String _pickContentString(Map<String, dynamic> m) {
  for (final key in const [
    'content',
    'html',
    'body',
    'markdown',
    'richtext',
    'richText',
    'text',
    'contentSource',
  ]) {
    final v = m[key];
    if (v == null) continue;
    final s = v.toString().trim();
    if (s.isNotEmpty) return s;
  }
  return '';
}

dynamic _tryDecodeJsonString(dynamic value) {
  if (value is String) {
    final t = value.trim();
    if (t.isEmpty || !(t.startsWith('{') || t.startsWith('['))) {
      return value;
    }
    try {
      return jsonDecode(t);
    } catch (_) {
      return value;
    }
  }
  return value;
}
