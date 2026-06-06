import 'package:firebase_auth/firebase_auth.dart';

import '../admin_auth_constants.dart';
import 'admin_auth_eligibility.dart';

/// Signed-in admin web session helpers (owner vs moderator).
abstract final class AdminSession {
  static User? get currentUser => FirebaseAuth.instance.currentUser;

  static bool isOwnerEmail(String? email) {
    return AdminAuthEligibility.normalizeEmail(email ?? '') ==
        AdminAuthConstants.ownerAdminEmail;
  }

  static bool isOwnerUser(User? user) {
    if (user == null) return false;
    return user.uid == AdminAuthConstants.ownerAdminUid ||
        isOwnerEmail(user.email);
  }

  static bool get isOwner => isOwnerUser(currentUser);

  static bool roleIsStaff(String? role) {
    final r = (role ?? 'user').toLowerCase();
    return r == 'admin' || r == 'moderator';
  }
}
