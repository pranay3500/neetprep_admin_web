import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'firebase_options.dart';
import 'src/admin_app.dart';
import 'src/services/firestore_db.dart';
import 'src/utils/webinar_schedule_timezone.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  WebinarScheduleTimezone.ensureInitialized();
  bool firebaseReady = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await FirestoreDb.initialize();
    firebaseReady = true;
  } catch (e, st) {
    debugPrint('[TPK][ADMIN] Firebase init failed: $e\n$st');
  }
  runApp(AdminApp(firebaseReady: firebaseReady));
}
