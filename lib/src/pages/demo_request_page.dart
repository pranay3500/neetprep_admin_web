import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firestore_db.dart';
import 'analysis_sessions_page.dart';
import 'slots_management_page.dart';

class DemoRequestPage extends StatefulWidget {
  const DemoRequestPage({super.key});

  @override
  State<DemoRequestPage> createState() => _DemoRequestPageState();
}

class _DemoRequestPageState extends State<DemoRequestPage> {
  final _heroVideo = TextEditingController();
  final _howItWorks = TextEditingController();
  final _videos = TextEditingController();
  final _nriAlertVideos = TextEditingController();
  final _sampleReports = TextEditingController();
  bool _loaded = false;
  bool _saving = false;
  String _status = 'Ready';

  DocumentReference<Map<String, dynamic>> get _doc => FirestoreDb.instance
      .collection('demo_request_config')
      .doc('expected_score');

  static final _defaults = <String, dynamic>{
    'heroVideoUrl': 'https://www.youtube.com/watch?v=aircAruvnKk',
    'howItWorks': [
      {
        'title': 'Book a demo analysis',
        'description':
            'Choose the student grade, subjects, date and an admin-managed available slot.',
        'iconKey': 'calendar',
        'colorKey': 'blue',
        'order': 1,
        'isPublished': true,
      },
      {
        'title': 'Meet the academic team',
        'description':
            'The session reviews preparation level, subject comfort, and current NEET readiness.',
        'iconKey': 'analysis',
        'colorKey': 'purple',
        'order': 2,
        'isPublished': true,
      },
      {
        'title': 'Get expected score direction',
        'description':
            'After approval and review, the expected score status and next steps update in the app.',
        'iconKey': 'score',
        'colorKey': 'green',
        'order': 3,
        'isPublished': true,
      },
    ],
    'videos': [
      {
        'title': 'How NEET score analysis works',
        'url': 'https://www.youtube.com/watch?v=RtAPBZFLY7s',
        'order': 1,
        'isPublished': true,
      },
      {
        'title': 'Study planning for NRI students',
        'url': 'https://www.youtube.com/watch?v=Z9Ki2WJHsPo',
        'order': 2,
        'isPublished': true,
      },
      {
        'title': 'Parent counselling walkthrough',
        'url': 'https://www.youtube.com/watch?v=y1LQ3og9W2s',
        'order': 3,
        'isPublished': true,
      },
      {
        'title': 'Score improvement roadmap',
        'url': 'https://www.youtube.com/watch?v=8pDqJVdNa44',
        'order': 4,
        'isPublished': true,
      },
    ],
    'nriAlertVideos': [
      {
        'title': 'NRI admission alert',
        'url': 'https://www.youtube.com/watch?v=aircAruvnKk',
        'order': 1,
        'isPublished': true,
      },
      {
        'title': 'NRI quota document checklist',
        'url': 'https://www.youtube.com/watch?v=RtAPBZFLY7s',
        'order': 2,
        'isPublished': true,
      },
      {
        'title': 'Counselling timeline alert',
        'url': 'https://www.youtube.com/watch?v=Z9Ki2WJHsPo',
        'order': 3,
        'isPublished': true,
      },
    ],
    'sampleReports': [
      {
        'title': 'Sample report 1',
        'url': '',
        'order': 1,
        'isPublished': true,
      },
      {
        'title': 'Sample report 2',
        'url': '',
        'order': 2,
        'isPublished': true,
      },
      {
        'title': 'Sample report 3',
        'url': '',
        'order': 3,
        'isPublished': true,
      },
    ],
  };

  @override
  void dispose() {
    _heroVideo.dispose();
    _howItWorks.dispose();
    _videos.dispose();
    _nriAlertVideos.dispose();
    _sampleReports.dispose();
    super.dispose();
  }

