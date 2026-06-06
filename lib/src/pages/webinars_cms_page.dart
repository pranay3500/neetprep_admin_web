import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/firestore_db.dart';
import '../utils/webinar_schedule_timezone.dart';
import '../widgets/admin_dialog_save_actions.dart';

/// Stable doc id for the default featured webinar (matches mobile preview content).
const String kDefaultWebinarDocId = 'default_featured_webinar';

class WebinarsCmsPage extends StatelessWidget {
  const WebinarsCmsPage({super.key});

  CollectionReference<Map<String, dynamic>> get _col =>
      FirestoreDb.instance.collection('webinars');

  Future<void> _seedDefaultWebinar(BuildContext context) async {
    try {
      final existing = await _col.doc(kDefaultWebinarDocId).get();
      final payload = _defaultWebinarPayload();
      await _col.doc(kDefaultWebinarDocId).set(
        {
          ...payload,
          'updatedAt': FieldValue.serverTimestamp(),
          if (!existing.exists) 'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Default webinar saved to Firestore (collection: webinars). '
            'Pull to refresh on the app to see the same data.',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not publish default webinar: $e')),
      );
    }
  }

  Future<void> _refreshFromServer(BuildContext context) async {
    try {
      final snap = await _col.get(const GetOptions(source: Source.server));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            snap.docs.isEmpty
                ? 'No documents in webinars on server.'
                : 'Loaded ${snap.docs.length} webinar(s) from server.',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Server refresh failed: $e')),
      );
    }
  }

