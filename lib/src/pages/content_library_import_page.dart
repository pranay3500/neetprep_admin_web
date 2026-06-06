import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../content_library_pilot_sync.dart';
import '../content_library_remote_api.dart';
import '../services/firestore_db.dart';
import '../widgets/admin_dialog_save_actions.dart';

Set<String> _parseFirestoreIdSetStatic(dynamic raw) {
  if (raw is! Iterable) return {};
  return raw
      .map((e) => e?.toString().trim() ?? '')
      .where((s) => s.isNotEmpty)
      .toSet();
}

Map<String, String> _parseNodePdfUrlsStatic(dynamic raw) {
  if (raw is! Map) return {};
  final out = <String, String>{};
  raw.forEach((key, value) {
    final id = key.toString().trim();
    final url = value?.toString().trim() ?? '';
    if (id.isNotEmpty && url.isNotEmpty) out[id] = url;
  });
  return out;
}

/// Keeps Auto/Lock/Free UI in sync without rebuilding the whole admin page on each Firestore tick.
class _HierarchyGatingNotifier extends ChangeNotifier {
  Set<String> freeIds = {};
  Set<String> lockedIds = {};
  Map<String, String> pdfUrls = {};
  final Map<String, int> selectionOverride = {};
  String? savingNodeId;
  String? savingPdfNodeId;

  void applyFirestore(Map<String, dynamic>? data) {
    final d = data ?? {};
    freeIds = _parseFirestoreIdSetStatic(
      d['alwaysFreeNodeIds'] ?? d['freeFullAccessNodeIds'],
    );
    lockedIds = _parseFirestoreIdSetStatic(
      d['alwaysLockedNodeIds'] ?? d['lockedNodeIds'],
    );
    pdfUrls = _parseNodePdfUrlsStatic(d['nodePdfUrls']);
    notifyListeners();
  }

  String? pdfUrlFor(String nodeId) => pdfUrls[nodeId];

  bool pdfBusyFor(String nodeId) => savingPdfNodeId == nodeId;

  void beginPdfSave(String nodeId) {
    savingPdfNodeId = nodeId;
    notifyListeners();
  }

  void endPdfSave() {
    savingPdfNodeId = null;
    notifyListeners();
  }

  void beginChipTap(String nodeId, int mode) {
    selectionOverride[nodeId] = mode;
    savingNodeId = nodeId;
    notifyListeners();
  }

  void endChipTap(String nodeId) {
    selectionOverride.remove(nodeId);
    savingNodeId = null;
    notifyListeners();
  }

  int selectionFor(String nodeId) =>
      selectionOverride[nodeId] ??
      (lockedIds.contains(nodeId)
          ? 1
          : (freeIds.contains(nodeId) ? 2 : 0));

  bool busyFor(String nodeId) => savingNodeId == nodeId;
}

class ContentLibraryImportPage extends StatefulWidget {
  const ContentLibraryImportPage({super.key});

  @override
  State<ContentLibraryImportPage> createState() => _ContentLibraryImportPageState();
}

