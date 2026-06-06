import 'package:cloud_firestore/cloud_firestore.dart';

import '../admin_auth_constants.dart';
import 'firestore_db.dart';

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
    try {
      final normalized = normalizeEmail(email);
      if (normalized == AdminAuthConstants.ownerAdminEmail) return true;

      final uidDoc =
          await FirestoreDb.instance.collection('users').doc(uid).get();
      if (uidDoc.exists && _docAllowed(uidDoc.data() ?? const {})) {
        return true;
      }

      return hasActiveAdminRole(normalized);
    } catch (_) {
      return false;
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
