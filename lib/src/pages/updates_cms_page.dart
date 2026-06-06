import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/firestore_db.dart';
import '../utils/update_read_time.dart';
import '../widgets/admin_dialog_save_actions.dart';

class UpdatesCmsPage extends StatelessWidget {
  const UpdatesCmsPage({super.key});

  CollectionReference<Map<String, dynamic>> get _col =>
      FirestoreDb.instance.collection('updates');

  Future<void> _openEditor(
    BuildContext context, {
    DocumentSnapshot<Map<String, dynamic>>? doc,
  }) async {
    final data = doc?.data() ?? <String, dynamic>{};
    final publishConfig = data['publishConfig'] is Map
        ? data['publishConfig'] as Map
        : null;
    final notificationConfig = data['notificationConfig'] is Map
        ? data['notificationConfig'] as Map
        : null;

    final title = TextEditingController(text: data['title']?.toString() ?? '');
    final preview = TextEditingController(
      text:
          data['preview']?.toString() ??
          data['summary']?.toString() ??
          data['description']?.toString() ??
          '',
    );
    final content = TextEditingController(
      text: data['content']?.toString() ?? '',
    );
    final sourceUrl = TextEditingController(
      text:
          data['externalUrl']?.toString() ??
          data['sourceUrl']?.toString() ??
          '',
    );
    final tags = TextEditingController(text: _tagsText(data['tags']));
    final authorName = TextEditingController(
      text: data['authorName']?.toString() ?? '',
    );
    final pushTitle = TextEditingController(
      text: notificationConfig?['pushTitle']?.toString() ?? '',
    );
    final pushBody = TextEditingController(
      text: notificationConfig?['pushBody']?.toString() ?? '',
    );
    final emailSubject = TextEditingController(
      text: notificationConfig?['emailSubject']?.toString() ?? '',
    );

    var category = _categoryId(data['category']?.toString());
    var priority = _priorityLabel(data['priority']);
    var status =
        publishConfig?['status']?.toString().toLowerCase() ??
        (data['isPublished'] == false ? 'draft' : 'published');
    if (!_statusOptions.contains(status)) status = 'published';
    DateTime selectedDate =
        _asDate(data['date'] ?? data['publishedAt']) ?? DateTime.now();
    DateTime? deadlineDate = _asDate(data['deadlineDate']);
    DateTime? publishAt = _asDate(publishConfig?['publishAt']);
    DateTime? expiresAt = _asDate(publishConfig?['expiresAt']);
    bool isPinned =
        data['isPinned'] == true || publishConfig?['isPinned'] == true;
    bool isBreaking =
        data['isBreaking'] == true || publishConfig?['isBreaking'] == true;
    bool sendPush = notificationConfig?['sendPushNotification'] != false;
    bool sendEmail = notificationConfig?['sendEmail'] == true;
    bool sendRecurring = notificationConfig?['sendRecurring'] == true;
    var recurringInterval = notificationConfig?['recurringConfig'] is Map
        ? (notificationConfig!['recurringConfig'] as Map)['interval']
                  ?.toString() ??
              'every_2_days'
        : 'every_2_days';
    var recurringMaxCount = notificationConfig?['recurringConfig'] is Map
        ? ((notificationConfig!['recurringConfig'] as Map)['maxCount'] as num?)
                  ?.toInt() ??
              3
        : 3;
    var stopIfRead = notificationConfig?['recurringConfig'] is Map
        ? (notificationConfig!['recurringConfig'] as Map)['stopIfRead'] != false
        : true;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(doc == null ? 'Create NEET Pulse Update' : 'Edit Update'),
          content: SizedBox(
            width: 860,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionHeader(
                    title: 'Update Content',
                    subtitle: 'This feeds the NEET Pulse cards and full view.',
                  ),
                  TextField(
                    controller: title,
                    maxLength: 120,
                    decoration: const InputDecoration(
                      labelText: 'Update Title *',
                      helperText:
                          'Keep it clear and action-oriented for parents.',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: category,
                          items: _categoryOptions
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item.id,
                                  child: Text(item.label),
                                ),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setState(() => category = v ?? 'general'),
                          decoration: const InputDecoration(
                            labelText: 'Category *',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: priority,
                          items: _priorityOptions
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item,
                                  child: Text(item),
                                ),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setState(() => priority = v ?? 'INFO'),
                          decoration: const InputDecoration(
                            labelText: 'Priority *',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: preview,
                    maxLength: 200,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Custom Preview Text',
                      helperText:
                          'Shown on cards. If empty, the app can fall back to content.',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: content,
                    minLines: 7,
                    maxLines: 12,
                    decoration: const InputDecoration(
                      labelText: 'Content *',
                      alignLabelWithHint: true,
                      helperText:
                          'Supports simple Markdown-style headings, bullets, NOTE:, WARNING:, and ACTION: callouts.',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: sourceUrl,
                          decoration: const InputDecoration(
                            labelText: 'Official Source Link',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: tags,
                          decoration: const InputDecoration(
                            labelText: 'Tags',
                            helperText: 'Comma separated: neet-2027, nta',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: authorName,
                    decoration: const InputDecoration(labelText: 'Author Name'),
                  ),
                  const SizedBox(height: 18),
                  _SectionHeader(
                    title: 'Publish Settings',
                    subtitle:
                        'Scheduled and archived updates stay out of the mobile feed.',
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: status,
                          items: _statusOptions
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item,
                                  child: Text(_titleCase(item)),
                                ),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setState(() => status = v ?? 'published'),
                          decoration: const InputDecoration(
                            labelText: 'Status',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DateButton(
                          label: 'Card Date',
                          value: selectedDate,
                          onPick: () async {
                            final picked = await _pickDate(ctx, selectedDate);
                            if (picked != null) {
                              setState(() => selectedDate = picked);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _OptionalDateChip(
                        label: 'Deadline',
                        value: deadlineDate,
                        onPick: () async {
                          final picked = await _pickDate(
                            ctx,
                            deadlineDate ?? selectedDate,
                          );
                          setState(() => deadlineDate = picked);
                        },
                        onClear: () => setState(() => deadlineDate = null),
                      ),
                      _OptionalDateChip(
                        label: 'Publish At',
                        value: publishAt,
                        onPick: () async {
                          final picked = await _pickDate(
                            ctx,
                            publishAt ?? selectedDate,
                          );
                          setState(() => publishAt = picked);
                        },
                        onClear: () => setState(() => publishAt = null),
                      ),
                      _OptionalDateChip(
                        label: 'Expires At',
                        value: expiresAt,
                        onPick: () async {
                          final picked = await _pickDate(
                            ctx,
                            expiresAt ?? selectedDate,
                          );
                          setState(() => expiresAt = picked);
                        },
                        onClear: () => setState(() => expiresAt = null),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: isPinned,
                    onChanged: (v) => setState(() => isPinned = v),
                    title: const Text('Pin this update'),
                    subtitle: const Text(
                      'Appears in Pinned & Saved for all users.',
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: isBreaking,
                    onChanged: (v) => setState(() => isBreaking = v),
                    title: const Text('Mark as Breaking News'),
                    subtitle: const Text(
                      'Shows the breaking banner for 72 hours.',
                    ),
                  ),
                  const SizedBox(height: 18),
                  _SectionHeader(
                    title: 'Notifications',
                    subtitle:
                        'The app stores these settings now; backend delivery can consume them.',
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: sendPush,
                    onChanged: (v) => setState(() => sendPush = v),
                    title: const Text('Send push notification on publish'),
                  ),
                  TextField(
                    controller: pushTitle,
                    maxLength: 65,
                    decoration: const InputDecoration(
                      labelText: 'Custom Push Title',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: pushBody,
                    maxLength: 120,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Custom Push Body',
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: sendEmail,
                    onChanged: (v) => setState(() => sendEmail = v),
                    title: const Text('Send email to subscribed users'),
                  ),
                  TextField(
                    controller: emailSubject,
                    decoration: const InputDecoration(
                      labelText: 'Custom Email Subject',
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: sendRecurring,
                    onChanged: (v) => setState(() => sendRecurring = v),
                    title: const Text('Send recurring reminder notifications'),
                  ),
                  if (sendRecurring) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: recurringInterval,
                            items: const [
                              DropdownMenuItem(
                                value: 'daily',
                                child: Text('Every day'),
                              ),
                              DropdownMenuItem(
                                value: 'every_2_days',
                                child: Text('Every 2 days'),
                              ),
                              DropdownMenuItem(
                                value: 'weekly',
                                child: Text('Weekly'),
                              ),
                            ],
                            onChanged: (v) => setState(
                              () => recurringInterval = v ?? 'every_2_days',
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Reminder Frequency',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: recurringMaxCount.clamp(1, 10),
                            items: List.generate(10, (index) => index + 1)
                                .map(
                                  (count) => DropdownMenuItem(
                                    value: count,
                                    child: Text('$count reminders'),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setState(() => recurringMaxCount = v ?? 3),
                            decoration: const InputDecoration(
                              labelText: 'Max Reminders',
                            ),
                          ),
                        ),
                      ],
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: stopIfRead,
                      onChanged: (v) => setState(() => stopIfRead = v),
                      title: const Text('Stop reminders once user reads'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            AdminDialogSaveActions(
              dialogContext: ctx,
              saveLabel: 'Save',
              savedMessage: 'Update saved.',
              onSave: () async {
                final payload = _payload(
                  title: title.text,
                  preview: preview.text,
                  content: content.text,
                  category: category,
                  priority: priority,
                  sourceUrl: sourceUrl.text,
                  tags: tags.text,
                  authorName: authorName.text,
                  selectedDate: selectedDate,
                  deadlineDate: deadlineDate,
                  status: status,
                  publishAt: publishAt,
                  expiresAt: expiresAt,
                  isPinned: isPinned,
                  isBreaking: isBreaking,
                  sendPush: sendPush,
                  sendEmail: sendEmail,
                  emailSubject: emailSubject.text,
                  pushTitle: pushTitle.text,
                  pushBody: pushBody.text,
                  sendRecurring: sendRecurring,
                  recurringInterval: recurringInterval,
                  recurringMaxCount: recurringMaxCount,
                  stopIfRead: stopIfRead,
                );
                if ((payload['title'] as String).isEmpty ||
                    (payload['content'] as String).isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('Title and content are required.'),
                    ),
                  );
                  return false;
                }
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

  Map<String, dynamic> _payload({
    required String title,
    required String preview,
    required String content,
    required String category,
    required String priority,
    required String sourceUrl,
    required String tags,
    required String authorName,
    required DateTime selectedDate,
    required DateTime? deadlineDate,
    required String status,
    required DateTime? publishAt,
    required DateTime? expiresAt,
    required bool isPinned,
    required bool isBreaking,
    required bool sendPush,
    required bool sendEmail,
    required String emailSubject,
    required String pushTitle,
    required String pushBody,
    required bool sendRecurring,
    required String recurringInterval,
    required int recurringMaxCount,
    required bool stopIfRead,
  }) {
    final cleanTitle = title.trim();
    final cleanContent = content.trim();
    final cleanPreview = preview.trim().isNotEmpty
        ? preview.trim()
        : _autoPreview(cleanContent);
    final cleanSource = sourceUrl.trim();
    final isPublished = status == 'published';
    final effectivePriority =
        !isBreaking && priority == 'BREAKING' ? 'URGENT' : priority;
    final readTime = UpdateReadTime.estimate(
      title: cleanTitle,
      preview: cleanPreview,
      content: cleanContent,
      priorityLabel: effectivePriority,
      isBreaking: isBreaking,
    );
    final date = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );

    return {
      'title': cleanTitle,
      'category': category,
      'priority': effectivePriority,
      'priorityRank': _priorityRank(effectivePriority),
      'preview': cleanPreview,
      'summary': cleanPreview,
      'description': cleanPreview,
      'content': cleanContent,
      'sourceUrl': cleanSource,
      'externalUrl': cleanSource,
      'tags': _splitTags(tags),
      'authorName': authorName.trim(),
      'readTime': readTime,
      'date': Timestamp.fromDate(date),
      'publishedAt': isPublished
          ? Timestamp.fromDate(publishAt ?? DateTime.now())
          : null,
      'deadlineDate': deadlineDate == null
          ? null
          : Timestamp.fromDate(deadlineDate),
      'isPublished': isPublished,
      'isPinned': isPinned,
      'isBreaking': isBreaking,
      'isActive': status != 'archived',
      'publishConfig': {
        'status': status,
        'publishAt': publishAt == null ? null : Timestamp.fromDate(publishAt),
        'expiresAt': expiresAt == null ? null : Timestamp.fromDate(expiresAt),
        'isPinned': isPinned,
        'isBreaking': isBreaking,
      },
      'notificationConfig': {
        'sendPushNotification': sendPush,
        'sendEmail': sendEmail,
        'emailSubject': emailSubject.trim(),
        'pushTitle': pushTitle.trim(),
        'pushBody': pushBody.trim(),
        'sendRecurring': sendRecurring,
        'recurringConfig': {
          'interval': recurringInterval,
          'maxCount': recurringMaxCount.clamp(1, 10),
          'stopIfRead': stopIfRead,
        },
      },
      'reactionCounts': {'helpful': 0, 'noted': 0, 'important': 0},
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  DateTime? _asDate(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  Future<DateTime?> _pickDate(BuildContext context, DateTime initial) {
    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2025),
      lastDate: DateTime(2035),
    );
  }

  static String _autoPreview(String content) {
    final normalized = content.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= 120) return normalized;
    return '${normalized.substring(0, 120)}...';
  }

  static List<String> _splitTags(String raw) {
    return raw
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();
  }

  static String _tagsText(dynamic raw) {
    if (raw is List) return raw.map((e) => e.toString()).join(', ');
    return '';
  }

  static int _priorityRank(String label) {
    switch (label) {
      case 'BREAKING':
        return 5;
      case 'URGENT':
        return 4;
      case 'IMPORTANT':
        return 3;
      case 'REMINDER':
        return 1;
      case 'INFO':
      default:
        return 2;
    }
  }

  static String _priorityLabel(dynamic raw) {
    if (raw is String && raw.trim().isNotEmpty) {
      final normalized = raw.trim().toUpperCase().replaceAll(' ', '_');
      return _priorityOptions.contains(normalized) ? normalized : 'INFO';
    }
    if (raw is num) {
      if (raw >= 5) return 'BREAKING';
      if (raw >= 4) return 'URGENT';
      if (raw >= 3) return 'IMPORTANT';
      if (raw >= 1) return 'REMINDER';
    }
    return 'INFO';
  }

  static String _categoryId(String? raw) {
    final normalized = (raw ?? 'general')
        .trim()
        .toLowerCase()
        .replaceAll('&', 'and')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return _categoryOptions.any((item) => item.id == normalized)
        ? normalized
        : 'general';
  }

  static String _titleCase(String raw) {
    if (raw.isEmpty) return raw;
    return raw[0].toUpperCase() + raw.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NEET Pulse Updates',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Create briefings, deadlines, breaking banners, and email-alert metadata for the mobile app.',
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () => _openEditor(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Update'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _col.orderBy('date', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Failed to load updates: ${snapshot.error}'),
                  );
                }
                final docs = snapshot.data?.docs ?? const [];
                if (docs.isEmpty) {
                  return const Center(child: Text('No updates configured.'));
                }
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: 1120,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(10),
                        itemCount: docs.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, index) {
                          final doc = docs[index];
                          final d = doc.data();
                          final date = _asDate(d['date']);
                          final category = _categoryId(
                            d['category']?.toString(),
                          );
                          final categoryLabel = _categoryOptions
                              .firstWhere((item) => item.id == category)
                              .label;
                          final priority = _priorityLabel(d['priority']);
                          final publishConfig = d['publishConfig'] is Map
                              ? d['publishConfig'] as Map
                              : null;
                          final status =
                              publishConfig?['status']?.toString() ??
                              (d['isPublished'] == false
                                  ? 'draft'
                                  : 'published');
                          return ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              backgroundColor: _priorityColor(priority),
                              child: Text(
                                '$index',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text(
                              d['title']?.toString() ?? 'Untitled',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                _Chip(label: categoryLabel),
                                _Chip(label: priority),
                                _Chip(label: _titleCase(status)),
                                if (d['isPinned'] == true)
                                  const _Chip(label: 'Pinned'),
                                if (d['isBreaking'] == true)
                                  const _Chip(label: 'Breaking'),
                                Text(
                                  date == null
                                      ? '-'
                                      : DateFormat('dd MMM yyyy').format(date),
                                ),
                              ],
                            ),
                            trailing: SizedBox(
                              width: 128,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Icon(
                                    d['isPublished'] == false
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_rounded,
                                    color: d['isPublished'] == false
                                        ? Colors.grey
                                        : Colors.green,
                                  ),
                                  IconButton(
                                    tooltip: 'Edit',
                                    onPressed: () =>
                                        _openEditor(context, doc: doc),
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                  IconButton(
                                    tooltip: 'Delete',
                                    onPressed: () => _col.doc(doc.id).delete(),
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.label,
    required this.value,
    required this.onPick,
  });

  final String label;
  final DateTime value;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPick,
      icon: const Icon(Icons.event_rounded),
      label: Text('$label: ${DateFormat('dd MMM yyyy').format(value)}'),
    );
  }
}

class _OptionalDateChip extends StatelessWidget {
  const _OptionalDateChip({
    required this.label,
    required this.value,
    required this.onPick,
    required this.onClear,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      avatar: const Icon(Icons.event_available_rounded, size: 18),
      label: Text(
        value == null
            ? '$label: not set'
            : '$label: ${DateFormat('dd MMM yyyy').format(value!)}',
      ),
      onPressed: onPick,
      onDeleted: value == null ? null : onClear,
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11)),
    );
  }
}

class _CategoryOption {
  const _CategoryOption(this.id, this.label);

  final String id;
  final String label;
}

const _categoryOptions = [
  _CategoryOption('registration', 'Registration'),
  _CategoryOption('exam_dates', 'Exam Dates'),
  _CategoryOption('admit_card', 'Admit Card'),
  _CategoryOption('results', 'Results'),
  _CategoryOption('test_centers', 'Test Centers'),
  _CategoryOption('syllabus', 'Syllabus'),
  _CategoryOption('counseling', 'Counseling'),
  _CategoryOption('nta_notice', 'NTA Notice'),
  _CategoryOption('fee_structure', 'Fee Update'),
  _CategoryOption('general', 'General'),
];

const _priorityOptions = [
  'BREAKING',
  'URGENT',
  'IMPORTANT',
  'INFO',
  'REMINDER',
];

const _statusOptions = ['draft', 'scheduled', 'published', 'archived'];

Color _priorityColor(String priority) {
  switch (priority) {
    case 'BREAKING':
    case 'URGENT':
      return Colors.red;
    case 'IMPORTANT':
      return Colors.orange;
    case 'REMINDER':
      return Colors.green;
    case 'INFO':
    default:
      return Colors.blue;
  }
}
