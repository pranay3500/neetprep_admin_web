/// Keep in sync with `neetprep_flutter/lib/features/dashboard/utils/update_read_time.dart`.
abstract final class UpdateReadTime {
  static const int wordsPerMinute = 200;
  static const int minMinutes = 1;
  static const int maxMinutes = 30;

  static int estimate({
    required String title,
    required String preview,
    required String content,
    required String priorityLabel,
    bool isBreaking = false,
  }) {
    final plain = _plainText([title, preview, content]);
    final wordCount = _wordCount(plain);

    var minutes = wordCount <= 0
        ? minMinutes
        : (wordCount / wordsPerMinute).ceil();

    minutes += _seriousnessBonus(
      priorityLabel: priorityLabel,
      isBreaking: isBreaking,
      wordCount: wordCount,
    );

    return minutes.clamp(minMinutes, maxMinutes);
  }

  static String _plainText(Iterable<String> parts) {
    final buffer = StringBuffer();
    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      if (buffer.isNotEmpty) buffer.write(' ');
      buffer.write(_stripHtml(trimmed));
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _stripHtml(String raw) {
    return raw
        .replaceAll(
          RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false),
          ' ',
        )
        .replaceAll(
          RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false),
          ' ',
        )
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'&nbsp;', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'&[a-z]+;|&#\d+;'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static int _wordCount(String plain) {
    if (plain.isEmpty) return 0;
    return plain.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  }

  static int _seriousnessBonus({
    required String priorityLabel,
    required bool isBreaking,
    required int wordCount,
  }) {
    var bonus = 0;
    final label =
        isBreaking ? 'BREAKING' : priorityLabel.trim().toUpperCase();
    switch (label) {
      case 'BREAKING':
        bonus += 2;
        break;
      case 'URGENT':
        bonus += 1;
        break;
      case 'IMPORTANT':
        bonus += 1;
        break;
      default:
        break;
    }
    if (wordCount > 600) bonus += 1;
    if (wordCount > 1200) bonus += 2;
    return bonus;
  }
}
