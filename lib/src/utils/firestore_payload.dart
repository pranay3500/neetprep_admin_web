import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore web helpers — null leaves break JS interop and can hang writes.
abstract final class FirestorePayload {
  /// Removes null leaves so Firestore web never receives `null` (JS interop:
  /// `null` is not an [Object] on some paths). Keeps [FieldValue] and [Timestamp].
  static Map<String, dynamic> stripNulls(Map<String, dynamic> input) {
    final out = <String, dynamic>{};
    Map<dynamic, dynamic>.from(input).forEach((k, v) {
      if (k == null || v == null) return;
      final stripped = _stripNullDeep(v);
      if (stripped != null) out[k.toString()] = stripped;
    });
    return out;
  }

  static dynamic _stripNullDeep(dynamic v) {
    if (v == null) return null;
    if (v is FieldValue || v is Timestamp) return v;
    if (v is Map) {
      final m = <String, dynamic>{};
      Map<dynamic, dynamic>.from(v).forEach((key, val) {
        if (key == null || val == null) return;
        final s = _stripNullDeep(val);
        if (s != null) m[key.toString()] = s;
      });
      return m;
    }
    if (v is List) {
      return v.map(_stripNullDeep).where((e) => e != null).toList();
    }
    return v;
  }

  static Future<DocumentReference<Map<String, dynamic>>> add(
    CollectionReference<Map<String, dynamic>> col,
    Map<String, dynamic> data, {
    Duration timeout = const Duration(seconds: 30),
  }) {
    return col
        .add(stripNulls(data))
        .timeout(
          timeout,
          onTimeout: () => throw TimeoutException(
            'Firestore save timed out after ${timeout.inSeconds}s. '
            'Check your connection and try again.',
          ),
        );
  }

  static Future<void> set(
    DocumentReference<Map<String, dynamic>> doc,
    Map<String, dynamic> data, {
    SetOptions? options,
    Duration timeout = const Duration(seconds: 30),
  }) {
    return doc
        .set(stripNulls(data), options)
        .timeout(
          timeout,
          onTimeout: () => throw TimeoutException(
            'Firestore save timed out after ${timeout.inSeconds}s. '
            'Check your connection and try again.',
          ),
        );
  }
}
