import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../content_library_body_cleaner.dart';
import '../services/firestore_db.dart';

/// Published curriculum bodies for the mobile app (`content_library_published_nodes`).
class ContentLibraryPublishedService {
  static const String collection = 'content_library_published_nodes';

  static CollectionReference<Map<String, dynamic>> get _col =>
      FirestoreDb.instance.collection(collection);

  static Future<Map<String, dynamic>?> load(String nodeId) async {
    final id = nodeId.trim();
    if (id.isEmpty) return null;
    final snap = await _col.doc(id).get();
    return snap.data();
  }

  static Stream<Map<String, dynamic>?> watch(String nodeId) {
    final id = nodeId.trim();
    if (id.isEmpty) return const Stream.empty();
    return _col.doc(id).snapshots().map((s) => s.data());
  }

  static Future<void> save({
    required String nodeId,
    required String title,
    required String type,
    required String contentHtml,
    required String status,
  }) async {
    final id = nodeId.trim();
    if (id.isEmpty) throw ArgumentError('nodeId is required');
    final html = ContentLibraryBodyCleaner.sanitizeForFirestore(contentHtml);
    final user = FirebaseAuth.instance.currentUser;
    final data = <String, dynamic>{
      'nodeId': id,
      'title': title.trim(),
      'type': type.trim(),
      'contentSource': html,
      'contentLength': html.length,
      'empty': html.isEmpty,
      'status': status,
      'source': 'admin_editor',
      'editorVersion': 1,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': user?.email ?? user?.uid ?? 'admin',
    };
    if (status == 'published') {
      data['publishedAt'] = FieldValue.serverTimestamp();
    }
    await _col.doc(id).set(data, SetOptions(merge: true));
  }
}
