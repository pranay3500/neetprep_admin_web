import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../seat_allotment/seat_allotment_csv.dart';
import '../seat_allotment/seat_allotment_import_service.dart';
import '../seat_allotment/seat_allotment_write_probe.dart';
import '../services/firestore_db.dart';
import '../utils/csv_file_pick_web.dart';

/// Admin CMS for counselling seat allotment CSV → Firestore → mobile tool.
class SeatAllotmentPage extends StatelessWidget {
  const SeatAllotmentPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SeatAllotmentTabHeader(),
          SizedBox(height: 8),
          Expanded(
            child: TabBarView(
              children: [
                _CsvImportTab(),
                _DatasetsTab(),
                _MobileBundleTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SeatAllotmentTabHeader extends StatelessWidget {
  const _SeatAllotmentTabHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Seat Allotment',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'CSV import for admin QA · mobile app reads bundled SQLite (OTA via Mobile Bundle tab).',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          TabBar(
            isScrollable: true,
            labelColor: theme.colorScheme.primary,
            tabs: const [
              Tab(
                icon: Icon(Icons.upload_file_rounded, size: 20),
                text: 'CSV Import',
              ),
              Tab(
                icon: Icon(Icons.storage_rounded, size: 20),
                text: 'Datasets',
              ),
              Tab(
                icon: Icon(Icons.phone_android_rounded, size: 20),
                text: 'Mobile Bundle',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CsvImportTab extends StatefulWidget {
  const _CsvImportTab();

  @override
  State<_CsvImportTab> createState() => _CsvImportTabState();
}

class _CsvImportTabState extends State<_CsvImportTab> {
  final _datasetId = TextEditingController(text: 'neet_ug_2025_round1_aiq');
  final _title = TextEditingController(text: 'NEET UG 2025 — Round 1 — AIQ');
  final _examYear = TextEditingController(text: '2025');
  final _round = TextEditingController(text: '1');
  final _counsellingType = TextEditingController(text: 'AIQ');
  final _pasteController = TextEditingController();

  String _fileName = '';
  SeatAllotmentCsvParseResult? _parsed;
  bool _importing = false;
  String? _importMessage;
  int _progressDone = 0;
  int _progressTotal = 0;

  @override
  void dispose() {
    _datasetId.dispose();
    _title.dispose();
    _examYear.dispose();
    _round.dispose();
    _counsellingType.dispose();
    _pasteController.dispose();
    super.dispose();
  }

  int _int(TextEditingController c, int fallback) =>
      int.tryParse(c.text.trim()) ?? fallback;

  void _applyParse(SeatAllotmentCsvParseResult result) {
    setState(() {
      _parsed = result;
      _importMessage = null;
    });
  }

  void _parseFromText(String raw) {
    _applyParse(parseSeatAllotmentCsv(raw));
  }

  Future<void> _pickCsvFile() async {
    final text = await pickCsvFileText();
    if (!mounted || text == null || text.trim().isEmpty) return;
    setState(() {
      _fileName = 'selected.csv';
      _pasteController.text = text;
    });
    _parseFromText(text);
  }

  Future<void> _runImport() async {
    final parsed = _parsed;
    if (parsed == null || !parsed.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Parse a valid CSV before importing.')),
      );
      return;
    }
    setState(() {
      _importing = true;
      _importMessage = null;
      _progressDone = 0;
      _progressTotal = parsed.rows.length;
    });
    try {
      final probeError = await SeatAllotmentWriteProbe.verify();
      if (probeError != null) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
          message: probeError,
        );
      }
      await SeatAllotmentImportService.importDataset(
        datasetId: _datasetId.text.trim(),
        title: _title.text.trim(),
        examYear: _int(_examYear, 2025),
        round: _int(_round, 1),
        counsellingType: _counsellingType.text.trim(),
        sourceFileName: _fileName.isNotEmpty ? _fileName : 'paste.csv',
        rows: parsed.rows,
        onProgress: (done, total) {
          if (!mounted) return;
          setState(() {
            _progressDone = done;
            _progressTotal = total;
          });
        },
      );
      if (!mounted) return;
      setState(() {
        _importing = false;
        _importMessage =
            'Imported ${parsed.rows.length} rows to dataset "${_datasetId.text.trim()}". '
            'Publish from the Datasets tab when ready.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_importMessage!)),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      final hint = msg.contains('permission-denied')
          ? ' Deploy Firestore rules: from neetprep_flutter run '
              '`firebase deploy --only firestore:rules`. '
              'Sign in as owner or an active admin/moderator.'
          : '';
      setState(() {
        _importing = false;
        _importMessage = 'Import failed: $e$hint';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_importMessage!),
          duration: const Duration(seconds: 8),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final parsed = _parsed;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Dataset metadata',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _datasetId,
                    decoration: const InputDecoration(
                      labelText: 'Dataset ID (Firestore document id)',
                      hintText: 'neet_ug_2025_round1_aiq',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _title,
                    decoration: const InputDecoration(
                      labelText: 'Display title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _examYear,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Exam year',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _round,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Round',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _counsellingType,
                          decoration: const InputDecoration(
                            labelText: 'Counselling type',
                            hintText: 'AIQ / State',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'CSV file',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Expected columns: SNo, Rank, Allotted Quota, Allotted Institute, '
                    'Course, Allotted Category, Candidate Category, Remarks. '
                    'UTF-8 CSV with quoted institute fields is supported.',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: _importing ? null : _pickCsvFile,
                        icon: const Icon(Icons.folder_open_rounded),
                        label: const Text('Choose CSV file'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _importing
                            ? null
                            : () => _parseFromText(_pasteController.text),
                        icon: const Icon(Icons.fact_check_outlined),
                        label: const Text('Validate pasted CSV'),
                      ),
                      FilledButton.icon(
                        onPressed: _importing || parsed == null || !parsed.ok
                            ? null
                            : _runImport,
                        icon: _importing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.cloud_upload_rounded),
                        label: Text(
                          _importing ? 'Importing…' : 'Import to Firestore',
                        ),
                      ),
                    ],
                  ),
                  if (_importing && _progressTotal > 0) ...[
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: _progressDone / _progressTotal,
                    ),
                    const SizedBox(height: 4),
                    Text('$_progressDone / $_progressTotal rows'),
                  ],
                  if (_importMessage != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _importMessage!,
                      style: TextStyle(
                        color: _importMessage!.startsWith('Import failed')
                            ? Colors.red.shade700
                            : Colors.green.shade800,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pasteController,
                    minLines: 6,
                    maxLines: 14,
                    decoration: const InputDecoration(
                      labelText: 'Or paste CSV text here',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    onChanged: (_) => setState(() => _parsed = null),
                  ),
                ],
              ),
            ),
          ),
          if (parsed != null) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      parsed.ok
                          ? 'Preview — ${parsed.rows.length} rows'
                          : 'Validation',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    if (parsed.headerLine.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Header: ${parsed.headerLine}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    if (parsed.errors.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ...parsed.errors.take(12).map(
                            (e) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                '• $e',
                                style: TextStyle(color: Colors.red.shade700),
                              ),
                            ),
                          ),
                      if (parsed.errors.length > 12)
                        Text('… and ${parsed.errors.length - 12} more'),
                    ],
                    if (parsed.rows.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'All 8 CSV columns are parsed and saved to Firestore. '
                        'Scroll horizontally to preview every column.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowHeight: 36,
                          dataRowMinHeight: 32,
                          dataRowMaxHeight: 56,
                          columns: const [
                            DataColumn(label: Text('SNo')),
                            DataColumn(label: Text('Rank')),
                            DataColumn(label: Text('Allotted Quota')),
                            DataColumn(label: Text('Allotted Institute')),
                            DataColumn(label: Text('Course')),
                            DataColumn(label: Text('Allotted Category')),
                            DataColumn(label: Text('Candidate Category')),
                            DataColumn(label: Text('Remarks')),
                          ],
                          rows: parsed.rows.take(25).map((row) {
                            return DataRow(
                              cells: [
                                DataCell(Text('${row.serialNo}')),
                                DataCell(Text('${row.rank}')),
                                DataCell(
                                  SizedBox(
                                    width: 120,
                                    child: Text(
                                      row.allottedQuota,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: 220,
                                    child: Text(
                                      row.instituteName,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                DataCell(Text(row.course)),
                                DataCell(Text(row.allottedCategory)),
                                DataCell(Text(row.candidateCategory)),
                                DataCell(Text(row.remarks)),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                      if (parsed.rows.length > 25)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Showing first 25 of ${parsed.rows.length} rows.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MobileBundleTab extends StatelessWidget {
  const _MobileBundleTab();

  static const _publishSteps = '''
From neetprep_flutter (after CSV preprocess + DB rebuild):

  cd E:\\New_TPK_2026\\Apps\\neetprep_flutter
  node tool/build_seat_allotment_db.mjs
  node tool/publish_seat_allotment_bundle.mjs

First time only (OTA rules):

  powershell -File tool/deploy_seat_allotment_rules.ps1

Requires tool/service-account.json (gitignored). Mobile app: MBBS Seats hub → Refresh.''';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirestoreDb.instance.doc('cms_seat_allotment/main').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            final err = '${snapshot.error}';
            final hint = err.contains('permission-denied')
                ? '\n\nDeploy rules from neetprep_flutter:\n'
                    'powershell -File tool/deploy_seat_allotment_rules.ps1'
                : '';
            return Center(
              child: Text('Error: $err$hint', textAlign: TextAlign.center),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final doc = snapshot.data!;
          if (!doc.exists) {
            return _MobileBundleEmptyState(theme: theme);
          }
          final data = doc.data() ?? {};
          final published = data['published'] == true;
          final fingerprint = data['fingerprint']?.toString() ?? '—';
          final generatedAt = data['generatedAt']?.toString() ?? '—';
          final version = data['bundleVersion'] ?? '—';
          final dbPath = data['dbStoragePath']?.toString() ?? '—';
          final manifestPath =
              data['manifestStoragePath']?.toString() ?? '—';
          final dbSize = data['dbSizeBytes'];
          String sizeLabel = '—';
          if (dbSize is num && dbSize > 0) {
            sizeLabel = '${(dbSize / (1024 * 1024)).toStringAsFixed(1)} MB';
          }
          final updatedAt = data['updatedAt'];
          String updatedLabel = '—';
          if (updatedAt is Timestamp) {
            updatedLabel = DateFormat.yMMMd().add_jm().format(
                  updatedAt.toDate(),
                );
          }

          return ListView(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            published
                                ? Icons.check_circle_rounded
                                : Icons.pause_circle_outline_rounded,
                            color: published
                                ? Colors.green.shade700
                                : theme.colorScheme.outline,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            published
                                ? 'OTA bundle published'
                                : 'Bundle not published',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _BundleInfoRow(label: 'Version', value: '$version'),
                      _BundleInfoRow(label: 'Fingerprint', value: fingerprint),
                      _BundleInfoRow(label: 'Generated', value: generatedAt),
                      _BundleInfoRow(label: 'DB size', value: sizeLabel),
                      _BundleInfoRow(label: 'Last write', value: updatedLabel),
                      const SizedBox(height: 8),
                      Text(
                        'Storage',
                        style: theme.textTheme.labelLarge,
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        dbPath,
                        style: theme.textTheme.bodySmall,
                      ),
                      SelectableText(
                        manifestPath,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                color: theme.colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'How mobile gets data',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'The app ships with a bundled SQLite database in the APK/IPA. '
                        'When you publish here, Production users can tap Refresh on the '
                        'MBBS Seats hub to download the newer bundle. '
                        'CSV Import / Datasets tabs are for admin QA only — not the mobile query path.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Publish from CLI',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        _publishSteps,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MobileBundleEmptyState extends StatelessWidget {
  const _MobileBundleEmptyState({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No OTA bundle yet',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Mobile users still get the SQLite database bundled in the app store build. '
                  'Run the publish script once to enable over-the-air updates.',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              _MobileBundleTab._publishSteps,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                height: 1.45,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BundleInfoRow extends StatelessWidget {
  const _BundleInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _DatasetsTab extends StatelessWidget {
  const _DatasetsTab();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirestoreDb.instance
            .collection('seat_allotment_datasets')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            final err = '${snapshot.error}';
            final hint = err.contains('permission-denied')
                ? '\n\nDeploy rules: firebase deploy --only firestore:rules '
                    '(from neetprep_flutter).'
                : '';
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Error: $err$hint', textAlign: TextAlign.center),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs.toList()
            ..sort((a, b) {
              final ta = a.data()['updatedAt'];
              final tb = b.data()['updatedAt'];
              if (ta is Timestamp && tb is Timestamp) {
                return tb.compareTo(ta);
              }
              return b.id.compareTo(a.id);
            });
          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'No datasets yet. Import a CSV in the CSV Import tab.',
              ),
            );
          }
          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final title = data['title']?.toString() ?? doc.id;
              final rowCount = data['rowCount'] ?? 0;
              final published = data['isPublished'] == true;
              final updatedAt = data['updatedAt'];
              String updatedLabel = '—';
              if (updatedAt is Timestamp) {
                updatedLabel = DateFormat.yMMMd().add_jm().format(
                      updatedAt.toDate(),
                    );
              }
              return Card(
                child: ListTile(
                  title: Text(title),
                  subtitle: Text(
                    'ID: ${doc.id}\n'
                    '$rowCount rows · ${data['counsellingType'] ?? ''} · '
                    'Updated $updatedLabel',
                  ),
                  isThreeLine: true,
                  trailing: Switch(
                    value: published,
                    onChanged: (v) async {
                      await SeatAllotmentImportService.setPublished(doc.id, v);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            v ? 'Published for mobile app.' : 'Unpublished.',
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
