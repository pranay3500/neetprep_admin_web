/// Shared admin authentication policy (sign-in, lockout, password recovery).
abstract final class AdminAuthConstants {
  static const String ownerAdminEmail = 'pranay3500@gmail.com';

  /// Firebase Auth UID for [ownerAdminEmail] — must match `isOwnerAdmin()` in `firestore.rules`.
  static const String ownerAdminUid = 'yHv2WB4L9LY73KFHL2bbTxpBT5h1';
  static const int maxFailedLoginAttempts = 3;
  static const Duration loginLockDuration = Duration(minutes: 60);
  static const String passwordResetContinueUrl = 'https://neetappadmin.satlas.org/';

  /// Failed-login lockout (Firestore `admin_login_security`). Off for local testing.
  /// Set to `true` before production admin deploy.
  static const bool loginLockoutEnabled = false;
}