  Future<void> _ensureDefaults() async {
    final snap = await _doc.get();
    if (!snap.exists) {
      await _doc.set({
        ..._defaults,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  void _load(Map<String, dynamic> data) {
    _heroVideo.text =
        data['heroVideoUrl']?.toString() ??
        _defaults['heroVideoUrl'].toString();
    _howItWorks.text = _joinRows(
      (data['howItWorks'] as List?) ?? (_defaults['howItWorks'] as List),
      ['title', 'description', 'iconKey', 'colorKey'],
    );
    _videos.text = _joinRows(
      (data['videos'] as List?) ?? (_defaults['videos'] as List),
      ['title', 'url'],
    );
    _nriAlertVideos.text = _joinRows(
      (data['nriAlertVideos'] as List?) ??
          (_defaults['nriAlertVideos'] as List),
      ['title', 'url'],
    );
    _sampleReports.text = _joinRows(
      (data['sampleReports'] as List?) ?? (_defaults['sampleReports'] as List),
      ['title', 'url'],
    );
    _loaded = true;
  }

  String _joinRows(List<dynamic> rows, List<String> keys) {
    return rows
        .whereType<Map>()
        .map((row) {
          return keys
              .map((key) => row[key]?.toString().trim() ?? '')
              .join(' | ');
        })
        .join('\n');
  }

  List<Map<String, dynamic>> _parseHowItWorks() {
    final lines = _howItWorks.text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    return lines.asMap().entries.map((entry) {
      final parts = entry.value.split('|').map((e) => e.trim()).toList();
      return {
        'title': parts.isNotEmpty ? parts[0] : '',
        'description': parts.length > 1 ? parts[1] : '',
        'iconKey': parts.length > 2 ? parts[2] : 'analysis',
        'colorKey': parts.length > 3 ? parts[3] : 'purple',
        'order': entry.key + 1,
        'isPublished': true,
      };
    }).toList();
  }

  List<Map<String, dynamic>> _parseVideos() {
    return _parseVideoRows(_videos.text);
  }

  List<Map<String, dynamic>> _parseVideoRows(String text) {
    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    return lines.asMap().entries.map((entry) {
      final parts = entry.value.split('|').map((e) => e.trim()).toList();
      return {
        'title': parts.isNotEmpty ? parts[0] : 'Video ${entry.key + 1}',
        'url': parts.length > 1 ? parts[1] : '',
        'order': entry.key + 1,
        'isPublished': true,
      };
    }).toList();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _status = 'Saving...';
    });
    try {
      await _doc
          .set({
            'heroVideoUrl': _heroVideo.text.trim(),
            'howItWorks': _parseHowItWorks(),
            'videos': _parseVideos(),
            'nriAlertVideos': _parseVideoRows(_nriAlertVideos.text),
            'sampleReports': _parseVideoRows(_sampleReports.text),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true))
          .timeout(const Duration(seconds: 12));
      if (!mounted) return;
      setState(() => _status = 'Saved');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Demo Request content saved.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Save failed');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirestoreDb.instance
                  .collection('analysis_session_requests')
                  .where('status', isEqualTo: 'pending_confirmation')
                  .limit(1)
                  .snapshots(),
              builder: (context, pendingSnapshot) {
                final hasPending =
                    (pendingSnapshot.data?.docs ?? const []).isNotEmpty;
                return TabBar(
                  tabs: [
                    const Tab(
                      icon: Icon(Icons.video_settings_rounded),
                      text: 'Content',
                    ),
                    const Tab(
                      icon: Icon(Icons.calendar_month_rounded),
                      text: 'Slots',
                    ),
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Badge(
                            isLabelVisible: false,
                            backgroundColor: hasPending
                                ? const Color(0xFFE53935)
                                : Colors.transparent,
                            child: const Icon(Icons.support_agent_rounded),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            hasPending
                                ? 'Demo Requests · new'
                                : 'Demo Requests',
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildContentTab(context),
                const SlotsManagementPage(),
                const AnalysisSessionsPage(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentTab(BuildContext context) {
    return FutureBuilder<void>(
      future: _ensureDefaults(),
      builder: (context, _) {
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _doc.snapshots(),
          builder: (context, snapshot) {
            if (!_loaded && snapshot.data?.data() != null) {
              _load(snapshot.data!.data()!);
            }
            return Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Demo Request CMS',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Controls Expected NEET Score hero video, How It Works, sample analysis report PDFs, bottom video tiles, and Dashboard NRIs Alert slider videos in the mobile app.',
                          ),
                          const SizedBox(height: 8),
                          Text('Doc path: demo_request_config/expected_score'),
                          Text('Status: $_status'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _heroVideo,
                    decoration: const InputDecoration(
                      labelText: 'Hero YouTube URL',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _howItWorks,
                    minLines: 5,
                    maxLines: 9,
                    decoration: const InputDecoration(
                      labelText: 'How It Works rows',
                      helperText:
                          'Format: title | description | iconKey(calendar/analysis/score) | colorKey(blue/purple/green)',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _videos,
                    minLines: 5,
                    maxLines: 9,
                    decoration: const InputDecoration(
                      labelText: 'Bottom video rows',
                      helperText: 'Format: title | YouTube URL',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _sampleReports,
                    minLines: 4,
                    maxLines: 7,
                    decoration: const InputDecoration(
                      labelText: 'Sample analysis report PDFs',
                      helperText:
                          'Expected NEET Score → Sample reports (tap opens in-app PDF). Format: title | HTTPS PDF URL. Up to 3 rows shown; leave URL empty to use bundled placeholder in app.',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nriAlertVideos,
                    minLines: 4,
                    maxLines: 7,
                    decoration: const InputDecoration(
                      labelText: 'Dashboard NRIs Alert video rows',
                      helperText:
                          'Only the first 3 published rows appear on dashboard. Format: title | YouTube URL',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_rounded),
                      label: const Text('Save Demo Request Content'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
