import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firestore_db.dart';

/// Live admin nav badge flags — single place for Firestore listeners (avoids
/// deeply nested [StreamBuilder]s that can trigger web SDK internal errors).
class AdminNavBadgeState {
  const AdminNavBadgeState({
    this.hasPendingDemoRequests = false,
    this.hasPendingMessages = false,
    this.hasPendingCourses = false,
    this.hasPendingWebinarInterest = false,
    this.hasPendingUnsubscribeRequests = false,
    this.hasPendingSubscriptionRequests = false,
    this.hasNewUserRegistrations = false,
    this.courseInquiryUnreadCount = 0,
    this.courseDemoUnreadCount = 0,
    this.webinarNotifyUnreadCount = 0,
  });

  final bool hasPendingDemoRequests;
  final bool hasPendingMessages;
  final bool hasPendingCourses;
  final bool hasPendingWebinarInterest;
  final bool hasPendingUnsubscribeRequests;
  final bool hasPendingSubscriptionRequests;
  final bool hasNewUserRegistrations;
  final int courseInquiryUnreadCount;
  final int courseDemoUnreadCount;
  final int webinarNotifyUnreadCount;

  bool get hasUsersMenuAttention =>
      hasPendingSubscriptionRequests || hasNewUserRegistrations;
}

class AdminNavBadgeHost extends StatefulWidget {
  const AdminNavBadgeHost({
    super.key,
    required this.builder,
  });

  final Widget Function(BuildContext context, AdminNavBadgeState badges) builder;

  static AdminNavBadgeState of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<_AdminNavBadgeScope>();
    return scope?.badges ?? const AdminNavBadgeState();
  }

  @override
  State<AdminNavBadgeHost> createState() => _AdminNavBadgeHostState();
}

class _AdminNavBadgeHostState extends State<AdminNavBadgeHost> {
  final List<StreamSubscription<QuerySnapshot<Map<String, dynamic>>>> _subs = [];

  bool _hasPendingDemoRequests = false;
  bool _hasPendingMessages = false;
  int _courseInquiryUnreadCount = 0;
  int _courseDemoUnreadCount = 0;
  bool _hasPendingWebinarInterest = false;
  int _webinarNotifyUnreadCount = 0;
  bool _hasPendingUnsubscribeRequests = false;
  bool _hasPendingSubscriptionRequests = false;
  bool _hasNewUserRegistrations = false;

  AdminNavBadgeState get _badges => AdminNavBadgeState(
        hasPendingDemoRequests: _hasPendingDemoRequests,
        hasPendingMessages: _hasPendingMessages,
        hasPendingCourses:
            _courseInquiryUnreadCount > 0 || _courseDemoUnreadCount > 0,
        hasPendingWebinarInterest: _hasPendingWebinarInterest,
        hasPendingUnsubscribeRequests: _hasPendingUnsubscribeRequests,
        hasPendingSubscriptionRequests: _hasPendingSubscriptionRequests,
        hasNewUserRegistrations: _hasNewUserRegistrations,
        courseInquiryUnreadCount: _courseInquiryUnreadCount,
        courseDemoUnreadCount: _courseDemoUnreadCount,
        webinarNotifyUnreadCount: _webinarNotifyUnreadCount,
      );

  @override
  void initState() {
    super.initState();
    _listen(
      FirestoreDb.instance
          .collection('analysis_session_requests')
          .where('status', isEqualTo: 'pending_confirmation')
          .limit(1)
          .snapshots(),
      (docs) => _hasPendingDemoRequests = docs.isNotEmpty,
    );
    _listen(
      FirestoreDb.instance
          .collection('threads')
          .where('adminUnread', isEqualTo: true)
          .limit(1)
          .snapshots(),
      (docs) => _hasPendingMessages = docs.isNotEmpty,
    );
    _listen(
      FirestoreDb.instance
          .collection('course_inquiries')
          .where('isRead', isEqualTo: false)
          .limit(200)
          .snapshots(),
      (docs) => _courseInquiryUnreadCount = docs.length,
    );
    _listen(
      FirestoreDb.instance
          .collection('course_demo_bookings')
          .where('isRead', isEqualTo: false)
          .limit(200)
          .snapshots(),
      (docs) => _courseDemoUnreadCount = docs.length,
    );
    _listen(
      FirestoreDb.instance
          .collection('webinar_notify_interest')
          .where('isRead', isEqualTo: false)
          .limit(50)
          .snapshots(),
      (docs) {
        _hasPendingWebinarInterest = docs.isNotEmpty;
        _webinarNotifyUnreadCount = docs.length;
      },
    );
    _listen(
      FirestoreDb.instance
          .collection('account_deletion_requests')
          .where('isRead', isEqualTo: false)
          .limit(1)
          .snapshots(),
      (docs) => _hasPendingUnsubscribeRequests = docs.isNotEmpty,
    );
    _listen(
      FirestoreDb.instance
          .collection('users')
          .where('subscriptionRequestPending', isEqualTo: true)
          .limit(1)
          .snapshots(),
      (docs) => _hasPendingSubscriptionRequests = docs.isNotEmpty,
    );
    _listen(
      FirestoreDb.instance
          .collection('users')
          .where('adminRegistrationUnread', isEqualTo: true)
          .limit(1)
          .snapshots(),
      (docs) => _hasNewUserRegistrations = docs.isNotEmpty,
    );
  }

  void _listen(
    Stream<QuerySnapshot<Map<String, dynamic>>> stream,
    void Function(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) apply,
  ) {
    _subs.add(
      stream.listen(
        (snapshot) {
          if (!mounted) return;
          setState(() => apply(snapshot.docs));
        },
        onError: (Object error, StackTrace stack) {
          debugPrint('[TPK][ADMIN] Nav badge listener error: $error');
        },
      ),
    );
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      unawaited(sub.cancel());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _AdminNavBadgeScope(
      badges: _badges,
      child: widget.builder(context, _badges),
    );
  }
}

class _AdminNavBadgeScope extends InheritedWidget {
  const _AdminNavBadgeScope({
    required this.badges,
    required super.child,
  });

  final AdminNavBadgeState badges;

  @override
  bool updateShouldNotify(_AdminNavBadgeScope oldWidget) =>
      oldWidget.badges.hasPendingDemoRequests != badges.hasPendingDemoRequests ||
      oldWidget.badges.hasPendingMessages != badges.hasPendingMessages ||
      oldWidget.badges.hasPendingCourses != badges.hasPendingCourses ||
      oldWidget.badges.hasPendingWebinarInterest !=
          badges.hasPendingWebinarInterest ||
      oldWidget.badges.hasPendingUnsubscribeRequests !=
          badges.hasPendingUnsubscribeRequests ||
      oldWidget.badges.hasPendingSubscriptionRequests !=
          badges.hasPendingSubscriptionRequests ||
      oldWidget.badges.hasNewUserRegistrations !=
          badges.hasNewUserRegistrations ||
      oldWidget.badges.courseInquiryUnreadCount !=
          badges.courseInquiryUnreadCount ||
      oldWidget.badges.courseDemoUnreadCount != badges.courseDemoUnreadCount ||
      oldWidget.badges.webinarNotifyUnreadCount !=
          badges.webinarNotifyUnreadCount;
}
