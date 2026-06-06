import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../firestore_db.dart';
import 'admin_email_config.dart';
import 'admin_email_sender.dart';
import 'admin_email_templates.dart';

class AdminEmailRecipient {
  const AdminEmailRecipient({
    required this.email,
    this.userId,
    this.userName,
    this.studentName,
  });

  final String email;
  final String? userId;
  final String? userName;
  final String? studentName;
}

/// Sends transactional emails from the admin web app via the HTTP relay.
class AdminEmailDispatcher {
  AdminEmailDispatcher._();
  static final AdminEmailDispatcher instance = AdminEmailDispatcher._();

  Map<String, dynamic>? _cachedSettings;
  DateTime? _settingsLoadedAt;

  Future<Map<String, dynamic>> loadSettings({bool force = false}) async {
    if (!force &&
        _cachedSettings != null &&
        _settingsLoadedAt != null &&
        DateTime.now().difference(_settingsLoadedAt!) <
            const Duration(minutes: 2)) {
      return _cachedSettings!;
    }
    final snap = await FirestoreDb.instance
        .doc(AdminEmailConfig.settingsPath)
        .get();
    _cachedSettings = snap.data() ?? {};
    _settingsLoadedAt = DateTime.now();
    return _cachedSettings!;
  }

  void invalidateSettingsCache() => _cachedSettings = null;

  Future<bool> _alreadySent(String dedupeKey) async {
    final snap = await FirestoreDb.instance
        .collection(AdminEmailConfig.sentMarkersCollection)
        .doc(dedupeKey)
        .get();
    return snap.exists;
  }

