import 'package:cloud_firestore/cloud_firestore.dart';

import 'account_deletion_email_service.dart';
import 'admin_auth_eligibility.dart';
import 'firestore_db.dart';

/// Public account-deletion requests submitted from /unsubscribe (Google Play data safety).
abstract final class AccountDeletionRequestService {
  static const String collection = 'account_deletion_requests';
  static const String publicSourceAdminWeb = 'admin_web_unsubscribe';
  static const String publicSourceTestprepkart = 'testprepkart_web_unsubscribe';

  static CollectionReference<Map<String, dynamic>> get _col =>
      FirestoreDb.instance.collection(collection);

  static String normalizeEmail(String email) =>
      AdminAuthEligibility.normalizeEmail(email);

  static bool isValidEmail(String email) {
    final v = normalizeEmail(email);
    if (v.isEmpty || v.length > 254) return false;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v);
  }

  /// Anonymous create from public unsubscribe page.
  static Future<void> submitPublicRequest(
    String email, {
    String source = publicSourceAdminWeb,
  }) async {
    final normalized = normalizeEmail(email);
    if (!isValidEmail(normalized)) {
      throw ArgumentError('Invalid email');
    }
    final allowedSource = source == publicSourceTestprepkart
        ? publicSourceTestprepkart
        : publicSourceAdminWeb;
    await _col.add({
      'email': normalized,
      'status': 'New',
      'isRead': false,
      'source': allowedSource,
      'createdAt': FieldValue.serverTimestamp(),
      'createdAtLocal': DateTime.now().toIso8601String(),
      'emailSentRequest': false,
    });
    // Request confirmation email: sent by AdminEmailListener when an admin session
    // is open, or backfilled on next admin login for rows with emailSentRequest != true.
  }

  static Future<void> markRead(String docId) async {
    await _col.doc(docId).set({
      'isRead': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> updateStatus(String docId, String status) async {
    final ref = _col.doc(docId);
    final snap = await ref.get();
    final data = snap.data() ?? {};
    await ref.set({
      'status': status,
      'isRead': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await AccountDeletionEmailService.sendStatusUpdateIfNeeded(
      docId: docId,
      newStatus: status,
      data: {...data, 'status': status},
    );
  }
}