class _ContentLibraryImportPageState extends State<ContentLibraryImportPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _apiUrlController = TextEditingController();
  final TextEditingController _nodeContentPathTemplateController =
      TextEditingController(
    text: kDefaultContentLibraryNodeContentPathTemplate,
  );
  final TextEditingController _authTokenController = TextEditingController();
  final TextEditingController _jsonPayloadController = TextEditingController();
  final TextEditingController _proxyUrlController = TextEditingController();
  final TextEditingController _timeoutSecondsController = TextEditingController(
    text: '180',
  );
  late final TabController _tabController;
  late final _HierarchyGatingNotifier _hierarchyGating;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _gatingFirestoreSub;

  bool _isFetching = false;
  bool _pilotSyncing = false;
  String? _pilotSyncMessage;
  String? _pilotSyncError;
  String? _fetchMessage;
  String? _fetchError;
  bool _useMockDetailFallback = true;
  bool _isLoadingDetail = false;
  String? _detailError;
  _NodeDetailPreview? _selectedDetail;

  DocumentReference<Map<String, dynamic>> get _cmsContentLibraryGatingDoc =>
      FirestoreDb.instance.collection('cms_content_library').doc('main');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _hierarchyGating = _HierarchyGatingNotifier();
    _gatingFirestoreSub =
        _cmsContentLibraryGatingDoc.snapshots().listen((snap) {
      _hierarchyGating.applyFirestore(snap.data());
    });
    unawaited(_loadSavedImportConfig());
  }

  @override
  void dispose() {
    _gatingFirestoreSub?.cancel();
    _hierarchyGating.dispose();
    _apiUrlController.dispose();
    _nodeContentPathTemplateController.dispose();
    _authTokenController.dispose();
    _jsonPayloadController.dispose();
    _proxyUrlController.dispose();
    _timeoutSecondsController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedImportConfig() async {
    try {
      final snap = await FirestoreDb.instance
          .collection('content_library_imports')
          .doc('config')
          .get();
      final data = snap.data();
      if (data == null || !mounted) return;
      _apiUrlController.text = (data['apiUrl'] ?? '').toString();
      final nodeTpl = (data['nodeContentPathTemplate'] ?? '').toString().trim();
      if (nodeTpl.isNotEmpty) {
        _nodeContentPathTemplateController.text = nodeTpl;
      } else {
        _nodeContentPathTemplateController.text =
            kDefaultContentLibraryNodeContentPathTemplate;
      }
      _authTokenController.text = (data['authToken'] ?? '').toString();
      _proxyUrlController.text = (data['proxyUrl'] ?? '').toString();
      _timeoutSecondsController.text = (data['timeoutSeconds'] ?? '180').toString();
      _useMockDetailFallback = data['useMockDetailFallback'] != false;
      setState(() {});
    } catch (_) {
      // Keep editor defaults when config read fails.
    }
  }

  Future<void> _saveImportConfig() async {
    await FirestoreDb.instance.collection('content_library_imports').doc('config').set({
      'apiUrl': _apiUrlController.text.trim(),
      'nodeContentPathTemplate': _nodeContentPathTemplateController.text.trim(),
      'authToken': _authTokenController.text.trim(),
      'proxyUrl': _proxyUrlController.text.trim(),
      'timeoutSeconds': int.tryParse(_timeoutSecondsController.text.trim()) ?? 180,
      'useMockDetailFallback': _useMockDetailFallback,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if (!mounted) return;
    setState(() {
      _fetchMessage = 'Import config saved.';
      _fetchError = null;
    });
  }

  Future<void> _openNodeDetail(_HierarchyNode node, {String? apiUrlOverride}) async {
    final apiUrl = (apiUrlOverride ?? _apiUrlController.text).trim();
    final apiUri = Uri.tryParse(apiUrl);
    if (apiUri == null || !apiUri.hasScheme || !apiUri.hasAuthority) {
      setState(() {
        _detailError = 'Set a valid API URL first so detail endpoint can be built.';
      });
      return;
    }

    var nodeId = node.sourceId?.trim() ?? '';
    if (nodeId.isEmpty) {
      nodeId = await _resolveNodeIdFromTreeApi(node, apiUri);
    }
    if (nodeId.isEmpty) {
      setState(() {
        _detailError =
            'This node has no source id and fallback resolution did not find a match.';
      });
      return;
    }

    final detailUri = buildContentLibraryNodeContentUri(
      contentTreeListUri: apiUri,
      nodeId: nodeId,
      pathTemplate: _nodeContentPathTemplateController.text,
    );

    setState(() {
      _isLoadingDetail = true;
      _detailError = null;
      _selectedDetail = null;
    });

    try {
      final resp = await http
          .get(detailUri, headers: const {'Accept': 'application/json'})
          .timeout(
            Duration(
              seconds: int.tryParse(_timeoutSecondsController.text.trim()) ?? 180,
            ),
          );
      final contentType = (resp.headers['content-type'] ?? '').toLowerCase();
      if (!contentType.contains('application/json')) {
        throw Exception(
          'Detail API returned non-JSON response (content-type: $contentType).',
        );
      }
      final decoded = jsonDecode(resp.body);
      final normalized = _normalizeApiPayload(decoded);
      if (normalized is! Map) {
        throw Exception('Detail payload is not an object.');
      }
      final map = Map<String, dynamic>.from(normalized);
      setState(() {
        _selectedDetail = _NodeDetailPreview(
          id: nodeId,
          title: (map['title'] ?? map['name'] ?? node.title).toString(),
          type: (map['type'] ?? node.type).toString(),
          content: (map['content'] ?? '').toString(),
          isMock: false,
        );
      });
    } catch (e) {
      if (_useMockDetailFallback) {
        setState(() {
          _selectedDetail = _NodeDetailPreview(
            id: nodeId,
            title: node.title,
            type: node.type,
            content:
                'Mock preview: detail API is not ready for this id yet.\n\n'
                'Expected endpoint (API 2): ${_nodeContentPathTemplateController.text.trim().isEmpty ? kDefaultContentLibraryNodeContentPathTemplate : _nodeContentPathTemplateController.text.trim()}\n'
                'Node id: $nodeId',
            isMock: true,
          );
          _detailError = null;
        });
      } else {
        setState(() {
          _detailError = 'Detail fetch failed: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingDetail = false);
      }
    }
  }

  Future<String> _resolveNodeIdFromTreeApi(_HierarchyNode node, Uri apiUri) async {
    try {
      final treeResp = await http
          .get(apiUri, headers: const {'Accept': 'application/json'})
          .timeout(
            Duration(
              seconds: int.tryParse(_timeoutSecondsController.text.trim()) ?? 180,
            ),
          );
      final contentType = (treeResp.headers['content-type'] ?? '').toLowerCase();
      if (!contentType.contains('application/json')) return '';
      final decoded = jsonDecode(treeResp.body);
      final forTree = _stripHeavyContentFields(decoded);
      final roots = _extractHierarchy(forTree);
      return _findNodeIdByTitleType(
            roots,
            title: node.title,
            type: node.type,
          ) ??
          '';
    } catch (_) {
      return '';
    }
  }

  String? _findNodeIdByTitleType(
    List<_HierarchyNode> nodes, {
    required String title,
    required String type,
  }) {
    for (final n in nodes) {
      final sameTitle = n.title.trim().toLowerCase() == title.trim().toLowerCase();
      final sameType = n.type.trim().toLowerCase() == type.trim().toLowerCase();
      if (sameTitle && sameType && (n.sourceId?.trim().isNotEmpty ?? false)) {
        return n.sourceId!.trim();
      }
      final childHit = _findNodeIdByTitleType(
        n.children,
        title: title,
        type: type,
      );
      if (childHit != null && childHit.isNotEmpty) return childHit;
    }
    return null;
  }

  Future<void> _saveImportedPayload({
    required String sourceLabel,
    required dynamic decoded,
    int? statusCode,
  }) async {
    // Drop huge HTML / body fields so admin only stores hierarchy metadata + tree labels.
    final forTree = _stripHeavyContentFields(decoded);
    final hierarchy = _extractHierarchy(forTree);
    final timeoutSeconds =
        int.tryParse(_timeoutSecondsController.text.trim()) ?? 180;
    final importId = DateTime.now().millisecondsSinceEpoch.toString();
    final flatNodes = _flattenHierarchy(hierarchy, importId: importId);
    await _saveFlatNodes(flatNodes);

    final payloadString = jsonEncode(forTree);
    final payloadSizeBytes = utf8.encode(payloadString).length;
    final payloadPreview =
        payloadString.length > 4000 ? '${payloadString.substring(0, 4000)}...' : payloadString;

    await FirestoreDb.instance.collection('content_library_imports').doc('main').set({
      'apiUrl': sourceLabel,
      'fetchedAt': FieldValue.serverTimestamp(),
      'statusCode': statusCode,
      'importId': importId,
      'timeoutSeconds': timeoutSeconds,
      'topLevelCount': hierarchy.length,
      'totalNodeCount': flatNodes.length,
      'payloadSizeBytes': payloadSizeBytes,
      'payloadPreview': payloadPreview,
      'hierarchyOnlyImport': true,
    }, SetOptions(merge: true));
    if (!mounted) return;
    setState(() {
      _fetchMessage = 'Import successful (structure only — large HTML/content fields omitted). '
          '${hierarchy.length} top-level item(s), ${flatNodes.length} tree node(s).';
      _fetchError = null;
    });
    _tabController.animateTo(1);
  }

  Future<void> _saveFlatNodes(List<_FlatNode> nodes) async {
    final collection = FirestoreDb.instance.collection('content_library_import_nodes');
    const batchSize = 400;
    for (var i = 0; i < nodes.length; i += batchSize) {
      final batch = FirestoreDb.instance.batch();
      final end = (i + batchSize > nodes.length) ? nodes.length : i + batchSize;
      for (var j = i; j < end; j++) {
        final node = nodes[j];
        batch.set(collection.doc(node.nodeId), node.toMap());
      }
      await batch.commit();
    }
  }

  Future<void> _fetchAndImport() async {
    final rawUrl = _apiUrlController.text.trim();
    if (rawUrl.isEmpty) {
      setState(() {
        _fetchError = 'Please paste your API URL first.';
        _fetchMessage = null;
      });
      return;
    }

    final uri = Uri.tryParse(rawUrl);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      setState(() {
        _fetchError = 'Invalid URL. Please enter a valid http/https API URL.';
        _fetchMessage = null;
      });
      return;
    }

    setState(() {
      _isFetching = true;
      _fetchError = null;
      _fetchMessage = null;
    });

    try {
      final headers = <String, String>{'Accept': 'application/json'};
      final tokenInput = _authTokenController.text.trim();
      if (tokenInput.isNotEmpty) {
        headers['Authorization'] = tokenInput.startsWith('Bearer ')
            ? tokenInput
            : 'Bearer $tokenInput';
      }

      final response = await http
          .get(uri, headers: headers)
          .timeout(
            Duration(
              seconds: int.tryParse(_timeoutSecondsController.text.trim()) ?? 180,
            ),
          );

      if (response.statusCode < 200 || response.statusCode > 299) {
        throw Exception(
          'API returned status ${response.statusCode}. Check endpoint/auth and try again.',
        );
      }

      final decoded = jsonDecode(response.body);
      await _saveImportedPayload(
        sourceLabel: rawUrl,
        decoded: decoded,
        statusCode: response.statusCode,
      );
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _fetchError = 'API request timed out. Please try again.';
        _fetchMessage = null;
      });
    } on http.ClientException catch (e) {
      if (!mounted) return;
      final proxyWorthy = kIsWeb && _isLikelyBrowserBlockedFetch(e);
      if (proxyWorthy) {
        try {
          final proxyResult = await _fetchViaCorsProxy(uri);
          await _saveImportedPayload(
            sourceLabel: proxyResult.sourceLabel,
            decoded: proxyResult.decoded,
            statusCode: 200,
          );
          return;
        } catch (_) {
          // Fall through to user-facing guidance below.
        }
      }
      setState(() {
        _fetchError = proxyWorthy
            ? 'Browser blocked or failed this API request (CORS / network). '
                'Allow your admin origin on the API, set a Proxy URL, or use “Paste JSON” below.'
            : 'Import failed: $e';
        _fetchMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().toLowerCase();
      if (kIsWeb &&
          msg.contains('clientexception') &&
          (msg.contains('network error') || msg.contains('failed to fetch'))) {
        try {
          final proxyResult = await _fetchViaCorsProxy(uri);
          await _saveImportedPayload(
            sourceLabel: proxyResult.sourceLabel,
            decoded: proxyResult.decoded,
            statusCode: 200,
          );
          return;
        } catch (_) {
          // Show generic error below.
        }
      }
      setState(() {
        _fetchError = 'Import failed: $e';
        _fetchMessage = null;
      });
    } finally {
      if (mounted) {
        setState(() => _isFetching = false);
      }
    }
  }

  Future<({dynamic decoded, String sourceLabel})> _fetchViaCorsProxy(Uri targetUri) async {
    final timeoutSeconds = int.tryParse(_timeoutSecondsController.text.trim()) ?? 180;
    final encoded = Uri.encodeComponent(targetUri.toString());
    final proxyUrls = <String>[];
    final customProxy = _proxyUrlController.text.trim();
    if (customProxy.isNotEmpty) {
      proxyUrls.add(
        customProxy.contains('{{url}}')
            ? customProxy.replaceAll('{{url}}', encoded)
            : '$customProxy$encoded',
      );
    }
    proxyUrls.addAll(<String>[
      'https://api.allorigins.win/raw?url=$encoded',
      'https://corsproxy.io/?$encoded',
    ]);

    Object? lastError;
    for (final proxyUrl in proxyUrls) {
      try {
        final proxyUri = Uri.parse(proxyUrl);
        final response = await http
            .get(proxyUri, headers: const {'Accept': 'application/json'})
            .timeout(Duration(seconds: timeoutSeconds));
        if (response.statusCode < 200 || response.statusCode > 299) {
          lastError = Exception('Proxy status ${response.statusCode}');
          continue;
        }
        final decoded = jsonDecode(response.body);
        return (decoded: decoded, sourceLabel: 'proxy:$proxyUrl -> $targetUri');
      } catch (e) {
        lastError = e;
      }
    }
    throw Exception('All proxy attempts failed: $lastError');
  }

  /// Pilot: API 2 → clean → Firestore for the **first unit** only (mobile reads Firestore).
  Future<void> _pilotSyncFirstUnit() async {
    final rawUrl = _apiUrlController.text.trim();
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      setState(() {
        _pilotSyncError = 'Set a valid API 1 URL first.';
        _pilotSyncMessage = null;
      });
      return;
    }

    setState(() {
      _pilotSyncing = true;
      _pilotSyncError = null;
      _pilotSyncMessage = 'Fetching tree…';
    });

    try {
      final headers = <String, String>{'Accept': 'application/json'};
      final tokenInput = _authTokenController.text.trim();
      if (tokenInput.isNotEmpty) {
        headers['Authorization'] = tokenInput.startsWith('Bearer ')
            ? tokenInput
            : 'Bearer $tokenInput';
      }

      final treeResp = await http
          .get(uri, headers: headers)
          .timeout(
            Duration(
              seconds: int.tryParse(_timeoutSecondsController.text.trim()) ??
                  180,
            ),
          );
      if (treeResp.statusCode < 200 || treeResp.statusCode > 299) {
        throw Exception('Tree API HTTP ${treeResp.statusCode}');
      }
      final roots = _extractHierarchy(jsonDecode(treeResp.body));
      final unitNode = _firstUnitForPilot(roots);
      final unitId = unitNode.sourceId?.trim() ?? '';
      if (unitId.isEmpty) {
        throw Exception(
          'First unit has no website id. Re-import tree or pick a unit with id.',
        );
      }

      final targets = ContentLibraryPilotSync.collectTargets(
        sourceId: unitId,
        title: unitNode.title,
        type: unitNode.type,
        children: unitNode.children.map(_pilotChildFromHierarchy).toList(),
      );
      if (targets.isEmpty) {
        throw Exception('No sync targets under first unit.');
      }

      if (!mounted) return;
      setState(() {
        _pilotSyncMessage =
            'Syncing ${targets.length} node(s) for “${unitNode.title}”…';
      });

      final result = await ContentLibraryPilotSync.syncUnitSubtree(
        treeListUri: uri,
        unitSourceId: unitId,
        unitTitle: unitNode.title,
        targets: targets,
        pathTemplate: _nodeContentPathTemplateController.text,
        authToken: _authTokenController.text,
        onProgress: (done, total, label) {
          if (!mounted) return;
          setState(() {
            _pilotSyncMessage = 'Syncing $done / $total — $label';
          });
        },
      );

      if (!mounted) return;
      final failPreview = result.failed.take(3).join('\n');
      setState(() {
        _pilotSyncMessage =
            'Pilot sync done for unit “${result.unitTitle}” (id: ${result.unitSourceId}).\n'
            'Stored: ${result.syncedCount} with HTML, ${result.skippedCount} empty, '
            '${result.failed.length} failed.\n'
            'Open that unit in the mobile app to verify Firestore content.';
        _pilotSyncError = result.failed.isEmpty
            ? null
            : 'Some nodes failed:\n$failPreview'
                '${result.failed.length > 3 ? '\n…' : ''}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pilotSyncError = 'Pilot sync failed: $e';
        _pilotSyncMessage = null;
      });
    } finally {
      if (mounted) {
        setState(() => _pilotSyncing = false);
      }
    }
  }

  _HierarchyNode _firstUnitForPilot(List<_HierarchyNode> roots) {
    var list = roots;
    if (list.length == 1) {
      final sole = list.first;
      final title = sole.title.trim().toLowerCase();
      if ((title.contains('neet planning') || title.contains('planning')) &&
          sole.children.isNotEmpty) {
        list = sole.children;
      }
    }
    if (list.isEmpty) {
      throw Exception('Tree has no units.');
    }
    return list.first;
  }

  PilotTreeChild _pilotChildFromHierarchy(_HierarchyNode node) {
    return PilotTreeChild(
      title: node.title,
      type: node.type,
      sourceId: node.sourceId,
      children: node.children.map(_pilotChildFromHierarchy).toList(),
    );
  }

  Future<void> _importFromPastedJson() async {
    final raw = _jsonPayloadController.text.trim();
    if (raw.isEmpty) {
      setState(() {
        _fetchError = 'Paste JSON payload first, then click Import Pasted JSON.';
        _fetchMessage = null;
      });
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      await _saveImportedPayload(
        sourceLabel: 'manual_json_input',
        decoded: decoded,
      );
    } catch (e) {
      setState(() {
        _fetchError = 'Invalid JSON payload: $e';
        _fetchMessage = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Content Library API Import',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          const SizedBox(height: 6),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Fetch JSON from your API and review the tree in the next tab. '
              'Imports keep titles and structure only; large HTML/content bodies are omitted.',
            ),
          ),
          const SizedBox(height: 14),
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(icon: Icon(Icons.cloud_download_rounded), text: 'API Import'),
              Tab(icon: Icon(Icons.account_tree_rounded), text: 'Imported Hierarchy'),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildImportTab(context),
                _buildHierarchyTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImportTab(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(
              controller: _apiUrlController,
              decoration: const InputDecoration(
                labelText: 'Content Library API URL (API 1 — tree)',
                hintText:
                    'https://www.testprepkart.com/self-study/api/tree/content/neet/neet-planning',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nodeContentPathTemplateController,
              decoration: const InputDecoration(
                labelText: 'API 2 — node content path template',
                hintText: '/self-study/api/content/{nodeId}',
                helperText:
                    'Relative to API 1 host, or a full https://… URL with {nodeId} or {id}. '
                    'Saved with Import config.',
                border: OutlineInputBorder(),
                alignLabelWithHint: false,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _authTokenController,
              decoration: const InputDecoration(
                labelText: 'Authorization token (optional)',
                hintText: 'Bearer token or raw token',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _proxyUrlController,
              decoration: const InputDecoration(
                labelText: 'Proxy URL (optional)',
                hintText: 'https://your-proxy.com/fetch?url={{url}}',
                border: OutlineInputBorder(),
                helperText: 'Use {{url}} placeholder for target API URL.',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _timeoutSecondsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Request timeout (seconds)',
                hintText: '180',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              value: _useMockDetailFallback,
              onChanged: _isFetching
                  ? null
                  : (v) => setState(() => _useMockDetailFallback = v),
              title: const Text('Use mock detail preview if detail API is not ready'),
              subtitle: const Text(
                'Lets you validate node-click flow before API 2 is stable. '
                'Adjust “API 2 — node content path template” above if the route changes.',
              ),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 12),
            const Divider(height: 20),
            const Text(
              'Pilot: Firestore-published content (mobile test)',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 6),
            const Text(
              'Fetches API 2 for every node under the **first unit** in the tree, '
              'cleans HTML, and saves to Firestore. The app reads that collection only '
              'for that unit (other units still use live API 2).',
              style: TextStyle(fontSize: 12, color: Color(0xFF616161)),
            ),
            const SizedBox(height: 10),
            FilledButton.tonalIcon(
              onPressed: (_isFetching || _pilotSyncing) ? null : _pilotSyncFirstUnit,
              icon: _pilotSyncing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.science_outlined),
              label: Text(
                _pilotSyncing
                    ? 'Pilot syncing…'
                    : 'Pilot sync first unit → Firestore',
              ),
            ),
            if (_pilotSyncMessage != null) ...[
              const SizedBox(height: 10),
              _InfoBanner(
                color: const Color(0xFF1565C0),
                icon: Icons.cloud_done_rounded,
                message: _pilotSyncMessage!,
              ),
            ],
            if (_pilotSyncError != null) ...[
              const SizedBox(height: 10),
              _InfoBanner(
                color: const Color(0xFFC62828),
                icon: Icons.error_outline_rounded,
                message: _pilotSyncError!,
              ),
            ],
            const SizedBox(height: 12),
            const Divider(height: 20),
            const SizedBox(height: 4),
            TextField(
              controller: _jsonPayloadController,
              maxLines: 8,
              minLines: 6,
              decoration: const InputDecoration(
                labelText: 'Paste JSON payload (fallback for CORS-blocked APIs)',
                hintText: '{"menus":[{"title":"...","units":[...]}]}',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: _isFetching ? null : _importFromPastedJson,
                  icon: const Icon(Icons.data_object_rounded),
                  label: const Text('Import Pasted JSON'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: _isFetching ? null : _fetchAndImport,
                  icon: _isFetching
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download_for_offline_rounded),
                  label: Text(_isFetching ? 'Fetching...' : 'Fetch & Import'),
                ),
                OutlinedButton.icon(
                  onPressed: _isFetching
                      ? null
                      : () {
                          _apiUrlController.clear();
                          _nodeContentPathTemplateController.text =
                              kDefaultContentLibraryNodeContentPathTemplate;
                          _authTokenController.clear();
                          _proxyUrlController.clear();
                          setState(() {
                            _fetchError = null;
                            _fetchMessage = null;
                          });
                        },
                  icon: const Icon(Icons.clear_rounded),
                  label: const Text('Clear'),
                ),
                OutlinedButton.icon(
                  onPressed: _isFetching ? null : _saveImportConfig,
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Save Config'),
                ),
              ],
            ),
            if (_fetchMessage != null) ...[
              const SizedBox(height: 12),
              _InfoBanner(
                color: const Color(0xFF2E7D32),
                icon: Icons.check_circle_rounded,
                message: _fetchMessage!,
              ),
            ],
            if (_fetchError != null) ...[
              const SizedBox(height: 12),
              _InfoBanner(
                color: const Color(0xFFC62828),
                icon: Icons.error_rounded,
                message: _fetchError!,
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              'Tip: {"success","data"} wrappers are handled automatically. '
              'If Fetch fails (CORS / network error), set Proxy URL or paste JSON. '
              'Page HTML fields such as content/html/body are stripped so only hierarchy remains.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHierarchyTab() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirestoreDb.instance
          .collection('content_library_imports')
          .doc('main')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data?.data();
        if (data == null) {
          return const Center(
            child: Text('No imported data yet. Use API Import tab first.'),
          );
        }

        final fetchedAt = data['fetchedAt'];
        final fetchedAtText = fetchedAt is Timestamp
            ? DateFormat('dd MMM yyyy, hh:mm a').format(fetchedAt.toDate())
            : 'Unknown';
        final importId = (data['importId'] ?? '').toString();
        final apiUrl = (data['apiUrl'] ?? '').toString();
        final statusCode = data['statusCode']?.toString() ?? '-';
        final totalNodeCount = data['totalNodeCount']?.toString() ?? '-';
        final payloadSizeBytes = data['payloadSizeBytes']?.toString() ?? '-';

        if (importId.isEmpty) {
          return const Card(
            child: Center(
              child: Text('No import session found yet.'),
            ),
          );
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirestoreDb.instance
              .collection('content_library_import_nodes')
              .where('importId', isEqualTo: importId)
              .snapshots(),
          builder: (context, nodesSnapshot) {
            if (nodesSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final flatNodes = (nodesSnapshot.data?.docs ?? const [])
                .map((doc) => _FlatNode.fromMap(doc.data()))
                .toList();
            final hierarchyFromNodes = _buildHierarchyFromFlatNodes(flatNodes);
            return ListenableBuilder(
              listenable: _hierarchyGating,
              builder: (context, _) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: hierarchyFromNodes.isEmpty
                        ? const Center(
                            child: Text(
                              'Import metadata exists, but parsed hierarchy nodes are empty.',
                            ),
                          )
                        : ListView(
                            key: const PageStorageKey<String>(
                              'content_library_import_hierarchy_list',
                            ),
                            children: [
                              Text(
                                'Last imported hierarchy',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Text('API: $apiUrl'),
                              Text('HTTP status: $statusCode'),
                              Text('Imported at: $fetchedAtText'),
                              Text('Top-level menus: ${hierarchyFromNodes.length}'),
                              Text('Total nodes: $totalNodeCount'),
                              Text('Payload bytes: $payloadSizeBytes'),
                              const Divider(height: 24),
                              _InfoBanner(
                                color: const Color(0xFF1565C0),
                                icon: Icons.phonelink_setup_rounded,
                                message:
                                    'Per row: Auto / Lock / Free control paywall (saved to cms_content_library/main). Orange PDF icon = direct HTTPS link to the full PDF for subscribed mobile users (nodePdfUrls).',
                              ),
                              const SizedBox(height: 12),
                              ..._buildVisibleHierarchy(
                                hierarchyFromNodes: hierarchyFromNodes,
                                flatNodes: flatNodes,
                                apiUrl: apiUrl,
                              ),
                              const Divider(height: 24),
                              Text(
                                'Node Detail Preview',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              if (_isLoadingDetail)
                                const LinearProgressIndicator()
                              else if (_detailError != null)
                                _InfoBanner(
                                  color: const Color(0xFFC62828),
                                  icon: Icons.error_outline_rounded,
                                  message: _detailError!,
                                )
                              else if (_selectedDetail == null)
                                const Text(
                                  'Click the eye icon on any node row to preview its detail.',
                                )
                              else
                                _buildDetailCard(_selectedDetail!),
                            ],
                          ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  List<Widget> _buildVisibleHierarchy({
    required List<_HierarchyNode> hierarchyFromNodes,
    required List<_FlatNode> flatNodes,
    required String apiUrl,
  }) {
    final visibleCount = _countHierarchyNodes(hierarchyFromNodes);
    if (visibleCount >= flatNodes.length || flatNodes.isEmpty) {
      return hierarchyFromNodes
          .map(
            (node) => _buildNodeTile(
              node,
              depth: 0,
              apiUrl: apiUrl,
            ),
          )
          .toList();
    }
    final ordered = [...flatNodes]
      ..sort((a, b) {
        final aOrder = int.tryParse(a.nodeId.split('_').last) ?? 0;
        final bOrder = int.tryParse(b.nodeId.split('_').last) ?? 0;
        return aOrder.compareTo(bOrder);
      });
    return [
      const Text(
        'Showing fallback hierarchy view from imported node records.',
      ),
      const SizedBox(height: 8),
      ...ordered.map(
        (n) => _buildFlatNodeTile(
          n,
          apiUrl: apiUrl,
        ),
      ),
    ];
  }

  int _countHierarchyNodes(List<_HierarchyNode> nodes) {
    var count = 0;
    for (final n in nodes) {
      count += 1 + _countHierarchyNodes(n.children);
    }
    return count;
  }

  Widget _buildFlatNodeTile(
    _FlatNode node, {
    required String apiUrl,
  }) {
    final icon = switch (node.type.toLowerCase()) {
      'menu' => Icons.menu_book_rounded,
      'unit' => Icons.folder_rounded,
      'chapter' => Icons.article_rounded,
      'topic' => Icons.topic_rounded,
      _ => Icons.label_outline_rounded,
    };
    final title = '${node.title} (${node.type})';
    final id = node.sourceId?.trim();
    return Padding(
      padding: EdgeInsets.only(left: node.depth * 12.0, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Icon(icon, size: 22),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
                if (id != null && id.isNotEmpty)
                  Text(
                    'ID: $id',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade700,
                      fontFamily: 'monospace',
                    ),
                  ),
              ],
            ),
          ),
          _buildNodeAccessToggleBar(id),
          IconButton(
            tooltip: 'Preview detail',
            icon: const Icon(Icons.visibility_outlined),
            onPressed: () => _openNodeDetail(
              _HierarchyNode(
                title: node.title,
                type: node.type,
                sourceId: node.sourceId,
                children: const [],
              ),
              apiUrlOverride: apiUrl,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNodeTile(
    _HierarchyNode node, {
    required int depth,
    required String apiUrl,
  }) {
    final icon = switch (node.type.toLowerCase()) {
      'menu' => Icons.menu_book_rounded,
      'unit' => Icons.folder_rounded,
      'chapter' => Icons.article_rounded,
      'topic' => Icons.topic_rounded,
      _ => Icons.label_outline_rounded,
    };

    final title = '${node.title} (${node.type})';
    final id = node.sourceId?.trim();
    return Padding(
      padding: EdgeInsets.only(left: depth * 12.0, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Icon(icon, size: 22),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
                    if (node.children.isNotEmpty)
                      Text(
                        '${node.children.length} item(s)',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    if (id != null && id.isNotEmpty)
                      Text(
                        'ID: $id',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade700,
                          fontFamily: 'monospace',
                        ),
                      ),
                  ],
                ),
              ),
              _buildNodeAccessToggleBar(id),
              IconButton(
                tooltip: 'Preview detail',
                icon: const Icon(Icons.visibility_outlined),
                onPressed: () => _openNodeDetail(node, apiUrlOverride: apiUrl),
              ),
            ],
          ),
          if (node.children.isNotEmpty)
            ...node.children.map(
              (child) =>               _buildNodeTile(
                child,
                depth: depth + 1,
                apiUrl: apiUrl,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailCard(_NodeDetailPreview detail) {
    final content = detail.content.trim();
    final snippet =
        content.isEmpty ? 'No content returned.' : content.substring(0, content.length > 1200 ? 1200 : content.length);
    return Card(
      margin: const EdgeInsets.only(top: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${detail.title} (${detail.type})'),
            Text('ID: ${detail.id}'),
            if (detail.isMock) const Text('Using mock fallback preview'),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7FB),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(snippet),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _persistNodePdfUrl(String nodeId, String? url) async {
    if (nodeId.isEmpty) return;
    _hierarchyGating.beginPdfSave(nodeId);
    try {
      await FirestoreDb.instance.runTransaction((txn) async {
        final snap = await txn.get(_cmsContentLibraryGatingDoc);
        final data = snap.data() ?? {};
        final map = _parseNodePdfUrlsStatic(data['nodePdfUrls']);
        var trimmed = url?.trim() ?? '';
        if (trimmed.isNotEmpty) {
          final parsed = Uri.tryParse(trimmed);
          if (parsed == null || !parsed.hasScheme) {
            trimmed = 'https://$trimmed';
          }
        }
        if (trimmed.isEmpty) {
          map.remove(nodeId);
        } else {
          map[nodeId] = trimmed;
        }
        txn.set(
          _cmsContentLibraryGatingDoc,
          {
            'nodePdfUrls': map,
            'updatedAt': FieldValue.serverTimestamp(),
            'updatedBy': FirebaseAuth.instance.currentUser?.email ??
                FirebaseAuth.instance.currentUser?.uid ??
                'content_library_import_ui',
          },
          SetOptions(merge: true),
        );
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              (url?.trim().isEmpty ?? true)
                  ? 'PDF URL removed for this node.'
                  : 'PDF URL saved for this node.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save PDF URL: $e')),
        );
      }
    } finally {
      if (mounted) {
        _hierarchyGating.endPdfSave();
      }
    }
  }

  Future<void> _showNodePdfUrlDialog(String nodeId) async {
    final controller = TextEditingController(
      text: _hierarchyGating.pdfUrlFor(nodeId) ?? '',
    );
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Content PDF URL'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Node ID: $nodeId',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade700,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Paste the full public PDF link (must start with https:// and end with .pdf). '
                'The Node ID above is only the content key — not the URL. '
                'PDF on Stage 1 applies to that stage and its chapters in the app.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'PDF URL',
                  hintText: 'https://…/chapter.pdf',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.url,
                autofocus: true,
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              controller.clear();
            },
            child: const Text('Clear'),
          ),
          AdminDialogSaveActions(
            dialogContext: ctx,
            showCancel: false,
            savedMessage: 'PDF URL saved.',
            onSave: () async {
              final value = controller.text.trim();
              if (value.isNotEmpty &&
                  !value.startsWith('http://') &&
                  !value.startsWith('https://')) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Enter a full PDF link starting with https:// (not just a file name).',
                    ),
                  ),
                );
                return false;
              }
              await _persistNodePdfUrl(nodeId, value);
              return true;
            },
          ),
        ],
      ),
    );
    controller.dispose();
  }

  Future<void> _persistNodeGatingAccess(String nodeId, int mode) async {
    if (nodeId.isEmpty) return;
    try {
      await FirestoreDb.instance.runTransaction((txn) async {
        final snap = await txn.get(_cmsContentLibraryGatingDoc);
        final data = snap.data() ?? {};
        var free = _parseFirestoreIdSetStatic(
          data['alwaysFreeNodeIds'] ?? data['freeFullAccessNodeIds'],
        );
        var locked = _parseFirestoreIdSetStatic(
          data['alwaysLockedNodeIds'] ?? data['lockedNodeIds'],
        );
        free.remove(nodeId);
        locked.remove(nodeId);
        if (mode == 1) {
          locked.add(nodeId);
        } else if (mode == 2) {
          free.add(nodeId);
        }
        final freeList = free.toList()..sort();
        final lockedList = locked.toList()..sort();
        txn.set(
          _cmsContentLibraryGatingDoc,
          {
            'alwaysFreeNodeIds': freeList,
            'alwaysLockedNodeIds': lockedList,
            'updatedAt': FieldValue.serverTimestamp(),
            'updatedBy': FirebaseAuth.instance.currentUser?.email ??
                FirebaseAuth.instance.currentUser?.uid ??
                'content_library_import_ui',
          },
          SetOptions(merge: true),
        );
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save access: $e')),
        );
      }
    } finally {
      if (mounted) {
        _hierarchyGating.endChipTap(nodeId);
      }
    }
  }

  Widget _buildNodeAccessToggleBar(
    String? nodeId,
  ) {
    if (nodeId == null || nodeId.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Tooltip(
          message:
              'No content API id on this row. Use an import where each node has id, or edit comma lists under Settings → Content Library.',
          child: Icon(Icons.link_off_outlined, size: 22, color: Colors.grey.shade500),
        ),
      );
    }
    final busy = _hierarchyGating.busyFor(nodeId);
    final pdfBusy = _hierarchyGating.pdfBusyFor(nodeId);
    final selection = _hierarchyGating.selectionFor(nodeId);
    final hasPdf = _hierarchyGating.pdfUrlFor(nodeId) != null;
    return Tooltip(
      message:
          'Non‑premium users in the app: Auto = tier defaults; Lock = paywall/blur; Free = full content. PDF icon = full PDF URL for subscribed users.',
      child: Padding(
        padding: const EdgeInsets.only(right: 4),
        child: SizedBox(
          height: 36,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _accessModeChip(
                label: 'Auto',
                selected: selection == 0,
                busy: busy,
                nodeId: nodeId,
                selectedBg: const Color(0xFFECEFF1),
                selectedFg: const Color(0xFF37474F),
                mode: 0,
              ),
              const SizedBox(width: 4),
              _accessModeChip(
                label: 'Lock',
                selected: selection == 1,
                busy: busy,
                nodeId: nodeId,
                selectedBg: const Color(0xFFFFCDD2),
                selectedFg: const Color(0xFFB71C1C),
                mode: 1,
              ),
              const SizedBox(width: 4),
              _accessModeChip(
                label: 'Free',
                selected: selection == 2,
                busy: busy,
                nodeId: nodeId,
                selectedBg: const Color(0xFFC8E6C9),
                selectedFg: const Color(0xFF1B5E20),
                mode: 2,
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: hasPdf
                    ? 'Edit PDF URL (configured)'
                    : 'Set PDF URL for subscribed app users',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                onPressed: pdfBusy ? null : () => _showNodePdfUrlDialog(nodeId),
                icon: pdfBusy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        Icons.picture_as_pdf_rounded,
                        size: 22,
                        color: hasPdf
                            ? const Color(0xFFE65100)
                            : Colors.grey.shade600,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _accessModeChip({
    required String label,
    required int mode,
    required bool selected,
    required bool busy,
    required String nodeId,
    required Color selectedBg,
    required Color selectedFg,
  }) {
    return Material(
      key: ValueKey<String>('gate_${nodeId}_$mode'),
      color: selected ? selectedBg : const Color(0xFFF5F5F5),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: busy
            ? null
            : () {
                _hierarchyGating.beginChipTap(nodeId, mode);
                unawaited(_persistNodeGatingAccess(nodeId, mode));
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy && selected)
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: selectedFg,
                  ),
                )
              else
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: selected ? selectedFg : Colors.black45,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Flutter Web often surfaces CORS / TLS issues as [http.ClientException].
  bool _isLikelyBrowserBlockedFetch(http.ClientException e) {
    final m = e.message.toLowerCase();
    return m.contains('failed to fetch') ||
        m.contains('network error') ||
        m.contains('xmlhttprequest') ||
        m.contains('connection error') ||
        m.contains('connection refused') ||
        m.contains('connection reset');
  }

  /// Removes large page-body fields so imports stay hierarchy metadata only (names, ids, nesting).
  dynamic _stripHeavyContentFields(dynamic value) {
    if (value is List) {
      return value.map(_stripHeavyContentFields).toList();
    }
    if (value is! Map) return value;
    final map = Map<String, dynamic>.from(value);
    for (final key in List<String>.from(map.keys)) {
      final lk = key.toLowerCase();
      if (_heavyHtmlFieldKeys.contains(lk)) {
        map.remove(key);
        continue;
      }
      final child = map[key];
      if (child is Map || child is List) {
        map[key] = _stripHeavyContentFields(child);
      } else if (child is String &&
          child.length > _maxInlineStringChars &&
          lk.contains('content')) {
        map.remove(key);
      }
    }
    return map;
  }

  dynamic _tryDecodeJsonString(dynamic value) {
    if (value is! String) return value;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return value;
    if (!(trimmed.startsWith('{') || trimmed.startsWith('['))) return value;
    try {
      return jsonDecode(trimmed);
    } catch (_) {
      return value;
    }
  }

  /// Website/proxy responses can be wrapped several times. Normalize to the actual tree payload.
  dynamic _normalizeApiPayload(dynamic decoded) {
    var current = _tryDecodeJsonString(decoded);
    var guard = 0;
    while (guard++ < 8) {
      current = _tryDecodeJsonString(current);
      if (current is! Map) return current;
      final m = Map<String, dynamic>.from(current);

      if (m.containsKey('contents')) {
        current = _tryDecodeJsonString(m['contents']);
        continue;
      }
      if (m.containsKey('body')) {
        current = _tryDecodeJsonString(m['body']);
        continue;
      }
      if (m.containsKey('data')) {
        current = _tryDecodeJsonString(m['data']);
        continue;
      }
      if (m.containsKey('result')) {
        current = _tryDecodeJsonString(m['result']);
        continue;
      }
      break;
    }
    return current;
  }

  List<_HierarchyNode> _extractHierarchy(dynamic rawPayload) {
    final payload = _normalizeApiPayload(rawPayload);
    final roots = <_HierarchyNode>[];

    if (payload is List) {
      for (var i = 0; i < payload.length; i++) {
        final node = _parseNode(payload[i], fallbackTitle: 'Menu ${i + 1}');
        if (node != null) roots.add(node);
      }
      return roots;
    }

    if (payload is! Map) return roots;
    final map = Map<String, dynamic>.from(payload);

    for (final key in _childrenKeys) {
      final value = map[key];
      if (value is List && value.isNotEmpty) {
        for (var i = 0; i < value.length; i++) {
          final node = _parseNode(
            value[i],
            fallbackTitle: '${_toTitleCase(_singularize(key))} ${i + 1}',
            preferredType: _singularize(key),
          );
          if (node != null) roots.add(node);
        }
        if (roots.isNotEmpty) return roots;
      }
    }

    // Singleton roots (e.g. TestprepKart `/tree/content/...` → `data.exam`)
    for (final key in _singletonRootKeys) {
      final value = map[key];
      if (value is Map) {
        final childMap = Map<String, dynamic>.from(value);
        final title =
            _resolveTitle(childMap) ?? _toTitleCase(key);
        final node = _parseNode(
          value,
          fallbackTitle: title,
          preferredType: key,
        );
        if (node != null) roots.add(node);
      }
    }
    if (roots.isNotEmpty) return roots;

    // Generic wrapper objects: if object/list values exist, treat those as roots.
    for (final entry in map.entries) {
      final key = entry.key;
      if (_wrapperMetaKeys.contains(key.toLowerCase())) continue;
      final value = entry.value;
      if (value is List) {
        for (var i = 0; i < value.length; i++) {
          final node = _parseNode(
            value[i],
            fallbackTitle: '${_toTitleCase(_singularize(key))} ${i + 1}',
            preferredType: _singularize(key),
          );
          if (node != null) roots.add(node);
        }
      } else if (value is Map) {
        final node = _parseNode(
          value,
          fallbackTitle: _toTitleCase(key),
          preferredType: key,
        );
        if (node != null) roots.add(node);
      }
    }
    if (roots.isNotEmpty) return roots;

    final selfNode = _parseNode(map, fallbackTitle: 'Root Menu', preferredType: 'menu');
    if (selfNode != null) {
      roots.add(selfNode);
    }
    return roots;
  }

  _HierarchyNode? _parseNode(
    dynamic value, {
    required String fallbackTitle,
    String? preferredType,
  }) {
    if (value is String) {
      final title = value.trim();
      if (title.isEmpty) return null;
      return _HierarchyNode(
        title: title,
        type: preferredType ?? 'item',
        sourceId: null,
        children: const [],
      );
    }
    if (value is! Map) return null;

    final map = Map<String, dynamic>.from(value);
    final title = _resolveTitle(map) ?? fallbackTitle;
    final type = (map['type']?.toString().trim().isNotEmpty ?? false)
        ? map['type'].toString().trim()
        : (map['level']?.toString().trim().isNotEmpty ?? false)
            ? map['level'].toString().trim()
            : (preferredType ?? 'item');

    final children = <_HierarchyNode>[];
    for (final key in _childrenKeys) {
      final childValue = map[key];
      if (childValue is List) {
        for (var i = 0; i < childValue.length; i++) {
          final parsed = _parseNode(
            childValue[i],
            fallbackTitle: '${_toTitleCase(_singularize(key))} ${i + 1}',
            preferredType: _singularize(key),
          );
          if (parsed != null) children.add(parsed);
        }
      } else if (childValue is Map) {
        final parsed = _parseNode(
          childValue,
          fallbackTitle: _toTitleCase(_singularize(key)),
          preferredType: _singularize(key),
        );
        if (parsed != null) children.add(parsed);
      }
    }

    final sourceId = map['id']?.toString() ?? map['_id']?.toString();
    return _HierarchyNode(
      title: title,
      type: type,
      sourceId: sourceId,
      children: children,
    );
  }

  String? _resolveTitle(Map<String, dynamic> map) {
    for (final key in _titleKeys) {
      final value = map[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  String _singularize(String key) {
    final clean = key.trim();
    if (clean.endsWith('ies')) {
      return '${clean.substring(0, clean.length - 3)}y';
    }
    if (clean.endsWith('s') && clean.length > 1) {
      return clean.substring(0, clean.length - 1);
    }
    return clean;
  }

  String _toTitleCase(String input) {
    if (input.isEmpty) return input;
    final normalized = input.replaceAll('_', ' ');
    return normalized[0].toUpperCase() + normalized.substring(1);
  }

  List<_FlatNode> _flattenHierarchy(
    List<_HierarchyNode> roots, {
    required String importId,
  }) {
    final result = <_FlatNode>[];
    var globalOrder = 0;

    void walk(
      _HierarchyNode node, {
      required String? parentId,
      required int depth,
      required int siblingIndex,
    }) {
      final nodeId = '${importId}_${globalOrder++}';
      result.add(
        _FlatNode(
          nodeId: nodeId,
          importId: importId,
          parentId: parentId,
          title: node.title,
          type: node.type,
          depth: depth,
          siblingIndex: siblingIndex,
          sourceId: node.sourceId,
        ),
      );
      for (var i = 0; i < node.children.length; i++) {
        walk(
          node.children[i],
          parentId: nodeId,
          depth: depth + 1,
          siblingIndex: i,
        );
      }
    }

    for (var i = 0; i < roots.length; i++) {
      walk(roots[i], parentId: null, depth: 0, siblingIndex: i);
    }
    return result;
  }

  List<_HierarchyNode> _buildHierarchyFromFlatNodes(List<_FlatNode> flatNodes) {
    if (flatNodes.isEmpty) return const [];
    final byId = <String, _MutableNode>{};
    final roots = <_MutableNode>[];
    final sorted = [...flatNodes]
      ..sort((a, b) {
        final depthCompare = a.depth.compareTo(b.depth);
        if (depthCompare != 0) return depthCompare;
        return a.nodeId.compareTo(b.nodeId);
      });

    for (final node in sorted) {
      final mutable = _MutableNode(
        title: node.title,
        type: node.type,
        siblingIndex: node.siblingIndex,
        sourceId: node.sourceId,
      );
      byId[node.nodeId] = mutable;
      if (node.parentId == null || !byId.containsKey(node.parentId)) {
        roots.add(mutable);
      } else {
        byId[node.parentId]!.children.add(mutable);
      }
    }

    void sortChildren(_MutableNode node) {
      node.children.sort((a, b) => a.siblingIndex.compareTo(b.siblingIndex));
      for (final child in node.children) {
        sortChildren(child);
      }
    }

    roots.sort((a, b) => a.siblingIndex.compareTo(b.siblingIndex));
    for (final root in roots) {
      sortChildren(root);
    }
    return roots.map((e) => e.toHierarchyNode()).toList();
  }
}

class _HierarchyNode {
  const _HierarchyNode({
    required this.title,
    required this.type,
    required this.children,
    this.sourceId,
  });

  final String title;
  final String type;
  final List<_HierarchyNode> children;
  final String? sourceId;

  Map<String, dynamic> toMap() => {
        'title': title,
        'type': type,
        'sourceId': sourceId,
        'children': children.map((e) => e.toMap()).toList(),
      };

  factory _HierarchyNode.fromMap(Map<String, dynamic> map) {
    final children = (map['children'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => _HierarchyNode.fromMap(Map<String, dynamic>.from(e)))
        .toList();
    return _HierarchyNode(
      title: (map['title'] ?? 'Untitled').toString(),
      type: (map['type'] ?? 'item').toString(),
      sourceId: map['sourceId']?.toString(),
      children: children,
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.color,
    required this.icon,
    required this.message,
  });

  final Color color;
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        border: Border.all(color: color.withOpacity(0.35)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _FlatNode {
  const _FlatNode({
    required this.nodeId,
    required this.importId,
    required this.parentId,
    required this.title,
    required this.type,
    required this.depth,
    required this.siblingIndex,
    this.sourceId,
  });

  final String nodeId;
  final String importId;
  final String? parentId;
  final String title;
  final String type;
  final int depth;
  final int siblingIndex;
  final String? sourceId;

  Map<String, dynamic> toMap() => {
        'nodeId': nodeId,
        'importId': importId,
        'parentId': parentId,
        'title': title,
        'type': type,
        'depth': depth,
        'siblingIndex': siblingIndex,
        'sourceId': sourceId,
      };

  factory _FlatNode.fromMap(Map<String, dynamic> map) {
    return _FlatNode(
      nodeId: (map['nodeId'] ?? '').toString(),
      importId: (map['importId'] ?? '').toString(),
      parentId: map['parentId']?.toString(),
      title: (map['title'] ?? 'Untitled').toString(),
      type: (map['type'] ?? 'item').toString(),
      depth: (map['depth'] as num?)?.toInt() ?? 0,
      siblingIndex: (map['siblingIndex'] as num?)?.toInt() ?? 0,
      sourceId: map['sourceId']?.toString(),
    );
  }
}

class _MutableNode {
  _MutableNode({
    required this.title,
    required this.type,
    required this.siblingIndex,
    this.sourceId,
  });

  final String title;
  final String type;
  final int siblingIndex;
  final String? sourceId;
  final List<_MutableNode> children = [];

  _HierarchyNode toHierarchyNode() {
    return _HierarchyNode(
      title: title,
      type: type,
      sourceId: sourceId,
      children: children.map((e) => e.toHierarchyNode()).toList(),
    );
  }
}

class _NodeDetailPreview {
  const _NodeDetailPreview({
    required this.id,
    required this.title,
    required this.type,
    required this.content,
    required this.isMock,
  });

  final String id;
  final String title;
  final String type;
  final String content;
  final bool isMock;
}

const _titleKeys = <String>[
  'title',
  'name',
  'label',
  'menuTitle',
  'unitName',
  'chapterName',
  'topicName',
  'subTopicName',
  'slug',
  'id',
];

const _childrenKeys = <String>[
  'menus',
  'menu',
  'units',
  'chapters',
  'topics',
  'subTopics',
  'subtopics',
  'items',
  'children',
  'results',
  'nodes',
  'lessons',
  'modules',
];

/// Single-object roots after unwrapping `data` (e.g. NEET planning tree).
const _singletonRootKeys = <String>[
  'exam',
  'tree',
  'root',
  'planning',
  'course',
];

/// Field names that usually hold full HTML / editor blobs (omit from hierarchy imports).
const _heavyHtmlFieldKeys = <String>{
  'content',
  'html',
  'body',
  'richtext',
  'rawhtml',
  'htmlcontent',
  'markup',
  'articlebody',
  'markdown',
  'ckeditor',
  'innerhtml',
  'fullcontent',
  'pagecontent',
  'descriptionhtml',
  'metadescription',
};

const _wrapperMetaKeys = <String>{
  'success',
  'message',
  'status',
  'statuscode',
  'error',
  'errors',
  'meta',
  'headers',
};

/// Strings longer than this whose key suggests HTML are dropped (safety net).
const int _maxInlineStringChars = 24000;
