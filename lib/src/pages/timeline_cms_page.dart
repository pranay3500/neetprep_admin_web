import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/firestore_db.dart';
import '../widgets/admin_dialog_save_actions.dart';

class TimelineCmsPage extends StatelessWidget {
  const TimelineCmsPage({super.key});

  CollectionReference<Map<String, dynamic>> get _col =>
      FirestoreDb.instance.collection('timeline');

  static final List<Map<String, dynamic>> _defaultEvents = [
    {
      'id': 'timeline_exam_registration',
      'title': 'NEET Registration Window',
      'date': 'Feb 09 - Mar 09, 2026',
      'status': 'Completed',
      'phase': 'Past',
      'order': 1,
      'startDate': DateTime.now().subtract(const Duration(days: 48)),
      'endDate': DateTime.now().subtract(const Duration(days: 20)),
      'description':
          'Application form, fee payment, and document upload should be completed before deadline.',
      'parentRequirements': [
        'Valid passport copy of student and sponsor',
        'Recent passport-size photo and signature scan',
        'NRI sponsorship declaration (if applicable)',
      ],
      'parentTodos': [
        'Create NTA account and verify email/phone',
        'Fill student details exactly as per passport',
        'Upload required documents and review preview',
        'Pay exam fee and save confirmation receipt',
      ],
      'isDone': true,
    },
    {
      'id': 'timeline_correction_window',
      'title': 'Application Correction Window',
      'date': 'Mar 10 - Mar 12, 2026',
      'status': 'Scheduled',
      'phase': 'Past',
      'order': 2,
      'startDate': DateTime.now().subtract(const Duration(days: 14)),
      'endDate': DateTime.now().subtract(const Duration(days: 12)),
      'description':
          'Limited correction period for eligible fields in the submitted NEET application.',
      'parentRequirements': [
        'Final school records for names and DOB match',
        'Correct category and identity details',
      ],
      'parentTodos': [
        'Review all submitted fields for mismatch',
        'Correct errors before window closes',
        'Download corrected application copy',
      ],
      'isDone': false,
    },
    {
      'id': 'timeline_admit_card',
      'title': 'Admit Card Release',
      'date': 'April 2026',
      'status': 'Upcoming',
      'phase': 'Upcoming',
      'order': 3,
      'startDate': DateTime.now().add(const Duration(days: 1)),
      'endDate': DateTime.now().add(const Duration(days: 2)),
      'description':
          'Download admit card early and verify exam center details to avoid last minute issues.',
      'parentRequirements': [
        'Application number and password',
        'Printer-ready PDF access',
      ],
      'parentTodos': [
        'Download admit card PDF',
        'Verify name, photo, and exam center details',
        'Print 2-3 copies for exam day',
      ],
      'isDone': false,
    },
    {
      'id': 'timeline_exam_day',
      'title': 'NEET Exam Day',
      'date': 'May 03, 2026',
      'status': 'Scheduled',
      'phase': 'Upcoming',
      'order': 4,
      'startDate': DateTime.now().add(const Duration(days: 6)),
      'endDate': DateTime.now().add(const Duration(days: 7)),
      'description':
          'Ensure travel, reporting time, and mandatory document checklist are fully planned.',
      'parentRequirements': [
        'Printed admit card',
        'Valid original photo ID',
        'Transparent water bottle and required stationery',
      ],
      'parentTodos': [
        'Visit exam center location one day before',
        'Pack all required documents the night before',
        'Reach center before reporting time',
      ],
      'isDone': false,
    },
    {
      'id': 'timeline_results',
      'title': 'NEET Result + Scorecard',
      'date': 'June 2026',
      'status': 'Upcoming',
      'phase': 'Upcoming',
      'order': 5,
      'startDate': DateTime.now().add(const Duration(days: 28)),
      'endDate': DateTime.now().add(const Duration(days: 35)),
      'description':
          'Results and scorecard release followed by rank analysis for counseling planning.',
      'parentRequirements': [
        'Application credentials for login',
        'List of preferred colleges and budget constraints',
      ],
      'parentTodos': [
        'Download scorecard and rank details',
        'Discuss seat strategy with counselor',
        'Prepare counseling documents file',
      ],
      'isDone': false,
    },
    {
      'id': 'timeline_counseling',
      'title': 'AIQ/State Counseling Rounds',
      'date': 'July - September 2026',
      'status': 'Planned',
      'phase': 'Upcoming',
      'order': 6,
      'startDate': DateTime.now().add(const Duration(days: 50)),
      'endDate': DateTime.now().add(const Duration(days: 65)),
      'description':
          'Choice filling, seat allotment, and reporting cycles across counseling rounds.',
      'parentRequirements': [
        'Document set attested and scanned',
        'Confirmed travel or remote reporting plan',
      ],
      'parentTodos': [
        'Complete registration for relevant counseling portals',
        'Fill and lock college choices carefully',
        'Track allotment results round-by-round',
        'Complete reporting and admission formalities on time',
      ],
      'isDone': false,
    },
  ];

