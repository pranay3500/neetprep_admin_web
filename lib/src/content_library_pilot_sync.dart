import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import 'content_library_body_cleaner.dart';
import 'content_library_remote_api.dart';
import 'services/firestore_db.dart';

/// Firestore: `content_library_published_nodes/{websiteNodeId}`.
const String kPublishedNodesCollection = 'content_library_published_nodes';

/// Firestore: `content_library_pilot/main` — which unit the app treats as pilot.
const String kPilotConfigCollection = 'content_library_pilot';
const String kPilotConfigDocId = 'main';

class ContentLibraryPilotSyncResult {
  const ContentLibraryPilotSyncResult({
    required this.unitSourceId,
    required this.unitTitle,
    required this.syncedCount,
    required this.skippedCount,
    required this.failed,
  });

  final String unitSourceId;
  final String unitTitle;
  final int syncedCount;
  final int skippedCount;
  final List<String> failed;
}

class ContentLibraryPilotSyncTarget {
  const ContentLibraryPilotSyncTarget({
    required this.sourceId,
    required this.title,
    required this.type,
  });

  final String sourceId;
  final String title;
  final String type;
}

/// Fetches API 2 per node, cleans HTML, writes Firestore for a single unit subtree.
class ContentLibraryPilotSync {
  static Future<ContentLibraryPilotSyncResult> syncUnitSubtree({
    required Uri treeListUri,
    required String unitSourceId,
    required String unitTitle,
    required List<ContentLibraryPilotSyncTarget> targets,
    required String pathTemplate,
    String? authToken,
    void Function(int done, int total, String label)? onProgress,
  }) async {
    final headers = <String, String>{'Accept': 'application/json'};
    final token = authToken?.trim() ?? '';
    if (token.isNotEmpty) {
      headers['Authorization'] =
          token.startsWith('Bearer ') ? token : 'Bearer $token';
    }

    var synced = 0;
    var skipped = 0;
    final failed = <String>[];
    final total = targets.length;

    for (var i = 0; i < targets.length; i++) {
      final t = targets[i];
      onProgress?.call(i, total, t.title);

      final uri = buildContentLibraryNodeContentUri(
        contentTreeListUri: treeListUri,
        nodeId: t.sourceId,
        pathTemplate: pathTemplate,
      );

      try {
        final resp = await http
            .get(uri, headers: headers)
            .timeout(const Duration(seconds: 60));
        if (resp.statusCode < 200 || resp.statusCode > 299) {
          failed.add('${t.sourceId}: HTTP ${resp.statusCode}');
          continue;
        }
        final ct = (resp.headers['content-type'] ?? '').toLowerCase();
        if (!ct.contains('application/json')) {
          failed.add('${t.sourceId}: non-JSON response');
          continue;
        }
        final decoded = jsonDecode(resp.body);
        final html = ContentLibraryBodyCleaner.htmlFromApi2Payload(decoded);
        if (html == null || html.trim().isEmpty) {
          skipped++;
          await FirestoreDb.instance
              .collection(kPublishedNodesCollection)
              .doc(t.sourceId)
              .set({
            'nodeId': t.sourceId,
            'title': t.title,
            'type': t.type,
            'contentSource': '',
            'empty': true,
            'syncedAt': FieldValue.serverTimestamp(),
            'cleanVersion': 1,
          }, SetOptions(merge: true));
          continue;
        }

        await FirestoreDb.instance
            .collection(kPublishedNodesCollection)
            .doc(t.sourceId)
            .set({
          'nodeId': t.sourceId,
          'title': t.title,
          'type': t.type,
          'contentSource': html,
          'contentLength': html.length,
          'empty': false,
          'syncedAt': FieldValue.serverTimestamp(),
          'cleanVersion': 1,
        }, SetOptions(merge: true));
        synced++;
      } catch (e) {
        failed.add('${t.sourceId}: $e');
      }
    }

    onProgress?.call(total, total, 'Saving pilot config');

    await FirestoreDb.instance
        .collection(kPilotConfigCollection)
        .doc(kPilotConfigDocId)
        .set({
      'enabledUnitSourceId': unitSourceId,
      'enabledUnitTitle': unitTitle,
      'nodeCount': targets.length,
      'syncedNodeCount': synced,
      'skippedEmptyCount': skipped,
      'failedCount': failed.length,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return ContentLibraryPilotSyncResult(
      unitSourceId: unitSourceId,
      unitTitle: unitTitle,
      syncedCount: synced,
      skippedCount: skipped,
      failed: failed,
    );
  }

  /// Collects API ids for [unit] and all descendants (depth-first).
  static List<ContentLibraryPilotSyncTarget> collectTargets({
    required String sourceId,
    required String title,
    required String type,
    required List<PilotTreeChild> children,
  }) {
    final out = <ContentLibraryPilotSyncTarget>[];
    void walk(String id, String t, String ty, List<PilotTreeChild> kids) {
      final sid = id.trim();
      if (sid.isNotEmpty) {
        out.add(ContentLibraryPilotSyncTarget(
          sourceId: sid,
          title: t,
          type: ty,
        ));
      }
      for (final c in kids) {
        walk(c.sourceId ?? '', c.title, c.type, c.children);
      }
    }

    walk(sourceId, title, type, children);
    return out;
  }
}

/// Minimal tree shape for pilot sync (built from admin hierarchy).
class PilotTreeChild {
  const PilotTreeChild({
    required this.title,
    required this.type,
    this.sourceId,
    this.children = const [],
  });

  final String title;
  final String type;
  final String? sourceId;
  final List<PilotTreeChild> children;
}
