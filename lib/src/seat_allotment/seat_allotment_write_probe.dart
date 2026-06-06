import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../admin_auth_constants.dart';
import '../services/firestore_db.dart';

/// Verifies Firestore rules allow seat allotment writes for the signed-in admin.
abstract final class SeatAllotmentWriteProbe {
  static const String _probeDocId = 'admin_write_probe';

  static Future<void> _refreshAuthToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await user.getIdToken(true);
  }

  /// Returns null when OK; otherwise a user-facing error string (includes uid/email).
  static Future<String?> verify() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return 'Not signed in. Sign out and sign in to the admin panel again.';
    }

    await _refreshAuthToken();

    final email = (user.email ?? '').trim().toLowerCase();
    final uid = user.uid;
    final ownerUid = AdminAuthConstants.ownerAdminUid;
    final ownerEmail = AdminAuthConstants.ownerAdminEmail;

    // Step 1 — same rule family as other CMS pages (Courses, Medical Colleges).
    try {
      await FirestoreDb.instance
          .collection('_admin_connectivity_probe')
          .doc('seat_allotment_import')
          .set({
        'checkedAt': FieldValue.serverTimestamp(),
        'checkedByUid': uid,
        'checkedByEmail': email,
      });
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        return _authFailureMessage(
          uid: uid,
          email: email,
          ownerUid: ownerUid,
          ownerEmail: ownerEmail,
          step: 'CMS connectivity probe (_admin_connectivity_probe)',
        );
      }
      return 'Firestore error (${e.code}): ${e.message}';
    }

    // Step 2 — seat allotment collections (dataset + row subcollection).
    final ref = FirestoreDb.instance
        .collection('seat_allotment_datasets')
        .doc(_probeDocId);

    try {
      await ref.set({
        'probe': true,
        'isPublished': false,
        'checkedAt': FieldValue.serverTimestamp(),
        'checkedByUid': uid,
        'checkedByEmail': email,
      });
      final rowRef = ref.collection('rows').doc('probe_1');
      await rowRef.set({
        'rank': 1,
        'serialNo': 1,
        'probe': true,
      });
      await rowRef.delete();
      await ref.delete();
      return null;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        return '${_authFailureMessage(
          uid: uid,
          email: email,
          ownerUid: ownerUid,
          ownerEmail: ownerEmail,
          step: 'seat_allotment_datasets',
        )}\n\n'
            'CMS probe passed but seat allotment rules are missing on Firebase. '
            'Deploy from neetprep_flutter:\n'
            'firebase deploy --only firestore:rules';
      }
      return 'Firestore error (${e.code}): ${e.message}';
    } catch (e) {
      return 'Could not verify write access: $e';
    }
  }

  static String _authFailureMessage({
    required String uid,
    required String email,
    required String ownerUid,
    required String ownerEmail,
    required String step,
  }) {
    final uidOk = uid == ownerUid;
    final emailOk = email == ownerEmail;
    return 'Firestore denied write ($step).\n'
        'Signed in as: ${email.isEmpty ? "(no email)" : email}\n'
        'UID: $uid\n'
        'Owner UID match: ${uidOk ? "yes" : "no — expected $ownerUid"}\n'
        'Owner email match: ${emailOk ? "yes" : "no — expected $ownerEmail"}\n\n'
        'Try: sign out → sign in again (refreshes auth token). '
        'Then deploy rules: firebase deploy --only firestore:rules';
  }
}
