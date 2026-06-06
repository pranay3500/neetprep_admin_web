import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/admin_email/admin_email_dispatcher.dart';
import '../services/firestore_db.dart';
import '../widgets/admin_dialog_save_actions.dart';

class AnalysisSessionsPage extends StatelessWidget {
  const AnalysisSessionsPage({super.key});

  CollectionReference<Map<String, dynamic>> get _requests =>
      FirestoreDb.instance.collection('analysis_session_requests');

  DateTime? _dateFrom(dynamic raw) {
    if (raw is Timestamp) return raw.toDate().toLocal();
    if (raw is DateTime) return raw.toLocal();
    if (raw is String) return DateTime.tryParse(raw)?.toLocal();
    return null;
  }

  DateTime? _startFrom(Map<String, dynamic> data) {
    return _dateFrom(data['requestedStartAt']) ??
        _dateFrom(data['sessionDate']);
  }

  DateTime? _endFrom(Map<String, dynamic> data) {
    return _dateFrom(data['requestedEndAt']) ?? _dateFrom(data['sessionEndAt']);
  }

  List<String> _subjectsFrom(Map<String, dynamic> data) {
    final raw = data['subjects'];
    if (raw is List) {
      return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }
    return const <String>[];
  }

  String _slotLabel(DateTime start, DateTime end) {
    return '${DateFormat('hh:mm a').format(start)} - ${DateFormat('hh:mm a').format(end)}';
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return const Color(0xFFE8F5E9);
      case 'cancelled':
        return const Color(0xFFFFEBEE);
      case 'completed':
        return const Color(0xFFE3F2FD);
      case 'rescheduled':
        return const Color(0xFFFFF8E1);
      default:
        return const Color(0xFFFFF3E0);
    }
  }

  Future<void> _notifyUser({
    required String uid,
    required String title,
    required String description,
    required String longContent,
    required String color,
  }) async {
    await FirestoreDb.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .add({
          'title': title,
          'description': description,
          'longContent': longContent,
          'type': 'analysis_session',
          'isRead': false,
          'icon': 'support_agent',
          'color': color,
          'timestamp': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        });
  }

  Future<void> _writeSessionUpdate({
    required BuildContext context,
    required QueryDocumentSnapshot<Map<String, dynamic>> doc,
    required String nextStatus,
    DateTime? startAt,
    DateTime? endAt,
    List<String>? subjects,
    String? adminNotes,
    int? expectedScoreMin,
    int? expectedScoreMax,
    required String notificationTitle,
    required String notificationDescription,
    required String notificationLongContent,
    required String notificationColor,
  }) async {
    final data = doc.data();
    final uid = data['userId']?.toString() ?? '';
    final recipients = await AdminEmailDispatcher.recipientsFromData(data);
    final userEmail = recipients.isEmpty ? null : recipients.first.email;
    final resolvedStart = startAt ?? _startFrom(data);
    final resolvedEnd = endAt ?? _endFrom(data);
    final resolvedSubjects = subjects ?? _subjectsFrom(data);
    final timeSlot = resolvedStart != null && resolvedEnd != null
        ? _slotLabel(resolvedStart, resolvedEnd)
        : data['timeSlot']?.toString() ?? '';

    final requestUpdate = <String, dynamic>{
      'status': nextStatus,
      'subjects': resolvedSubjects,
      'timeSlot': timeSlot,
      'adminNotes': adminNotes?.trim() ?? data['adminNotes'] ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
      'adminUpdatedAt': FieldValue.serverTimestamp(),
      if (userEmail != null) 'email': userEmail,
    };
    if (resolvedStart != null) {
      requestUpdate['sessionDate'] = resolvedStart.toIso8601String();
      requestUpdate['requestedStartAt'] = Timestamp.fromDate(
        resolvedStart.toUtc(),
      );
    }
    if (resolvedEnd != null) {
      requestUpdate['sessionEndAt'] = resolvedEnd.toIso8601String();
      requestUpdate['requestedEndAt'] = Timestamp.fromDate(resolvedEnd.toUtc());
    }
    if (expectedScoreMin != null) {
      requestUpdate['expectedScoreMin'] = expectedScoreMin;
    }
    if (expectedScoreMax != null) {
      requestUpdate['expectedScoreMax'] = expectedScoreMax;
    }

    await _requests.doc(doc.id).set(requestUpdate, SetOptions(merge: true));

    if (uid.isEmpty) return;
    final sessionForUser = <String, dynamic>{
      ...data,
      ...requestUpdate,
      'requestId': doc.id,
      'adminUpdatedAt': DateTime.now().toIso8601String(),
    }..remove('updatedAt');

    final userUpdate = <String, dynamic>{'analysisSession': sessionForUser};
    if (expectedScoreMin != null) {
      userUpdate['expectedScoreMin'] = expectedScoreMin;
    }
    if (expectedScoreMax != null) {
      userUpdate['expectedScoreMax'] = expectedScoreMax;
    }
    await FirestoreDb.instance
        .collection('users')
        .doc(uid)
        .set(userUpdate, SetOptions(merge: true));
    await _notifyUser(
      uid: uid,
      title: notificationTitle,
      description: notificationDescription,
      longContent: notificationLongContent,
      color: notificationColor,
    );

    final mergedRequest = <String, dynamic>{
      ...data,
      ...requestUpdate,
      if (userEmail != null) 'email': userEmail,
    };
    await AdminEmailDispatcher.instance.dispatch(
      triggerKey: 'analysisSessionStatusChanged',
      sourcePath: 'analysis_session_requests/${doc.id}',
      payload: AdminEmailDispatcher.payloadFromAnalysis(mergedRequest, doc.id),
      userRecipients: recipients,
      sendAdmin: true,
    );
    if (context.mounted && userEmail == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Session updated. User has no email on file — in-app notification only.',
          ),
        ),
      );
    }
  }

  Future<void> _confirmSession(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    await _writeSessionUpdate(
      context: context,
      doc: doc,
      nextStatus: 'confirmed',
      notificationTitle: 'Analysis session confirmed',
      notificationDescription:
          'Your Expected NEET Score analysis session has been confirmed.',
      notificationLongContent:
          'Your analysis session request has been approved by the TestprepKart academics team. Please check the Expected NEET Score page for the confirmed session details.',
      notificationColor: '#2E7D32',
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Session confirmed. In-app notification sent; see email status above if shown.',
          ),
        ),
      );
    }
  }

  Future<void> _openRescheduleDialog(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    final now = DateTime.now();
    DateTime selectedDate =
        _startFrom(data) ?? now.add(const Duration(days: 1));
    int hour = selectedDate.hour;
    int minute = selectedDate.minute;
    int duration = ((_endFrom(data)?.difference(selectedDate).inMinutes ?? 60))
        .clamp(30, 180);
    final selectedSubjects = _subjectsFrom(data).toSet();
    const subjectOptions = ['Physics', 'Chemistry', 'Biology'];

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('Reschedule Analysis Session'),
            content: SizedBox(
              width: 540,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: selectedDate,
                          firstDate: now.subtract(const Duration(days: 1)),
                          lastDate: now.add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setDialogState(() {
                            selectedDate = DateTime(
                              picked.year,
                              picked.month,
                              picked.day,
                              hour,
                              minute,
                            );
                          });
                        }
                      },
                      icon: const Icon(Icons.calendar_today_rounded),
                      label: Text(
                        DateFormat('dd MMM yyyy').format(selectedDate),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: hour,
                            decoration: const InputDecoration(
                              labelText: 'Hour',
                              border: OutlineInputBorder(),
                            ),
                            items: List.generate(24, (i) => i)
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(e.toString().padLeft(2, '0')),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setDialogState(() {
                              hour = v ?? hour;
                            }),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: minute,
                            decoration: const InputDecoration(
                              labelText: 'Minute',
                              border: OutlineInputBorder(),
                            ),
                            items: const [0, 15, 30, 45]
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(e.toString().padLeft(2, '0')),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setDialogState(() {
                              minute = v ?? minute;
                            }),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: duration,
                      decoration: const InputDecoration(
                        labelText: 'Duration',
                        border: OutlineInputBorder(),
                      ),
                      items: const [30, 45, 60, 90, 120, 180]
                          .map(
                            (e) => DropdownMenuItem(
                              value: e,
                              child: Text('$e minutes'),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setDialogState(() {
                        duration = v ?? duration;
                      }),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Subject(s)',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: subjectOptions.map((subject) {
                        return FilterChip(
                          label: Text(subject),
                          selected: selectedSubjects.contains(subject),
                          onSelected: (selected) => setDialogState(() {
                            if (selected) {
                              selectedSubjects.add(subject);
                            } else {
                              selectedSubjects.remove(subject);
                            }
                          }),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              AdminDialogSaveActions(
                dialogContext: ctx,
                saveLabel: 'Save',
                savedMessage: 'Reschedule saved.',
                onSave: () async {
                  if (selectedSubjects.isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text('Select at least one subject.'),
                      ),
                    );
                    return false;
                  }
                  final startAt = DateTime(
                    selectedDate.year,
                    selectedDate.month,
                    selectedDate.day,
                    hour,
                    minute,
                  );
                  final endAt = startAt.add(Duration(minutes: duration));
                  await _writeSessionUpdate(
                    context: ctx,
                    doc: doc,
                    nextStatus: 'rescheduled',
                    startAt: startAt,
                    endAt: endAt,
                    subjects: selectedSubjects.toList(),
                    notificationTitle: 'Analysis session rescheduled',
                    notificationDescription:
                        'Your Expected NEET Score analysis session has been rescheduled.',
                    notificationLongContent:
                        'Your analysis session date, time, or subjects were updated by the TestprepKart academics team. Please check the Expected NEET Score page for the latest details.',
                    notificationColor: '#EF6C00',
                  );
                  return true;
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openCancelDialog(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final notes = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Analysis Session'),
        content: TextField(
          controller: notes,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Cancellation note',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () async {
              await _writeSessionUpdate(
                context: ctx,
                doc: doc,
                nextStatus: 'cancelled',
                adminNotes: notes.text,
                notificationTitle: 'Analysis session cancelled',
                notificationDescription:
                    'Your Expected NEET Score analysis session has been cancelled.',
                notificationLongContent: notes.text.trim().isEmpty
                    ? 'Your analysis session was cancelled by the TestprepKart academics team. Please check the Expected NEET Score page for the latest status.'
                    : notes.text.trim(),
                notificationColor: '#C62828',
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Cancel Session'),
          ),
        ],
      ),
    );
  }

  Future<void> _openSessionReportDialog(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    final notes = TextEditingController(
      text: data['adminNotes']?.toString() ?? '',
    );
    final minScore = TextEditingController(
      text: data['expectedScoreMin']?.toString() ?? '',
    );
    final maxScore = TextEditingController(
      text: data['expectedScoreMax']?.toString() ?? '',
    );
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Session Report'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: minScore,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Expected min score',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: maxScore,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Expected max score',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notes,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Report notes',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          AdminDialogSaveActions(
            dialogContext: ctx,
            saveLabel: 'Save',
            savedMessage: 'Report saved.',
            onSave: () async {
              final parsedMin = int.tryParse(minScore.text.trim());
              final parsedMax = int.tryParse(maxScore.text.trim());
              if (parsedMin == null || parsedMax == null) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Enter valid min and max scores.'),
                  ),
                );
                return false;
              }
              await _writeSessionUpdate(
                context: ctx,
                doc: doc,
                nextStatus: 'completed',
                adminNotes: notes.text,
                expectedScoreMin: parsedMin,
                expectedScoreMax: parsedMax,
                notificationTitle: 'Analysis session report ready',
                notificationDescription:
                    'Your Expected NEET Score analysis report has been updated.',
                notificationLongContent:
                    'Your expected score range and analysis notes are now available in the Expected NEET Score page.',
                notificationColor: '#1565C0',
              );
              return true;
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _requests.orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data?.docs ?? const [];
          if (docs.isEmpty) {
            return const Center(child: Text('No analysis requests found.'));
          }
          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (_, index) {
              final doc = docs[index];
              final d = doc.data();
              final status = d['status']?.toString() ?? 'pending_confirmation';
              final student = d['studentName']?.toString() ?? 'Unknown';
              final grade = d['currentGrade']?.toString() ?? '-';
              final subjects = _subjectsFrom(d).join(', ');
              final start = _startFrom(d);
              final end = _endFrom(d);
              final time = start == null
                  ? '-'
                  : '${DateFormat('dd MMM yyyy, hh:mm a').format(start)}${end == null ? '' : ' - ${DateFormat('hh:mm a').format(end)}'}';

              final needsReview =
                  status.toLowerCase() == 'pending_confirmation';

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (needsReview) ...[
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: const BoxDecoration(
                                color: Color(0xFFE53935),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                          Expanded(
                            child: Text(
                              student,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _statusColor(status),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(status),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Grade: $grade'),
                      Text('Subjects: ${subjects.isEmpty ? '-' : subjects}'),
                      Text('Time: $time'),
                      if ((d['adminNotes']?.toString() ?? '').isNotEmpty)
                        Text('Admin notes: ${d['adminNotes']}'),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _confirmSession(context, doc),
                            icon: const Icon(Icons.verified_rounded),
                            label: const Text('Confirm'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () =>
                                _openRescheduleDialog(context, doc),
                            icon: const Icon(Icons.event_repeat_rounded),
                            label: const Text('Reschedule'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () =>
                                _openSessionReportDialog(context, doc),
                            icon: const Icon(Icons.assessment_rounded),
                            label: const Text('Session Report'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _openCancelDialog(context, doc),
                            icon: const Icon(Icons.cancel_outlined),
                            label: const Text('Cancel'),
                          ),
                        ],
                      ),
                    ],
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
