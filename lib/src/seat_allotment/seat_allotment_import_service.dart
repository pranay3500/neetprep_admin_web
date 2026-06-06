import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/firestore_db.dart';
import 'seat_allotment_csv.dart';

/// Firestore: `seat_allotment_datasets/{datasetId}` + `rows` subcollection.
class SeatAllotmentImportService {
  SeatAllotmentImportService._();

  static CollectionReference<Map<String, dynamic>> get _datasets =>
      FirestoreDb.instance.collection('seat_allotment_datasets');

  static CollectionReference<Map<String, dynamic>> _rows(String datasetId) =>
      _datasets.doc(datasetId).collection('rows');

  static Future<void> importDataset({
    required String datasetId,
    required String title,
    required int examYear,
    required int round,
    required String counsellingType,
    required String sourceFileName,
    required List<SeatAllotmentRow> rows,
    void Function(int done, int total)? onProgress,
  }) async {
    final id = datasetId.trim();
    if (id.isEmpty) {
      throw ArgumentError('Dataset ID is required.');
    }
    if (rows.isEmpty) {
      throw ArgumentError('No rows to import.');
    }

    // Do not force-refresh token here — long imports (10k+ rows) can hit
    // firebase_auth/network-request-failed. Use tool/import_seat_allotment_csv.mjs instead.

    final datasetRef = _datasets.doc(id);
    final now = FieldValue.serverTimestamp();
    final filterOptions = buildFilterOptions(rows);

    // Create parent dataset first so subcollection rules can resolve the parent path.
    await datasetRef.set({
      'title': title.trim(),
      'examYear': examYear,
      'round': round,
      'counsellingType': counsellingType.trim(),
      'isPublished': false,
      'rowCount': 0,
      'sourceFileName': sourceFileName.trim(),
      'importedAt': now,
      'updatedAt': now,
      'filterOptions': filterOptions,
    }, SetOptions(merge: true));

    final existing = await _rows(id).limit(1).get();
    if (existing.docs.isNotEmpty) {
      await _deleteAllRows(id, onProgress: onProgress);
    }

    const chunkSize = 400;
    var written = 0;
    for (var start = 0; start < rows.length; start += chunkSize) {
      final end = (start + chunkSize > rows.length) ? rows.length : start + chunkSize;
      final batch = FirestoreDb.instance.batch();
      for (var i = start; i < end; i++) {
        final row = rows[i];
        final docId = '${row.rank}_${row.serialNo}';
        batch.set(_rows(id).doc(docId), {
          ...row.toFirestoreMap(),
          'datasetId': id,
          'importedAt': now,
        });
      }
      await batch.commit();
      written = end;
      onProgress?.call(written, rows.length);
    }

    await datasetRef.update({
      'rowCount': rows.length,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> _deleteAllRows(
    String datasetId, {
    void Function(int done, int total)? onProgress,
  }) async {
    const pageSize = 400;
    var deleted = 0;
    while (true) {
      final snap = await _rows(datasetId).limit(pageSize).get();
      if (snap.docs.isEmpty) break;
      final batch = FirestoreDb.instance.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      deleted += snap.docs.length;
      onProgress?.call(deleted, deleted);
      if (snap.docs.length < pageSize) break;
    }
  }

  static Future<void> setPublished(String datasetId, bool published) async {
    await _datasets.doc(datasetId.trim()).update({
      'isPublished': published,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