  Future<void> _seedDefaults(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final batch = FirestoreDb.instance.batch();
      for (final event in _defaultEvents) {
        final id = event['id']!.toString();
        batch.set(
          _col.doc(id),
          _toFirestorePayload(event, seed: true),
          SetOptions(merge: true),
        );
      }
      await batch.commit();
      messenger.showSnackBar(
        const SnackBar(content: Text('Default timelines synced to Firestore.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not seed timelines: $e')),
      );
    }
  }

  Future<void> _openEditor(
    BuildContext context, {
    DocumentSnapshot<Map<String, dynamic>>? doc,
  }) async {
    final data = doc?.data() ?? <String, dynamic>{};
    final title = TextEditingController(text: data['title']?.toString() ?? '');
    final dateLabel = TextEditingController(
      text: data['date']?.toString() ?? data['eventDate']?.toString() ?? '',
    );
    final description = TextEditingController(
      text:
          data['description']?.toString() ?? data['subtitle']?.toString() ?? '',
    );
    final order = TextEditingController(
      text: ((data['order'] as num?)?.toInt() ?? 1).toString(),
    );
    final requirements = TextEditingController(
      text: _listText(data['parentRequirements'] ?? data['requirements']),
    );
    final todos = TextEditingController(
      text: _listText(
        data['parentTodos'] ?? data['todos'] ?? data['checklist'],
      ),
    );
    DateTime start = _asDate(data['startDate']) ?? DateTime.now();
    DateTime end =
        _asDate(data['endDate']) ?? DateTime.now().add(const Duration(days: 3));
    bool isDone =
        data['isDone'] == true ||
        (data['status']?.toString().toLowerCase() == 'completed');
    bool isPublished = data['isPublished'] != false;
    String status = _normalStatus(data['status']?.toString() ?? 'Upcoming');

    Future<void> pickStart(StateSetter setState) async {
      final picked = await showDatePicker(
        context: context,
        initialDate: start,
        firstDate: DateTime(2025),
        lastDate: DateTime(2035),
      );
      if (picked != null) {
        setState(() => start = picked);
      }
    }

    Future<void> pickEnd(StateSetter setState) async {
      final picked = await showDatePicker(
        context: context,
        initialDate: end,
        firstDate: DateTime(2025),
        lastDate: DateTime(2035),
      );
      if (picked != null) {
        setState(() => end = picked);
      }
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(
            doc == null ? 'Add Timeline Event' : 'Edit Timeline Event',
          ),
          content: SizedBox(
            width: 760,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: title,
                          decoration: const InputDecoration(
                            labelText: 'Timeline title',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 120,
                        child: TextField(
                          controller: order,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Order'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: dateLabel,
                    decoration: const InputDecoration(
                      labelText: 'Display date label',
                      helperText: 'Example: Feb 09 - Mar 09, 2026',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: description,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description shown in app',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => pickStart(setState),
                          icon: const Icon(Icons.play_circle_outline_rounded),
                          label: Text(
                            'Start: ${DateFormat('dd MMM yyyy').format(start)}',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => pickEnd(setState),
                          icon: const Icon(Icons.flag_outlined),
                          label: Text(
                            'End: ${DateFormat('dd MMM yyyy').format(end)}',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: const [
                      DropdownMenuItem(
                        value: 'Planned',
                        child: Text('Planned'),
                      ),
                      DropdownMenuItem(
                        value: 'Upcoming',
                        child: Text('Upcoming'),
                      ),
                      DropdownMenuItem(
                        value: 'Scheduled',
                        child: Text('Scheduled'),
                      ),
                      DropdownMenuItem(
                        value: 'Completed',
                        child: Text('Completed'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        status = value;
                        isDone = value == 'Completed';
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: requirements,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Parent requirements (one per line)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: todos,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Parent to-do checklist (one per line)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    value: isDone,
                    onChanged: (v) => setState(() {
                      isDone = v;
                      status = v ? 'Completed' : status;
                    }),
                    title: const Text('Mark completed'),
                  ),
                  SwitchListTile(
                    value: isPublished,
                    onChanged: (v) => setState(() => isPublished = v),
                    title: const Text('Publish in mobile app'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            AdminDialogSaveActions(
              dialogContext: ctx,
              savedMessage: 'Timeline event saved.',
              onSave: () async {
                final normalizedStatus = isDone ? 'Completed' : status;
                final payload = <String, dynamic>{
                  'title': title.text.trim(),
                  'date': dateLabel.text.trim(),
                  'eventDate': dateLabel.text.trim(),
                  'description': description.text.trim(),
                  'order': int.tryParse(order.text.trim()) ?? 1,
                  'startDate': Timestamp.fromDate(
                    DateTime(start.year, start.month, start.day),
                  ),
                  'endDate': Timestamp.fromDate(
                    DateTime(end.year, end.month, end.day, 23, 59, 59),
                  ),
                  'dueDate': Timestamp.fromDate(
                    DateTime(end.year, end.month, end.day, 23, 59, 59),
                  ),
                  'parentRequirements': _parseLines(requirements.text),
                  'parentTodos': _parseLines(todos.text),
                  'requirements': _parseLines(requirements.text),
                  'checklist': _parseLines(todos.text),
                  'phase': _phaseForStatus(normalizedStatus, isDone),
                  'isDone': isDone,
                  'isPublished': isPublished,
                  'status': normalizedStatus,
                  'updatedAt': FieldValue.serverTimestamp(),
                };
                if (doc == null) {
                  await _col.add({
                    ...payload,
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                } else {
                  await _col.doc(doc.id).set(payload, SetOptions(merge: true));
                }
                return true;
              },
            ),
          ],
        ),
      ),
    );
  }

  static Map<String, dynamic> _toFirestorePayload(
    Map<String, dynamic> event, {
    required bool seed,
  }) {
    final start = event['startDate'] as DateTime;
    final end = event['endDate'] as DateTime;
    final req = List<String>.from(event['parentRequirements'] as List);
    final todos = List<String>.from(event['parentTodos'] as List);
    return {
      'title': event['title'],
      'date': event['date'],
      'eventDate': event['date'],
      'status': event['status'],
      'phase': event['phase'],
      'order': event['order'],
      'startDate': Timestamp.fromDate(start),
      'endDate': Timestamp.fromDate(end),
      'dueDate': Timestamp.fromDate(end),
      'description': event['description'],
      'parentRequirements': req,
      'parentTodos': todos,
      'requirements': req,
      'checklist': todos,
      'isDone': event['isDone'],
      'isPublished': true,
      'updatedAt': FieldValue.serverTimestamp(),
      if (seed) 'seededFrom': 'guest_timeline_defaults',
      if (seed) 'createdAt': FieldValue.serverTimestamp(),
    };
  }

  static String _listText(dynamic raw) {
    if (raw is List) {
      return raw.map((e) => e.toString()).join('\n');
    }
    return '';
  }

  static List<String> _parseLines(String text) {
    return text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  DateTime? _asDate(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  static String _normalStatus(String raw) {
    final value = raw.trim().toLowerCase();
    if (value == 'completed') return 'Completed';
    if (value == 'scheduled') return 'Scheduled';
    if (value == 'planned') return 'Planned';
    return 'Upcoming';
  }

  static String _phaseForStatus(String status, bool isDone) {
    if (isDone || status.toLowerCase() == 'completed') return 'Past';
    return 'Upcoming';
  }

  String _dateRangeText(Map<String, dynamic> d) {
    final explicit = d['date']?.toString().trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final start = _asDate(d['startDate']);
    final end = _asDate(d['endDate']);
    if (start != null && end != null) {
      return '${DateFormat('dd MMM yyyy').format(start)} - ${DateFormat('dd MMM yyyy').format(end)}';
    }
    if (end != null) return DateFormat('dd MMM yyyy').format(end);
    if (start != null) return DateFormat('dd MMM yyyy').format(start);
    return 'Date not set';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Create, edit, publish, and order the NEET timeline cards shown in the mobile app.',
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _seedDefaults(context),
                icon: const Icon(Icons.auto_fix_high_outlined),
                label: const Text('Seed defaults'),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: () => _openEditor(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Timeline'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _col.orderBy('order').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Failed to load timelines: ${snapshot.error}'),
                  );
                }
                final docs = snapshot.data?.docs ?? const [];
                if (docs.isEmpty) {
                  return Center(
                    child: FilledButton.icon(
                      onPressed: () => _seedDefaults(context),
                      icon: const Icon(Icons.auto_fix_high_outlined),
                      label: const Text('Seed guest-mode timeline defaults'),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 8),
                  itemBuilder: (_, index) {
                    final doc = docs[index];
                    final d = doc.data();
                    final isPublished = d['isPublished'] != false;
                    return Card(
                      child: ListTile(
                        title: Text(d['title']?.toString() ?? 'Untitled'),
                        subtitle: Text(
                          '${_dateRangeText(d)}\n${d['description']?.toString() ?? ''}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        leading: CircleAvatar(
                          child: Text(
                            '${(d['order'] as num?)?.toInt() ?? index + 1}',
                          ),
                        ),
                        trailing: Wrap(
                          spacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Chip(
                              visualDensity: VisualDensity.compact,
                              label: Text(
                                d['status']?.toString() ?? 'Upcoming',
                              ),
                            ),
                            Icon(
                              isPublished
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_outlined,
                              color: isPublished ? Colors.green : Colors.grey,
                            ),
                            IconButton(
                              tooltip: 'Edit timeline',
                              onPressed: () => _openEditor(context, doc: doc),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              tooltip: 'Delete timeline',
                              onPressed: () => _col.doc(doc.id).delete(),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