  Future<void> _setPublished(
    BuildContext context, {
    required String docId,
    required bool published,
  }) async {
    try {
      await _col.doc(docId).set(
        {
          'isPublished': published,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            published
                ? 'Webinar enabled — visible in the mobile app.'
                : 'Webinar disabled — hidden from the mobile app.',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update webinar: $e')),
      );
    }
  }

  Future<void> _confirmDisableWebinar(
    BuildContext context, {
    required String docId,
    required String title,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disable webinar?'),
        content: Text(
          'Hide “$title” from the mobile app? '
          'You can re-enable it later from this list.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Disable'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await _setPublished(context, docId: docId, published: false);
  }

  Future<void> _confirmDeleteWebinar(
    BuildContext context, {
    required String docId,
    required String title,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete webinar?'),
        content: Text(
          'Permanently delete “$title”? This cannot be undone. '
          'The mobile app will stop showing this webinar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await _col.doc(docId).delete();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Webinar deleted.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete webinar: $e')),
      );
    }
  }

  Future<void> _openEditor(
    BuildContext context, {
    String? docId,
  }) async {
    /// After first save on a new webinar, further saves must update this doc (not add again).
    String? saveDocId = docId;
    Map<String, dynamic> data = {};
    if (docId != null) {
      final snap = await _col.doc(docId).get();
      if (!context.mounted) return;
      if (!snap.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Webinar document not found.')),
        );
        return;
      }
      data = Map<String, dynamic>.from(snap.data() ?? {});
    }
    final title = TextEditingController(text: _text(data['title'], ''));
    final subtitle = TextEditingController(text: _text(data['subtitle'], ''));
    final hostLabel =
        TextEditingController(text: _text(data['hostLabel'], 'TestprepKart NEET Team'));
    final highlights = TextEditingController(
      text: _linesText(data['topicHighlights']),
    );
    final descriptionHtml =
        TextEditingController(text: _text(data['descriptionHtml'], ''));
    var scheduledUtc =
        WebinarScheduleTimezone.utcFromFirestore(data['scheduledAt']) ??
            WebinarScheduleTimezone.nextSunday8pmIstUtc();
    final timezoneDisplay = TextEditingController(
      text: _text(data['timezoneDisplay'], '').isNotEmpty
          ? _text(data['timezoneDisplay'], '')
          : WebinarScheduleTimezone.usTimezoneDisplay(scheduledUtc),
    );
    final joinUrl = TextEditingController(text: _text(data['joinUrl'], ''));
    final youtubeUrl = TextEditingController(
      text: _text(data['youtubePromoId'] ?? data['youtubeUrl'], ''),
    );
    final thumbnailUrl = TextEditingController(
      text: _text(data['thumbnailImageUrl'] ?? data['heroImageUrl'], ''),
    );
    final heroImageUrl = TextEditingController(text: _text(data['heroImageUrl'], ''));
    final sessionRecordingTitle = TextEditingController(
      text: _text(data['sessionRecordingTitle'], 'Webinar Recording'),
    );
    final sessionRecordingUrl =
        TextEditingController(text: _text(data['sessionRecordingUrl'], ''));
    final sessionRecordingThumb = TextEditingController(
      text: _text(data['sessionRecordingThumbnailUrl'], ''),
    );
    final recordings = TextEditingController(text: _recordingsText(data['pastRecordings']));
    final assets = TextEditingController(text: _assetsText(data['assetItems']));

    var durationMinutes = _int(data['durationMinutes'], 75);
    var status = _normalizeStatus(data['status']);
    var isPublished = data['isPublished'] != false;
    var liveQa = data['features'] is Map ? (data['features'] as Map)['liveQa'] != false : true;
    var sharedAssets =
        data['features'] is Map ? (data['features'] as Map)['sharedAssets'] != false : true;
    var recordingEnabled = data['features'] is Map
        ? (data['features'] as Map)['recordingEnabled'] != false
        : true;
    var usTimezone = data['features'] is Map
        ? (data['features'] as Map)['usTimezoneFriendly'] != false
        : true;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(saveDocId == null ? 'Add Webinar' : 'Edit Webinar'),
          content: SizedBox(
            width: 720,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: title,
                    decoration: const InputDecoration(labelText: 'Title'),
                  ),
                  TextField(
                    controller: subtitle,
                    decoration: const InputDecoration(labelText: 'Subtitle'),
                  ),
                  TextField(
                    controller: hostLabel,
                    decoration: const InputDecoration(labelText: 'Host label'),
                  ),
                  TextField(
                    controller: thumbnailUrl,
                    decoration: const InputDecoration(
                      labelText: 'Home card thumbnail URL',
                      hintText: 'https://… image shown on mobile dashboard',
                    ),
                  ),
                  TextField(
                    controller: heroImageUrl,
                    decoration: const InputDecoration(
                      labelText: 'Detail page hero image URL (optional)',
                      hintText: 'Falls back to thumbnail if empty',
                    ),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Event date & time (IST)'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(WebinarScheduleTimezone.formatIstLong(scheduledUtc)),
                        const SizedBox(height: 4),
                        Text(
                          'US: ${WebinarScheduleTimezone.usTimezoneDisplay(scheduledUtc)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF5E35B1),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    trailing: TextButton(
                      onPressed: () async {
                        final istWall =
                            WebinarScheduleTimezone.istWallFromUtc(scheduledUtc);
                        final date = await showDatePicker(
                          context: ctx,
                          initialDate: istWall,
                          firstDate: DateTime(2024),
                          lastDate: DateTime(2032),
                          helpText: 'Select date (IST)',
                        );
                        if (date == null) return;
                        if (!ctx.mounted) return;
                        final time = await showTimePicker(
                          context: ctx,
                          initialTime: TimeOfDay.fromDateTime(istWall),
                          helpText: 'Select time (IST)',
                        );
                        if (time == null) return;
                        setState(() {
                          scheduledUtc = WebinarScheduleTimezone.utcFromIstParts(
                            year: date.year,
                            month: date.month,
                            day: date.day,
                            hour: time.hour,
                            minute: time.minute,
                          );
                          timezoneDisplay.text =
                              WebinarScheduleTimezone.usTimezoneDisplay(
                            scheduledUtc,
                          );
                        });
                      },
                      child: const Text('Pick IST'),
                    ),
                  ),
                  _numberField('Duration (minutes)', durationMinutes, (v) {
                    setState(() => durationMinutes = v);
                  }),
                  TextField(
                    controller: timezoneDisplay,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'US time label (auto from IST)',
                      helperText:
                          'Eastern & Pacific with DST. Shown on the mobile app.',
                      filled: true,
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    value: status,
                    items: const [
                      DropdownMenuItem(value: 'upcoming', child: Text('Upcoming')),
                      DropdownMenuItem(value: 'live', child: Text('Live')),
                      DropdownMenuItem(value: 'past', child: Text('Past')),
                      DropdownMenuItem(value: 'draft', child: Text('Draft')),
                    ],
                    onChanged: (v) => setState(() => status = v ?? 'upcoming'),
                    decoration: const InputDecoration(labelText: 'Status'),
                  ),
                  SwitchListTile(
                    value: isPublished,
                    onChanged: (v) => setState(() => isPublished = v),
                    title: const Text('Visible in mobile app'),
                    subtitle: Text(
                      isPublished
                          ? 'Shown on home, webinar list, and detail pages.'
                          : 'Disabled — hidden from app users until re-enabled.',
                    ),
                  ),
                  SwitchListTile(
                    value: liveQa,
                    onChanged: (v) => setState(() => liveQa = v),
                    title: const Text('Live Q&A during session'),
                  ),
                  SwitchListTile(
                    value: sharedAssets,
                    onChanged: (v) => setState(() => sharedAssets = v),
                    title: const Text('Assets shared during webinar'),
                  ),
                  SwitchListTile(
                    value: recordingEnabled,
                    onChanged: (v) => setState(() => recordingEnabled = v),
                    title: const Text('Recording available'),
                  ),
                  SwitchListTile(
                    value: usTimezone,
                    onChanged: (v) => setState(() => usTimezone = v),
                    title: const Text('US Sunday-friendly timing badge'),
                  ),
                  TextField(
                    controller: highlights,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Topic highlights (one per line)',
                    ),
                  ),
                  TextField(
                    controller: descriptionHtml,
                    minLines: 4,
                    maxLines: 10,
                    decoration: const InputDecoration(
                      labelText: 'Detail description (HTML)',
                    ),
                  ),
                  TextField(
                    controller: joinUrl,
                    decoration: const InputDecoration(
                      labelText: 'Live join URL (premium users only in app)',
                    ),
                  ),
                  TextField(
                    controller: youtubeUrl,
                    decoration: const InputDecoration(
                      labelText: 'YouTube promo ID or URL (optional)',
                    ),
                  ),
                  const Divider(height: 28),
                  const Text(
                    'Session recording (Past tab in app)',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: sessionRecordingTitle,
                    decoration: const InputDecoration(
                      labelText: 'Recording title',
                    ),
                  ),
                  TextField(
                    controller: sessionRecordingUrl,
                    decoration: const InputDecoration(
                      labelText: 'Recording URL (YouTube or video link)',
                      hintText: 'Shown on app only after session is past',
                    ),
                  ),
                  TextField(
                    controller: sessionRecordingThumb,
                    decoration: const InputDecoration(
                      labelText: 'Recording thumbnail URL (optional)',
                      hintText: 'Uses YouTube still if empty',
                    ),
                  ),
                  TextField(
                    controller: recordings,
                    minLines: 2,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Extra recordings: title | URL, one per line',
                    ),
                  ),
                  TextField(
                    controller: assets,
                    minLines: 2,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Shared assets: title | URL, one per line',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            AdminDialogSaveActions(
              dialogContext: ctx,
              savedMessage: 'Webinar saved.',
              onSave: () async {
                if (title.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Title is required.')),
                  );
                  return false;
                }
                final payload = <String, dynamic>{
                  'title': title.text.trim(),
                  'subtitle': subtitle.text.trim(),
                  'hostLabel': hostLabel.text.trim(),
                  'topicHighlights': _lines(highlights.text),
                  'descriptionHtml': descriptionHtml.text.trim(),
                  'durationMinutes': durationMinutes,
                  'scheduledAt': Timestamp.fromDate(scheduledUtc),
                  'timezoneDisplay':
                      WebinarScheduleTimezone.usTimezoneDisplay(scheduledUtc),
                  'status': status,
                  'isPublished': isPublished,
                  'joinUrl': joinUrl.text.trim(),
                  'thumbnailImageUrl': thumbnailUrl.text.trim(),
                  'heroImageUrl': heroImageUrl.text.trim().isNotEmpty
                      ? heroImageUrl.text.trim()
                      : thumbnailUrl.text.trim(),
                  'youtubePromoId': _extractYoutubeId(youtubeUrl.text.trim()),
                  'features': {
                    'liveQa': liveQa,
                    'sharedAssets': sharedAssets,
                    'recordingEnabled': recordingEnabled,
                    'usTimezoneFriendly': usTimezone,
                  },
                  'sessionRecordingTitle': sessionRecordingTitle.text.trim().isNotEmpty
                      ? sessionRecordingTitle.text.trim()
                      : 'Webinar Recording',
                  'sessionRecordingUrl': sessionRecordingUrl.text.trim(),
                  'sessionRecordingThumbnailUrl': sessionRecordingThumb.text.trim(),
                  'pastRecordings': _recordingRows(recordings.text),
                  'assetItems': _assetRows(assets.text),
                  'updatedAt': FieldValue.serverTimestamp(),
                };
                if (saveDocId == null) {
                  final ref = await _col.add({
                    ...payload,
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                  saveDocId = ref.id;
                } else {
                  await _col.doc(saveDocId).set(payload, SetOptions(merge: true));
                }
                return true;
              },
            ),
          ],
        ),
      ),
    );
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
                child: Text(
                  'Webinars',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
              ),
              TextButton.icon(
                onPressed: () => _refreshFromServer(context),
                icon: const Icon(Icons.cloud_download_outlined),
                label: const Text('Check server'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => _openEditor(context),
                icon: const Icon(Icons.add),
                label: const Text('Add webinar'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Firestore collection: webinars. The mobile app reads only published webinars '
            '(isPublished). Use Disable on a row to hide a webinar without deleting it. '
            'Session status (Upcoming/Live/Past) is separate from visibility.',
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _col.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Could not load webinars: ${snapshot.error}'),
                  );
                }
                final docs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
                  snapshot.data?.docs ?? [],
                )..sort((a, b) {
                    final ad = _ts(a.data()['scheduledAt']) ??
                        DateTime.fromMillisecondsSinceEpoch(0);
                    final bd = _ts(b.data()['scheduledAt']) ??
                        DateTime.fromMillisecondsSinceEpoch(0);
                    return ad.compareTo(bd);
                  });
                if (docs.isEmpty) {
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.live_tv_outlined,
                              size: 48,
                              color: Color(0xFF5E35B1),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No webinars in Firestore',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'The app used to show a built-in preview when this list was empty. '
                              'Publish the default webinar to Firestore so admin and app use the same data.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            FilledButton.icon(
                              onPressed: () => _seedDefaultWebinar(context),
                              icon: const Icon(Icons.cloud_upload_outlined),
                              label: const Text('Publish default webinar'),
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: () => _openEditor(context),
                              icon: const Icon(Icons.add),
                              label: const Text('Add custom webinar'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    final at = WebinarScheduleTimezone.utcFromFirestore(
                      data['scheduledAt'],
                    );
                    final scheduleLabel = at != null
                        ? '${WebinarScheduleTimezone.formatIstShort(at)}\n'
                            '${WebinarScheduleTimezone.usTimezoneDisplay(at)}'
                        : 'No date';
                    final published = data['isPublished'] != false;
                    final titleText = _text(data['title'], 'Untitled');
                    final sessionStatus = _titleCase(_text(data['status'], 'upcoming'));
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    titleText,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    scheduleLabel,
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: [
                                      Chip(
                                        visualDensity: VisualDensity.compact,
                                        label: Text(sessionStatus),
                                      ),
                                      Chip(
                                        visualDensity: VisualDensity.compact,
                                        avatar: Icon(
                                          published
                                              ? Icons.visibility_rounded
                                              : Icons.visibility_off_outlined,
                                          size: 16,
                                          color: published
                                              ? Colors.green.shade700
                                              : Colors.grey.shade600,
                                        ),
                                        label: Text(
                                          published ? 'Visible in app' : 'Disabled',
                                        ),
                                        backgroundColor: published
                                            ? Colors.green.withValues(alpha: 0.08)
                                            : Colors.grey.withValues(alpha: 0.12),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Wrap(
                              spacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                OutlinedButton(
                                  onPressed: published
                                      ? () => _confirmDisableWebinar(
                                            context,
                                            docId: doc.id,
                                            title: titleText,
                                          )
                                      : () => _setPublished(
                                            context,
                                            docId: doc.id,
                                            published: true,
                                          ),
                                  child: Text(published ? 'Disable' : 'Enable'),
                                ),
                                IconButton(
                                  tooltip: 'Edit',
                                  onPressed: () =>
                                      _openEditor(context, docId: doc.id),
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                                IconButton(
                                  tooltip: 'Delete webinar',
                                  onPressed: () => _confirmDeleteWebinar(
                                    context,
                                    docId: doc.id,
                                    title: titleText,
                                  ),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                  ),
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
          ),
        ],
      ),
    );
  }

  Widget _numberField(String label, int value, ValueChanged<int> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        initialValue: '$value',
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label),
        onChanged: (v) => onChanged(int.tryParse(v) ?? value),
      ),
    );
  }
}

