import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../admin_auth_constants.dart';
import 'admin_session.dart';
import 'firestore_db.dart';

/// Result of the post-sign-in admin panel gate.
class AdminAccessCheckResult {
  const AdminAccessCheckResult._({
    required this.allowed,
    this.denyReason,
    this.detail,
  });

  final bool allowed;
  final String? denyReason;
  final String? detail;

  static const allowedResult = AdminAccessCheckResult._(allowed: true);
}

/// Whether [email] may use admin sign-in / password recovery.
abstract final class AdminAuthEligibility {
  static String normalizeEmail(String email) => email.trim().toLowerCase();

  /// Pre-check before sign-in / password reset.
  ///
  /// Does not use [FirebaseAuth.fetchSignInMethodsForEmail] — that API returns
  /// empty when email enumeration protection is on, which blocked valid admins.
  /// Pre–sign-in hint only. Firebase Auth + [hasActiveAdminAccess] are authoritative.
  ///
  /// Returns true when Firestore shows panel role for this email, or when we should
  /// still allow an Auth attempt (role may exist only on `users/{uid}` after grant).
  static Future<bool> isRegisteredAdminEmail(String email) async {
    final normalized = normalizeEmail(email);
    if (normalized.isEmpty || !normalized.contains('@')) return false;

    if (normalized == AdminAuthConstants.ownerAdminEmail) return true;
    if (await hasActiveAdminRole(normalized)) return true;
    // Do not block here: moderators are validated on `users/{uid}` after sign-in.
    return true;
  }

  /// Whether a signed-in user may access the admin shell (post-auth gate).
  static Future<bool> hasActiveAdminAccess({
    required String email,
    required String uid,
  }) async {
    final result = await checkActiveAdminAccess(email: email, uid: uid);
    return result.allowed;
  }

  /// Detailed post-sign-in gate — used for admin shell routing and diagnostics.
  static Future<AdminAccessCheckResult> checkActiveAdminAccess({
    required String email,
    required String uid,
  }) async {
    try {
      final normalized = normalizeEmail(email);
      if (normalized == AdminAuthConstants.ownerAdminEmail) {
        return AdminAccessCheckResult.allowedResult;
      }

      final authUser = FirebaseAuth.instance.currentUser;
      if (authUser != null && authUser.uid == uid) {
        try {
          // Firestore rules need a fresh auth token right after sign-in.
          await authUser.getIdToken(true);
        } catch (e) {
          debugPrint('[TPK][ADMIN] Auth token refresh before panel check: $e');
        }
      }

      final uidDoc =
          await FirestoreDb.instance.collection('users').doc(uid).get();

      if (!uidDoc.exists) {
        return AdminAccessCheckResult._(
          allowed: false,
          denyReason:
              'No Firestore profile at users/$uid.\n\n'
              'Ask the owner to open App Users, find this email, and tap '
              'Grant moderator (the person must register on the mobile app first).',
        );
      }

      final data = uidDoc.data() ?? const <String, dynamic>{};
      if (_docAllowed(data)) {
        return AdminAccessCheckResult.allowedResult;
      }

      final role = (data['role'] ?? 'user').toString().toLowerCase();
      final isActive = data['isActive'] != false;
      final storedEmail = normalizeEmail(data['email']?.toString() ?? '');

      if (!AdminSession.roleIsStaff(role)) {
        return AdminAccessCheckResult._(
          allowed: false,
          denyReason:
              'Firestore users/$uid has role "$role" (needs admin or moderator).\n\n'
              'On App Users, the owner must tap Grant moderator for $normalized '
              '(sign in with email + password, not the UID).',
        );
      }

      if (!isActive) {
        return AdminAccessCheckResult._(
          allowed: false,
          denyReason:
              'Panel login is disabled (Active = off) on users/$uid.\n\n'
              'Ask the owner to turn Active on in App Users for $normalized.',
        );
      }

      if (storedEmail.isNotEmpty && storedEmail != normalized) {
        return AdminAccessCheckResult._(
          allowed: false,
          denyReason:
              'Signed-in email ($normalized) does not match Firestore profile '
              'email ($storedEmail) on users/$uid.\n\n'
              'Use the same email as the mobile app, or ask the owner to fix the profile.',
        );
      }

      return AdminAccessCheckResult._(
        allowed: false,
        denyReason: 'Could not verify admin access for users/$uid.',
      );
    } on FirebaseException catch (e) {
      debugPrint('[TPK][ADMIN] Admin access Firestore error: ${e.code} ${e.message}');
      final hint = e.code == 'permission-denied'
          ? 'Firestore denied reading users/$uid. Deploy the latest '
              'firestore.rules (firebase deploy --only firestore:default:rules).'
          : 'Firestore error (${e.code}). Try again in a moment.';
      return AdminAccessCheckResult._(
        allowed: false,
        denyReason: hint,
        detail: e.message,
      );
    } catch (e, st) {
      debugPrint('[TPK][ADMIN] Admin access check failed: $e\n$st');
      return AdminAccessCheckResult._(
        allowed: false,
        denyReason:
            'Could not verify admin access. Check your connection and try again.',
        detail: e.toString(),
      );
    }
  }

  static Future<bool> hasActiveAdminRole(String normalized) async {
    try {
      final users = FirestoreDb.instance.collection('users');
      final exact =
          await users.where('email', isEqualTo: normalized).limit(5).get();
      return _roleAllowed(exact.docs);
    } catch (_) {
      return false;
    }
  }

  /// Owner action: ensure panel role is on the Firebase Auth UID document.
  static Future<void> grantModeratorOnUid({
    required String uid,
    required String email,
    String? grantedByEmail,
  }) async {
    final normalized = normalizeEmail(email);
    await FirestoreDb.instance.collection('users').doc(uid).set({
      'uid': uid,
      'email': normalized,
      'role': 'moderator',
      'isActive': true,
      'panelAccessGrantedAt': FieldValue.serverTimestamp(),
      if (grantedByEmail != null) 'panelAccessGrantedBy': grantedByEmail,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static bool _roleAllowed(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    for (final doc in docs) {
      if (_docAllowed(doc.data())) return true;
    }
    return false;
  }

  static bool _docAllowed(Map<String, dynamic> data) {
    final role = (data['role'] ?? 'user').toString().toLowerCase();
    final isActive = data['isActive'] != false;
    return isActive && (role == 'admin' || role == 'moderator');
  }
}
