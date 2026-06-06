import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../firestore_db.dart';
import 'admin_email_config.dart';

class AdminEmailSendResult {
  const AdminEmailSendResult({required this.ok, this.error});
  final bool ok;
  final String? error;
}

/// Sends one HTML email through the Satlas email relay (SMTP from server-side).
abstract final class AdminEmailSender {
  static Future<AdminEmailSendResult> send({
    required Map<String, dynamic> settings,
    required String to,
    required String subject,
    required String html,
  }) async {
    final relayUrl = _text(settings['relayUrl'], AdminEmailConfig.defaultRelayUrl);
    if (relayUrl.isEmpty) {
      return const AdminEmailSendResult(
        ok: false,
        error: 'Email relay URL is not configured in Settings.',
      );
    }

    try {
      final response = await http
          .post(
            Uri.parse(relayUrl),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'to': to,
              'subject': subject,
              'html': html,
              'settings': settings,
            }),
          )
          .timeout(const Duration(seconds: 45));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['ok'] == true) {
          return const AdminEmailSendResult(ok: true);
        }
        return AdminEmailSendResult(
          ok: false,
          error: decoded is Map
              ? decoded['error']?.toString() ?? 'Relay rejected send'
              : response.body,
        );
      }
      return AdminEmailSendResult(
        ok: false,
        error: 'Relay HTTP ${response.statusCode}: ${response.body}',
      );
    } catch (e) {
      debugPrint('[TPK][ADMIN][EMAIL] send failed: $e');
      return AdminEmailSendResult(ok: false, error: e.toString());
    }
  }

  static Future<void> logDispatch({
    required String triggerKey,
    required String sourcePath,
    required String audience,
    required String to,
    required String status,
    String? error,
  }) async {
    try {
      await FirestoreDb.instance
          .collection(AdminEmailConfig.dispatchLogsCollection)
          .add({
        'triggerKey': triggerKey,
        'sourcePath': sourcePath,
        'audience': audience,
        'to': to,
        'status': status,
        if (error != null) 'error': error,
        'sentFrom': 'admin_web',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[TPK][ADMIN][EMAIL] log failed: $e');
    }
  }

  static String _text(Object? raw, String fallback) {
    final value = raw?.toString().trim() ?? '';
    return value.isEmpty ? fallback : value;
  }
}