String _text(Object? raw, String fallback) {
  final t = raw?.toString().trim() ?? '';
  return t.isEmpty ? fallback : t;
}

int _int(Object? raw, int fallback) {
  if (raw is num) return raw.toInt();
  return int.tryParse(raw?.toString() ?? '') ?? fallback;
}

DateTime? _ts(Object? raw) {
  if (raw is Timestamp) return raw.toDate();
  if (raw is DateTime) return raw;
  return DateTime.tryParse(raw?.toString() ?? '');
}

Map<String, dynamic> _defaultWebinarPayload() {
  final scheduledUtc = WebinarScheduleTimezone.nextSunday8pmIstUtc();
  return {
    'isPublished': true,
    'title': 'NEET 2027 Strategy for NRI Families',
    'subtitle': 'Live session with TestprepKart mentors',
    'hostLabel': 'TestprepKart NEET Team',
    'topicHighlights': [
      'NEET 2027 timeline for Class 11 & 12 NRI students',
      'How to balance school abroad with NEET prep',
      'Q&A on counselling, fees, and study plans',
    ],
    'timezoneDisplay': WebinarScheduleTimezone.usTimezoneDisplay(scheduledUtc),
    'durationMinutes': 75,
    'scheduledAt': Timestamp.fromDate(scheduledUtc),
    'status': 'upcoming',
    'joinUrl': '',
    'descriptionHtml':
        '<p>Join our academic team for a focused webinar on NEET preparation while studying outside India.</p>',
    'thumbnailImageUrl':
        'https://images.unsplash.com/photo-1571260899304-425eee4c353f?w=800&q=80',
    'youtubePromoId': '',
    'features': {
      'liveQa': true,
      'sharedAssets': true,
      'recordingEnabled': true,
      'usTimezoneFriendly': true,
    },
    'sessionRecordingTitle': 'Webinar Recording',
    'sessionRecordingUrl': '',
    'sessionRecordingThumbnailUrl': '',
    'pastRecordings': <Map<String, dynamic>>[],
    'assetItems': <Map<String, dynamic>>[],
  };
}

