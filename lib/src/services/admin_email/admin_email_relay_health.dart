import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'admin_email_config.dart';

class AdminEmailRelayHealthResult {
  const AdminEmailRelayHealthResult({
    required this.reachable,
    required this.message,
    this.runtime,
  });

  final bool reachable;
  final String message;
  final String? runtime;
}

/// Checks whether the deployed email relay responds (not the Flutter SPA).
abstract final class AdminEmailRelayHealth {
  static String healthUrlFor(String relayUrl) {
    final trimmed = relayUrl.trim();
    if (trimmed.isEmpty) {
      return '${AdminEmailConfig.defaultRelayUrl.replaceAll('send-email', 'health')}';
    }
    if (trimmed.endsWith('send-email')) {
      return '${trimmed.substring(0, trimmed.length - 'send-email'.length)}health';
    }
    final uri = Uri.parse(trimmed);
    return uri.replace(path: '/api/health').toString();
  }

  static Future<AdminEmailRelayHealthResult> check(String relayUrl) async {
    final url = healthUrlFor(relayUrl);
    if (url.isEmpty) {
      return const AdminEmailRelayHealthResult(
        reachable: false,
        message: 'Email relay URL is empty.',
      );
    }

    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 12));

      final body = response.body.trim();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return AdminEmailRelayHealthResult(
          reachable: false,
          message: 'Relay health HTTP ${response.statusCode}',
        );
      }

      try {
        final decoded = jsonDecode(body);
        if (decoded is Map && decoded['ok'] == true) {
          return AdminEmailRelayHealthResult(
            reachable: true,
            message: 'Relay online (${decoded['runtime'] ?? 'ok'})',
            runtime: decoded['runtime']?.toString(),
          );
        }
      } catch (_) {
        // Not JSON — likely SPA index.html when relay is not deployed.
      }

      if (body.contains('<!DOCTYPE html>') ||
          body.contains('neetprep_admin_web') ||
          body.contains('flutter')) {
        return const AdminEmailRelayHealthResult(
          reachable: false,
          message:
              'Relay not deployed — /api/health returned the admin app instead of the email API. '
              'Upload web/email-api/*.php and updated .htaccess, then rebuild.',
        );
      }

      return AdminEmailRelayHealthResult(
        reachable: false,
        message: 'Unexpected health response: ${body.length > 120 ? '${body.substring(0, 120)}…' : body}',
      );
    } catch (e) {
      debugPrint('[TPK][ADMIN][EMAIL] relay health failed: $e');
      return AdminEmailRelayHealthResult(
        reachable: false,
        message: 'Could not reach relay: $e',
      );
    }
  }
}

class AdminEmailConfigCheck {
  const AdminEmailConfigCheck({
    required this.ready,
    required this.issues,
  });

  final bool ready;
  final List<String> issues;

  static AdminEmailConfigCheck fromSettings(Map<String, dynamic> settings) {
    final issues = <String>[];

    if (settings['masterEnabled'] != true) {
      issues.add('Turn on Email Configuration (master switch).');
    }

    final fromEmail = settings['fromEmail']?.toString().trim() ?? '';
    if (!fromEmail.contains('@')) {
      issues.add('Set a valid From Email.');
    }

    final provider = settings['provider']?.toString() ?? 'SMTP';
    if (provider == 'SMTP') {
      final smtp = settings['smtp'] is Map
          ? Map<String, dynamic>.from(settings['smtp'] as Map)
          : <String, dynamic>{};
      if ((smtp['host']?.toString().trim() ?? '').isEmpty) {
        issues.add('Set SMTP host (e.g. smtp.hostinger.com).');
      }
      if ((smtp['username']?.toString().trim() ?? '').isEmpty) {
        issues.add('Set SMTP username.');
      }
      if ((smtp['password']?.toString().trim() ?? '').isEmpty) {
        issues.add('Set SMTP password / app password.');
      }
    } else if (provider == 'SendGrid') {
      final api = settings['api'] is Map
          ? Map<String, dynamic>.from(settings['api'] as Map)
          : <String, dynamic>{};
      if ((api['apiKey']?.toString().trim() ?? '').isEmpty) {
        issues.add('Set SendGrid API key.');
      }
    }

    final admins = settings['adminRecipients'];
    final hasAdmin = admins is List
        ? admins.any((e) => e.toString().contains('@'))
        : admins.toString().contains('@');
    if (!hasAdmin) {
      issues.add('Add at least one admin alert recipient email.');
    }

    return AdminEmailConfigCheck(
      ready: issues.isEmpty,
      issues: issues,
    );
  }
}
