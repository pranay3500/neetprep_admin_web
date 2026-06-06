import 'dart:convert';

/// Normalizes API 2 payloads before storing in Firestore for the mobile app.
class ContentLibraryBodyCleaner {
  static const _contentKeys = [
    'content',
    'html',
    'body',
    'markdown',
    'richtext',
    'richText',
    'text',
  ];

  /// Extracts display HTML from a decoded API 2 JSON body.
  static String? htmlFromApi2Payload(dynamic decoded) {
    final normalized = _unwrapPayload(decoded);
    if (normalized is String) {
      return sanitizeForFirestore(normalized);
    }
    if (normalized is! Map) return null;
    final m = Map<String, dynamic>.from(normalized);
    final raw = _pickContentString(m);
    if (raw.trim().isEmpty) return null;
    return sanitizeForFirestore(raw);
  }

  static String sanitizeForFirestore(String html) {
    var t = _normalizeEscapedMarkupIfNeeded(html).trim();
    if (t.isEmpty) return '';
    t = t.replaceAll(
      RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false),
      '',
    );
    t = t.replaceAll(
      RegExp(r'<noscript[^>]*>[\s\S]*?</noscript>', caseSensitive: false),
      '',
    );
    t = t.replaceAll(
      RegExp(r'<iframe[^>]*>[\s\S]*?</iframe>', caseSensitive: false),
      '',
    );
    t = t.replaceAll(
      RegExp(r'<object[^>]*>[\s\S]*?</object>', caseSensitive: false),
      '',
    );
    t = t.replaceAll(
      RegExp(r'<embed[^>]*\/?>', caseSensitive: false),
      '',
    );
    return _stripFixedPixelWidthsFromInlineStyles(t.trim());
  }

  /// CMS HTML often sets narrow `width` / `white-space` on wrappers — breaks mobile layout.
  static String _stripFixedPixelWidthsFromInlineStyles(String html) {
    var t = html.replaceAllMapped(
      RegExp(
        r'\b(width|min-width|max-width|height|float|white-space)\s*:\s*[^;"]+;?',
        caseSensitive: false,
      ),
      (_) => '',
    );
    t = t.replaceAll(
      RegExp(r'\s(width|height)\s*=\s*"[^"]*"', caseSensitive: false),
      '',
    );
    return t.replaceAll(
      RegExp(r"\s(width|height)\s*=\s*'[^']*'", caseSensitive: false),
      '',
    );
  }

  static String _normalizeEscapedMarkupIfNeeded(String html) {
    final t = html.trim();
    if (t.isEmpty) return t;
    final escapedLt = '&lt;'.allMatches(t).length +
        RegExp(r'&#60;|&#x3c;', caseSensitive: false).allMatches(t).length;
    if (escapedLt == 0) return t;
    final rawOpens = RegExp(r'<[a-zA-Z!]').allMatches(t).length;
    if (rawOpens >= 3 && rawOpens >= escapedLt) return t;
    return t
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&amp;', '&');
  }

  static String _pickContentString(Map<String, dynamic> m) {
    for (final key in _contentKeys) {
      final v = m[key];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isNotEmpty) return s;
    }
    return '';
  }

  static dynamic _tryDecodeJsonString(dynamic raw) {
    if (raw is String) {
      final t = raw.trim();
      if (t.isEmpty || !(t.startsWith('{') || t.startsWith('['))) return raw;
      try {
        return jsonDecode(t);
      } catch (_) {
        return raw;
      }
    }
    return raw;
  }

  static dynamic _unwrapPayload(dynamic decoded) {
    var current = _tryDecodeJsonString(decoded);
    for (var i = 0; i < 8; i++) {
      current = _tryDecodeJsonString(current);
      if (current is! Map) return current;
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
}