List<String> _lines(String raw) => raw
    .split('\n')
    .map((e) => e.trim())
    .where((e) => e.isNotEmpty)
    .toList();

String _linesText(Object? raw) {
  if (raw is! List) return '';
  return raw.map((e) => e.toString()).join('\n');
}

List<Map<String, dynamic>> _recordingRows(String raw) => raw
    .split('\n')
    .where((line) => line.trim().isNotEmpty)
    .map((line) {
      final parts = line.split('|').map((e) => e.trim()).toList();
      return {
        'title': parts.isNotEmpty ? parts[0] : 'Recording',
        'url': parts.length > 1 ? parts[1] : '',
      };
    })
    .toList();

List<Map<String, dynamic>> _assetRows(String raw) => raw
    .split('\n')
    .where((line) => line.trim().isNotEmpty)
    .map((line) {
      final parts = line.split('|').map((e) => e.trim()).toList();
      return {
        'title': parts.isNotEmpty ? parts[0] : 'Asset',
        'url': parts.length > 1 ? parts[1] : '',
      };
    })
    .toList();

String _recordingsText(Object? raw) {
  if (raw is! List) return '';
  return raw.map((item) {
    final map = item is Map ? item : const {};
    return '${_text(map['title'], '')} | ${_text(map['url'], '')}';
  }).join('\n');
}

String _assetsText(Object? raw) {
  if (raw is! List) return '';
  return raw.map((item) {
    final map = item is Map ? item : const {};
    return '${_text(map['title'], '')} | ${_text(map['url'], '')}';
  }).join('\n');
}

String _normalizeStatus(Object? raw) {
  final s = (raw?.toString() ?? 'upcoming').toLowerCase().trim();
  const allowed = {'upcoming', 'live', 'past', 'draft'};
  if (allowed.contains(s)) return s;
  if (s == 'scheduled' || s == 'published') return 'upcoming';
  return 'upcoming';
}

String _titleCase(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return t;
  return t[0].toUpperCase() + t.substring(1).toLowerCase();
}

String _extractYoutubeId(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return '';
  final uri = Uri.tryParse(value);
  if (uri != null && uri.host.isNotEmpty) {
    if (uri.host.contains('youtu.be')) {
      return uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
    }
    if (uri.host.contains('youtube.com')) {
      final queryId = uri.queryParameters['v'];
      if (queryId != null && queryId.isNotEmpty) return queryId;
    }
  }
  return value.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
}
