import 'package:country_picker/country_picker.dart';

/// Keep in sync with `neetprep_flutter/lib/core/utils/country_iso_resolver.dart`.
abstract final class CountryIsoResolver {
  static String resolveIso2({
    String? countryName,
    String? dialCode,
    String? phone,
    String? storedIso2,
  }) {
    final direct = storedIso2?.trim().toUpperCase() ?? '';
    if (RegExp(r'^[A-Z]{2}$').hasMatch(direct)) return direct;

    final name = countryName?.trim() ?? '';
    if (name.isNotEmpty) {
      final byName = CountryParser.tryParse(name);
      if (byName != null && byName.countryCode.length == 2) {
        return byName.countryCode.toUpperCase();
      }
    }

    final phoneCode = _digitsFromDialOrPhone(dialCode, phone);
    if (phoneCode != null) {
      final byPhone = CountryParser.tryParsePhoneCode(phoneCode);
      if (byPhone != null && byPhone.countryCode.length == 2) {
        return byPhone.countryCode.toUpperCase();
      }
    }

    return '';
  }

  static String flagEmojiFromIso2(String iso2) {
    final code = iso2.trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{2}$').hasMatch(code)) return '';
    final first = code.codeUnitAt(0) - 65 + 0x1F1E6;
    final second = code.codeUnitAt(1) - 65 + 0x1F1E6;
    return String.fromCharCode(first) + String.fromCharCode(second);
  }

  static String? _digitsFromDialOrPhone(String? dialCode, String? phone) {
    final dialDigits = _onlyDigits(dialCode);
    if (dialDigits != null && dialDigits.isNotEmpty) return dialDigits;

    final rawPhone = phone?.trim() ?? '';
    if (!rawPhone.startsWith('+')) return null;
    final digits = rawPhone.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return null;

    for (var len = 3; len >= 1; len--) {
      if (digits.length < len) continue;
      final candidate = digits.substring(0, len);
      if (CountryParser.tryParsePhoneCode(candidate) != null) {
        return candidate;
      }
    }
    return null;
  }

  static String? _onlyDigits(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final digits = trimmed.replaceAll(RegExp(r'[^\d]'), '');
    return digits.isEmpty ? null : digits;
  }
}