  Future<void> _markSent(String dedupeKey, Map<String, dynamic> meta) async {
    await FirestoreDb.instance
        .collection(AdminEmailConfig.sentMarkersCollection)
        .doc(dedupeKey)
        .set({
      ...meta,
      'sentAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> dispatch({
    required String triggerKey,
    required String sourcePath,
    required Map<String, String> payload,
    required List<AdminEmailRecipient> userRecipients,
    bool sendAdmin = true,
  }) async {
    final settings = await loadSettings();
    if (settings['masterEnabled'] != true) {
      debugPrint('[TPK][ADMIN][EMAIL] skipped (master off) $triggerKey');
      return;
    }

    final triggers = _map(settings['triggers']);
    if (triggers[triggerKey] == false) {
      debugPrint('[TPK][ADMIN][EMAIL] skipped (trigger off) $triggerKey');
      return;
    }

    final appName = _text(settings['senderName'], 'TestprepKart NEET');
    final base = <String, String>{
      'appName': appName,
      'actionUrl': payload['actionUrl'] ?? AdminEmailConfig.adminWebBaseUrl,
      ...payload,
    };

    for (final recipient in userRecipients) {
      if (recipient.email.isEmpty) continue;
      final dedupe =
          '${triggerKey}_${sourcePath}_user_${recipient.email.toLowerCase()}';
      if (await _alreadySent(dedupe)) continue;

      final merged = <String, String>{
        ...base,
        'email': recipient.email,
        'userName': recipient.userName ?? recipient.studentName ?? 'there',
        'studentName': recipient.studentName ?? recipient.userName ?? '',
      };
      final ok = await _sendOne(
        settings: settings,
        triggerKey: triggerKey,
        sourcePath: sourcePath,
        audience: 'user',
        to: recipient.email,
        payload: merged,
      );
      if (ok) {
        await _markSent(dedupe, {
          'triggerKey': triggerKey,
          'sourcePath': sourcePath,
          'audience': 'user',
          'to': recipient.email,
        });
      }
    }

    if (!sendAdmin) return;
    final adminList = _adminEmails(settings);
    for (final email in adminList) {
      final dedupe =
          '${triggerKey}_${sourcePath}_admin_${email.toLowerCase()}';
      if (await _alreadySent(dedupe)) continue;
      final merged = <String, String>{...base, 'email': email};
      final ok = await _sendOne(
        settings: settings,
        triggerKey: triggerKey,
        sourcePath: sourcePath,
        audience: 'admin',
        to: email,
        payload: merged,
      );
      if (ok) {
        await _markSent(dedupe, {
          'triggerKey': triggerKey,
          'sourcePath': sourcePath,
          'audience': 'admin',
          'to': email,
        });
      }
    }
  }

  Future<bool> _sendOne({
    required Map<String, dynamic> settings,
    required String triggerKey,
    required String sourcePath,
    required String audience,
    required String to,
    required Map<String, String> payload,
  }) async {
    final templates = _map(settings['templates']);
    final triggerTemplates = _map(templates[triggerKey]);
    final audienceTemplate = _map(triggerTemplates[audience]);
    final subjectTemplate = _text(
      audienceTemplate['subject'],
      AdminEmailTemplates.defaultSubject(triggerKey, audience),
    );
    final htmlTemplate = _text(
      audienceTemplate['html'],
      AdminEmailTemplates.defaultHtml(triggerKey, audience),
    );

    final subject = AdminEmailTemplates.render(subjectTemplate, payload);
    final html = AdminEmailTemplates.render(htmlTemplate, payload);

    final result = await AdminEmailSender.send(
      settings: settings,
      to: to,
      subject: subject,
      html: html,
    );

    await AdminEmailSender.logDispatch(
      triggerKey: triggerKey,
      sourcePath: sourcePath,
      audience: audience,
      to: to,
      status: result.ok ? 'sent' : 'failed',
      error: result.error,
    );

    if (!result.ok) {
      debugPrint(
        '[TPK][ADMIN][EMAIL] failed $triggerKey → $to: ${result.error}',
      );
    }
    return result.ok;
  }

  static Future<List<AdminEmailRecipient>> recipientsFromData(
    Map<String, dynamic> data, {
    String? userIdOverride,
  }) async {
    final email = _emailFrom(data);
    if (email != null) {
      return [
        AdminEmailRecipient(
          email: email,
          userId: _text(data['userId'], userIdOverride ?? ''),
          userName: _nameFrom(data),
          studentName: _text(data['studentName']),
        ),
      ];
    }

    final userId = _text(data['userId'], userIdOverride ?? '');
    if (userId.isEmpty) return [];

    final snap = await FirestoreDb.instance.collection('users').doc(userId).get();
    if (!snap.exists) return [];
    final user = snap.data() ?? {};
    final userEmail = _emailFrom(user);
    if (userEmail == null) return [];

    return [
      AdminEmailRecipient(
        email: userEmail,
        userId: userId,
        userName: _nameFrom(user),
        studentName: _text(user['studentName']),
      ),
    ];
  }

  static Future<List<AdminEmailRecipient>> allUsersWithEmail() async {
    final snap = await FirestoreDb.instance.collection('users').limit(800).get();
    final out = <AdminEmailRecipient>[];
    final seen = <String>{};
    for (final doc in snap.docs) {
      final email = _emailFrom(doc.data());
      if (email == null || seen.contains(email)) continue;
      seen.add(email);
      out.add(
        AdminEmailRecipient(
          email: email,
          userId: doc.id,
          userName: _nameFrom(doc.data()),
          studentName: _text(doc.data()['studentName']),
        ),
      );
    }
    return out;
  }

  static Future<List<AdminEmailRecipient>> usersSubscribedToCategory(
    String categoryId,
  ) async {
    if (categoryId.isEmpty) return [];
    final snap = await FirestoreDb.instance
        .collection('users')
        .where('subscribedUpdateCategoryIds', arrayContains: categoryId)
        .limit(500)
        .get();
    return snap.docs
        .map((doc) {
          final email = _emailFrom(doc.data());
          if (email == null) return null;
          return AdminEmailRecipient(
            email: email,
            userId: doc.id,
            userName: _nameFrom(doc.data()),
          );
        })
        .whereType<AdminEmailRecipient>()
        .toList();
  }

  static Future<List<AdminEmailRecipient>> usersTrackingCollege(
    String collegeId,
  ) async {
    if (collegeId.isEmpty) return [];
    final snap = await FirestoreDb.instance
        .collection('users')
        .where('medicalCollegeAlertIds', arrayContains: collegeId)
        .limit(500)
        .get();
    return snap.docs
        .map((doc) {
          final email = _emailFrom(doc.data());
          if (email == null) return null;
          return AdminEmailRecipient(
            email: email,
            userId: doc.id,
            userName: _nameFrom(doc.data()),
          );
        })
        .whereType<AdminEmailRecipient>()
        .toList();
  }

  static Map<String, String> payloadFromAnalysis(
    Map<String, dynamic> data,
    String requestId,
  ) {
    return {
      'requestId': requestId,
      'userId': _text(data['userId']),
      'userName': _nameFrom(data),
      'studentName': _text(data['studentName']),
      'email': _text(data['email']),
      'status': _text(data['status']),
      'sessionDate': _text(data['sessionDate']),
      'sessionTime': _text(data['timeSlot']),
      'adminNotes': _text(data['adminNotes']),
      'actionUrl': '${AdminEmailConfig.adminWebBaseUrl}',
    };
  }

  static Map<String, String> payloadFromCourse(
    Map<String, dynamic> data,
    String requestId,
  ) {
    return {
      'requestId': requestId,
      'userId': _text(data['userId']),
      'userName': _nameFrom(data),
      'studentName': _text(data['studentName']),
      'email': _text(data['email']),
      'courseName':
          _text(data['courseName'], _text(data['courseTitle'])),
      'actionUrl': AdminEmailConfig.adminWebBaseUrl,
    };
  }

  static Map<String, String> payloadFromUpdate(
    Map<String, dynamic> data,
    String updateId,
  ) {
    return {
      'updateId': updateId,
      'updateTitle': _text(data['title']),
      'title': _text(data['title']),
      'category': _text(data['category']),
      'actionUrl': 'app:///updates/$updateId',
    };
  }

  static Map<String, String> payloadFromUser(
    Map<String, dynamic> data,
    String userId,
  ) {
    return {
      'userId': userId,
      'userName': _nameFrom(data),
      'studentName': _text(data['studentName']),
      'email': _text(data['email']),
      'amount': _text(data['subscriptionAmount'], _text(data['amount'])),
      'actionUrl': 'app:///subscription',
    };
  }

  static bool isPublishedUpdate(Map<String, dynamic> data) {
    if (data['isPublished'] == true) return true;
    final publish = _map(data['publishConfig']);
    return _text(publish['status']).toLowerCase() == 'published';
  }

  static bool updateAllowsEmail(Map<String, dynamic> data) {
    final cfg = _map(data['notificationConfig']);
    return cfg['sendEmail'] == true;
  }

  static bool collegeAlertRelevantChange(
    Map<String, dynamic> before,
    Map<String, dynamic> after,
  ) {
    const fields = [
      'annualFeeInr',
      'totalFeeInr',
      'stateCutoff',
      'aiqCutoff',
      'seats',
      'rank',
    ];
    for (final field in fields) {
      if (jsonEncode(before[field]) != jsonEncode(after[field])) return true;
    }
    return false;
  }

  static String _normalizeCategory(String raw) {
    return raw
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  static String categoryIdFromUpdate(Map<String, dynamic> data) {
    final direct = _text(data['categoryId']);
    if (direct.isNotEmpty) return direct;
    return _normalizeCategory(_text(data['category']));
  }

  static List<String> _adminEmails(Map<String, dynamic> settings) {
    final raw = settings['adminRecipients'];
    if (raw is List) {
      return raw
          .map((e) => e.toString().trim())
          .where((e) => e.contains('@'))
          .toList();
    }
    return _text(raw)
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.contains('@'))
        .toList();
  }

  static String? _emailFrom(Map<String, dynamic> data) {
    for (final key in ['email', 'userEmail', 'parentEmail', 'contactEmail']) {
      final value = data[key]?.toString().trim() ?? '';
      if (value.contains('@')) return value.toLowerCase();
    }
    return null;
  }

  static String _nameFrom(Map<String, dynamic> data) {
    for (final key in ['userName', 'fullName', 'name', 'studentName']) {
      final value = data[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return 'there';
  }

  static Map<String, dynamic> _map(Object? raw) =>
      raw is Map ? Map<String, dynamic>.from(raw) : {};

  static String _text(Object? raw, [String fallback = '']) {
    final value = raw?.toString().trim() ?? '';
    return value.isEmpty ? fallback : value;
  }
}
