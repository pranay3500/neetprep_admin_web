import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'account_deletion_request_service.dart';
import 'admin_email/admin_email_dispatcher.dart';
import 'firestore_db.dart';

/// Sends transactional emails for account-deletion requests (admin relay).
abstract final class AccountDeletionEmailService {
  static String triggerForStatus(String status) {
    switch (status) {
      case 'Completed':
        return 'accountDeletionCompleted';
      case 'Rejected':
        return 'accountDeletionRejected';
      default:
        return '';
    }
  }

  static Future<void> sendRequestReceivedIfNeeded({
    required String docId,
    required Map<String, dynamic> data,
  }) async {
    if (data['emailSentRequest'] == true) return;
    final email = AccountDeletionRequestService.normalizeEmail(
      data['email']?.toString() ?? '',
    );
    if (!AccountDeletionRequestService.isValidEmail(email)) return;

    await _dispatch(
      triggerKey: 'accountDeletionRequested',
      sourcePath: '${AccountDeletionRequestService.collection}/$docId',
      email: email,
      status: 'New',
    );

    await FirestoreDb.instance
        .collection(AccountDeletionRequestService.collection)
        .doc(docId)
        .set({'emailSentRequest': true}, SetOptions(merge: true));
  }

  static Future<void> sendStatusUpdateIfNeeded({
    required String docId,
    required String newStatus,
    required Map<String, dynamic> data,
  }) async {
    final triggerKey = triggerForStatus(newStatus);
    if (triggerKey.isEmpty) return;

    final markerField = newStatus == 'Completed'
        ? 'emailSentCompleted'
        : 'emailSentRejected';
    if (data[markerField] == true) return;

    final email = AccountDeletionRequestService.normalizeEmail(
      data['email']?.toString() ?? '',
    );
    if (!AccountDeletionRequestService.isValidEmail(email)) return;

    await _dispatch(
      triggerKey: triggerKey,
      sourcePath: '${AccountDeletionRequestService.collection}/$docId',
      email: email,
      status: newStatus,
    );

    await FirestoreDb.instance
        .collection(AccountDeletionRequestService.collection)
        .doc(docId)
        .set({markerField: true}, SetOptions(merge: true));
  }

  static Future<void> _dispatch({
    required String triggerKey,
    required String sourcePath,
    required String email,
    required String status,
  }) async {
    try {
      final recipients = [
        AdminEmailRecipient(email: email, userName: 'there'),
      ];
      await AdminEmailDispatcher.instance.dispatch(
        triggerKey: triggerKey,
        sourcePath: sourcePath,
        payload: {
          'email': email,
          'userName': 'there',
          'status': status,
          'actionUrl': 'https://www.testprepkart.com/unsubscribe/',
        },
        userRecipients: recipients,
        sendAdmin: triggerKey == 'accountDeletionRequested',
      );
    } catch (e, st) {
      debugPrint('[TPK][ADMIN][EMAIL] account deletion $triggerKey failed: $e\n$st');
    }
  }
}
