import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../account_deletion_email_service.dart';
import '../firestore_db.dart';
import 'admin_email_dispatcher.dart';

/// Watches Firestore while admin is signed in and sends emails via [AdminEmailDispatcher].
class AdminEmailListener {
  AdminEmailListener._();
  static final AdminEmailListener instance = AdminEmailListener._();

  final List<StreamSubscription<dynamic>> _subs = [];
  final Map<String, bool> _bootstrapped = {};
  final Map<String, bool> _userWasPremium = {};
  final Map<String, String> _collegeAlertHashes = {};
  final AdminEmailDispatcher _dispatcher = AdminEmailDispatcher.instance;

  bool get isRunning => _subs.isNotEmpty;

  void start() {
    if (_subs.isNotEmpty) return;
    debugPrint('[TPK][ADMIN][EMAIL] listener started');

    _subs.add(
      FirestoreDb.instance
          .collection('users')
          .snapshots()
          .listen(_onUsers),
    );
    _subs.add(
      FirestoreDb.instance
          .collection('analysis_session_requests')
          .snapshots()
          .listen(_onAnalysisRequests),
    );
    _subs.add(
      FirestoreDb.instance.collection('course_inquiries').snapshots().listen(
            _onCourseInquiries,
          ),
    );
    _subs.add(
      FirestoreDb.instance.collection('course_demo_bookings').snapshots().listen(
            _onCourseDemos,
          ),
    );
    _subs.add(
      FirestoreDb.instance.collection('updates').snapshots().listen(_onUpdates),
    );
    _subs.add(
      FirestoreDb.instance.collection('threads').snapshots().listen(_onThreads),
    );
    _subs.add(
      FirestoreDb.instance
          .collection('medical_colleges')
          .snapshots()
          .listen(_onColleges),
    );
    _subs.add(
      FirestoreDb.instance
          .collection('account_deletion_requests')
          .snapshots()
          .listen(_onAccountDeletionRequests),
    );
  }

  void stop() {
    for (final sub in _subs) {
      unawaited(sub.cancel());
    }
    _subs.clear();
    _bootstrapped.clear();
    debugPrint('[TPK][ADMIN][EMAIL] listener stopped');
  }

  bool _bootstrap(String key) {
    if (_bootstrapped[key] == true) return false;
    _bootstrapped[key] = true;
    return true;
  }

  Future<void> _onUsers(QuerySnapshot<Map<String, dynamic>> snap) async {
    if (_bootstrap('users')) {
      for (final doc in snap.docs) {
        _userWasPremium[doc.id] = doc.data()['isPremium'] == true;
      }
      return;
    }

    for (final change in snap.docChanges) {
      final data = change.doc.data() ?? {};
      final userId = change.doc.id;

      if (change.type == DocumentChangeType.added) {
        _userWasPremium[userId] = data['isPremium'] == true;
        final recipients = await AdminEmailDispatcher.recipientsFromData(
          data,
          userIdOverride: userId,
        );
        await _dispatcher.dispatch(
          triggerKey: 'userRegistered',
          sourcePath: 'users/$userId',
          payload: AdminEmailDispatcher.payloadFromUser(data, userId),
          userRecipients: recipients,
          sendAdmin: true,
        );
        continue;
      }

      if (change.type == DocumentChangeType.modified) {
        final wasPremium = _userWasPremium[userId] ?? false;
        final isPremium = data['isPremium'] == true;
        _userWasPremium[userId] = isPremium;
        if (!wasPremium && isPremium) {
          final recipients = await AdminEmailDispatcher.recipientsFromData(
            data,
            userIdOverride: userId,
          );
          await _dispatcher.dispatch(
            triggerKey: 'subscriptionPurchase',
            sourcePath: 'users/$userId',
            payload: AdminEmailDispatcher.payloadFromUser(data, userId),
            userRecipients: recipients,
            sendAdmin: true,
          );
        }
      }
    }
  }

  Future<void> _onAnalysisRequests(
    QuerySnapshot<Map<String, dynamic>> snap,
  ) async {
    if (_bootstrap('analysis')) return;

    for (final change in snap.docChanges) {
      final data = change.doc.data();
      if (data == null) continue;
      final id = change.doc.id;

      if (change.type == DocumentChangeType.added) {
        final recipients = await AdminEmailDispatcher.recipientsFromData(data);
        await _dispatcher.dispatch(
          triggerKey: 'demoRequestCreated',
          sourcePath: 'analysis_session_requests/$id',
          payload: AdminEmailDispatcher.payloadFromAnalysis(data, id),
          userRecipients: recipients,
          sendAdmin: true,
        );
      } else if (change.type == DocumentChangeType.modified) {
        final status = data['status']?.toString() ?? '';
        if (status.isEmpty) continue;
        final recipients = await AdminEmailDispatcher.recipientsFromData(data);
        await _dispatcher.dispatch(
          triggerKey: 'analysisSessionStatusChanged',
          sourcePath: 'analysis_session_requests/$id',
          payload: AdminEmailDispatcher.payloadFromAnalysis(data, id),
          userRecipients: recipients,
          sendAdmin: true,
        );
      }
    }
  }

  /// No bootstrap skip — backfills request emails for rows with emailSentRequest != true.
  Future<void> _onAccountDeletionRequests(
    QuerySnapshot<Map<String, dynamic>> snap,
  ) async {
    for (final change in snap.docChanges) {
      final data = change.doc.data();
      if (data == null) continue;
      final id = change.doc.id;

      if (change.type == DocumentChangeType.added ||
          (change.type == DocumentChangeType.modified &&
              data['emailSentRequest'] != true)) {
        await AccountDeletionEmailService.sendRequestReceivedIfNeeded(
          docId: id,
          data: data,
        );
      }
    }
  }

