import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neetprep_admin_web/src/utils/firestore_payload.dart';

void main() {
  test('stripNulls removes null leaves and keeps nested maps', () {
    final out = FirestorePayload.stripNulls({
      'title': 'NEET update',
      'publishedAt': null,
      'publishConfig': {
        'status': 'published',
        'publishAt': null,
        'expiresAt': null,
      },
      'tags': ['a', null, 'b'],
    });

    expect(out['title'], 'NEET update');
    expect(out.containsKey('publishedAt'), isFalse);
    expect(out['publishConfig'], {
      'status': 'published',
    });
    expect(out['tags'], ['a', 'b']);
  });

  test('stripNulls preserves FieldValue and Timestamp', () {
    final ts = Timestamp.fromDate(DateTime(2026, 7, 7));
    final out = FirestorePayload.stripNulls({
      'updatedAt': FieldValue.serverTimestamp(),
      'date': ts,
    });
    expect(out['updatedAt'], isA<FieldValue>());
    expect(out['date'], ts);
  });
}
