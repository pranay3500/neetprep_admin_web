import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class FirestoreDb {
  FirestoreDb._();

  static FirebaseFirestore? _instance;
  static const String databaseId = 'default';
  static bool _initialized = false;

  /// Public CMS doc (rules: `allow read: if true`) — safe before admin sign-in.
  static const String _connectivityCollection = 'cms_dashboard';
  static const String _connectivityDocId = 'main';

  static FirebaseFirestore get instance =>
      _instance ??
      FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: databaseId,
      );

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _instance = FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: databaseId,
    );

    try {
      await _instance!
          .collection(_connectivityCollection)
          .doc(_connectivityDocId)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 8));
      debugPrint(
        '[TPK][ADMIN] Firestore OK (databaseId=$databaseId, '
        'read $_connectivityCollection/$_connectivityDocId).',
      );
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        debugPrint(
          '[TPK][ADMIN] Firestore reachable but CMS read denied — '
          'check deployed rules for $_connectivityCollection. databaseId=$databaseId.',
        );
      } else {
        debugPrint(
          '[TPK][ADMIN] Firestore probe ${e.code}. Continuing with databaseId=$databaseId.',
        );
      }
    } on TimeoutException {
      debugPrint(
        '[TPK][ADMIN] Firestore probe timed out. Continuing with databaseId=$databaseId.',
      );
    } catch (e) {
      debugPrint(
        '[TPK][ADMIN] Firestore probe failed: $e. Continuing with databaseId=$databaseId.',
      );
    }
  }
}
