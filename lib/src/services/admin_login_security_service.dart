import 'package:cloud_firestore/cloud_firestore.dart';

import '../admin_auth_constants.dart';
import 'admin_auth_eligibility.dart';
import 'firestore_db.dart';

class AdminLoginLockStatus {
  const AdminLoginLockStatus({
    required this.isLocked,
    this.lockedUntil,
    this.failedAttempts = 0,
  });

  final bool isLocked;
  final DateTime? lockedUntil;
  final int failedAttempts;

  Duration? get remainingLockTime {
    if (lockedUntil == null) return null;
    final left = lockedUntil!.difference(DateTime.now());
    if (left.isNegative) return Duration.zero;
    return left;
  }
}

/// Tracks failed admin logins in Firestore (`admin_login_security/{emailKey}`).
abstract final class AdminLoginSecurityService {
  static CollectionReference<Map<String, dynamic>> get _collection =>
      FirestoreDb.instance.collection('admin_login_security');

  static String emailKey(String email) {
    return AdminAuthEligibility.normalizeEmail(email)
        .replaceAll('@', '_at_')
        .replaceAll('.', '_dot_');
  }

  static DocumentReference<Map<String, dynamic>> _doc(String email) =>
      _collection.doc(emailKey(email));

  static Future<AdminLoginLockStatus> checkLockout(String email) async {
    if (!AdminAuthConstants.loginLockoutEnabled) {
      return const AdminLoginLockStatus(isLocked: false);
    }
    final snap = await _doc(email).get();
    if (!snap.exists) {
      return const AdminLoginLockStatus(isLocked: false);
    }
    final data = snap.data() ?? {};
    final lockedUntil = _parseTimestamp(data['lockedUntil']);
    final failed = (data['failedAttempts'] as num?)?.toInt() ?? 0;

    if (lockedUntil != null && lockedUntil.isAfter(DateTime.now())) {
      return AdminLoginLockStatus(
        isLocked: true,
        lockedUntil: lockedUntil,
        failedAttempts: failed,
      );
    }

    if (lockedUntil != null && !lockedUntil.isAfter(DateTime.now())) {
      await clearFailures(email);
      return const AdminLoginLockStatus(isLocked: false);
    }

    return AdminLoginLockStatus(isLocked: false, failedAttempts: failed);
  }

  static Future<void> recordFailedAttempt(String email) async {
    if (!AdminAuthConstants.loginLockoutEnabled) return;
    final normalized = AdminAuthEligibility.normalizeEmail(email);
    final ref = _doc(normalized);
    final now = DateTime.now();

    await FirestoreDb.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      var attempts = 1;
      if (snap.exists) {
        final data = snap.data() ?? {};
        final existingUntil = _parseTimestamp(data['lockedUntil']);
        if (existingUntil != null && existingUntil.isAfter(now)) {
          return;
        }
        attempts = ((data['failedAttempts'] as num?)?.toInt() ?? 0) + 1;
      }

      final payload = <String, dynamic>{
        'email': normalized,
        'failedAttempts': attempts,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (attempts >= AdminAuthConstants.maxFailedLoginAttempts) {
        payload['lockedUntil'] = Timestamp.fromDate(
          now.add(AdminAuthConstants.loginLockDuration),
        );
      } else {
        payload['lockedUntil'] = FieldValue.delete();
      }

      tx.set(ref, payload, SetOptions(merge: true));
    });
  }

  static Future<void> clearFailures(String email) async {
    try {
      await _doc(email).delete();
    } catch (_) {}
  }

  static DateTime? _parseTimestamp(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return null;
  }

  static String lockoutMessage(AdminLoginLockStatus status) {
    final remaining = status.remainingLockTime;
    if (remaining == null || remaining <= Duration.zero) {
      return 'Too many failed attempts. Try again in 60 minutes.';
    }
    final minutes = remaining.inMinutes.clamp(1, 9999);
    return 'Too many failed attempts. Sign-in is blocked for about $minutes more minute(s).';
  }
}