  Future<void> _onCourseInquiries(
    QuerySnapshot<Map<String, dynamic>> snap,
  ) async {
    if (_bootstrap('inquiries')) return;
    for (final change in snap.docChanges) {
      if (change.type != DocumentChangeType.added) continue;
      final data = change.doc.data();
      if (data == null) continue;
      final id = change.doc.id;
      final recipients = await AdminEmailDispatcher.recipientsFromData(data);
      await _dispatcher.dispatch(
        triggerKey: 'courseInquiryCreated',
        sourcePath: 'course_inquiries/$id',
        payload: AdminEmailDispatcher.payloadFromCourse(data, id),
        userRecipients: recipients,
        sendAdmin: true,
      );
    }
  }

  Future<void> _onCourseDemos(
    QuerySnapshot<Map<String, dynamic>> snap,
  ) async {
    if (_bootstrap('demos')) return;
    for (final change in snap.docChanges) {
      if (change.type != DocumentChangeType.added) continue;
      final data = change.doc.data();
      if (data == null) continue;
      final id = change.doc.id;
      final recipients = await AdminEmailDispatcher.recipientsFromData(data);
      await _dispatcher.dispatch(
        triggerKey: 'courseDemoBooked',
        sourcePath: 'course_demo_bookings/$id',
        payload: AdminEmailDispatcher.payloadFromCourse(data, id),
        userRecipients: recipients,
        sendAdmin: true,
      );
    }
  }

  Future<void> _onUpdates(QuerySnapshot<Map<String, dynamic>> snap) async {
    if (_bootstrap('updates')) return;
    for (final change in snap.docChanges) {
      if (change.type != DocumentChangeType.added &&
          change.type != DocumentChangeType.modified) {
        continue;
      }
      final data = change.doc.data();
      if (data == null) continue;
      if (!AdminEmailDispatcher.isPublishedUpdate(data)) continue;
      if (!AdminEmailDispatcher.updateAllowsEmail(data)) continue;

      final id = change.doc.id;
      final isBreaking = data['isBreaking'] == true ||
          (data['priority']?.toString().toUpperCase() == 'BREAKING') ||
          (data['priority']?.toString().toUpperCase() == 'URGENT');
      final triggerKey = isBreaking ? 'breakingUpdate' : 'updatePublished';
      final categoryId = AdminEmailDispatcher.categoryIdFromUpdate(data);
      final userRecipients = isBreaking
          ? await AdminEmailDispatcher.allUsersWithEmail()
          : await AdminEmailDispatcher.usersSubscribedToCategory(categoryId);

      await _dispatcher.dispatch(
        triggerKey: triggerKey,
        sourcePath: 'updates/$id',
        payload: AdminEmailDispatcher.payloadFromUpdate(data, id),
        userRecipients: userRecipients,
        sendAdmin: true,
      );
    }
  }

  Future<void> _onThreads(QuerySnapshot<Map<String, dynamic>> snap) async {
    if (_bootstrap('threads')) return;
    for (final change in snap.docChanges) {
      if (change.type != DocumentChangeType.added &&
          change.type != DocumentChangeType.modified) {
        continue;
      }
      final data = change.doc.data();
      if (data == null) continue;
      if (data['adminUnread'] != true) continue;

      final id = change.doc.id;
      final recipients = await AdminEmailDispatcher.recipientsFromData(data);
      await _dispatcher.dispatch(
        triggerKey: 'messageReceived',
        sourcePath: 'threads/$id',
        payload: {
          ...AdminEmailDispatcher.payloadFromUser(data, data['userId']?.toString() ?? ''),
          'messageTopic': data['topic']?.toString() ?? 'New message',
          'messageContent': data['lastMessageContent']?.toString() ?? '',
        },
        userRecipients: recipients,
        sendAdmin: true,
      );
    }
  }

  Future<void> _onColleges(QuerySnapshot<Map<String, dynamic>> snap) async {
    if (_bootstrap('colleges')) {
      for (final doc in snap.docs) {
        _collegeAlertHashes[doc.id] = _collegeAlertHash(doc.data());
      }
      return;
    }
    for (final change in snap.docChanges) {
      if (change.type != DocumentChangeType.modified) continue;
      final after = change.doc.data();
      if (after == null) continue;
      final id = change.doc.id;
      final hash = _collegeAlertHash(after);
      final previous = _collegeAlertHashes[id];
      _collegeAlertHashes[id] = hash;
      if (previous == null || previous == hash) continue;

      final users = await AdminEmailDispatcher.usersTrackingCollege(id);
      if (users.isEmpty) continue;
      await _dispatcher.dispatch(
        triggerKey: 'collegeAlertUpdate',
        sourcePath: 'medical_colleges/$id',
        payload: {
          'collegeId': id,
          'collegeName':
              after['collegeName']?.toString() ?? after['name']?.toString() ?? '',
          'actionUrl': 'app:///colleges/$id',
        },
        userRecipients: users,
        sendAdmin: true,
      );
    }
  }

  String _collegeAlertHash(Map<String, dynamic> data) {
    final fields = [
      data['annualFeeInr'],
      data['totalFeeInr'],
      data['stateCutoff'],
      data['aiqCutoff'],
      data['seats'],
      data['rank'],
    ];
    return jsonEncode(fields);
  }
}
