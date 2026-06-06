import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firestore_db.dart';
import '../utils/analysis_slot_template.dart';
import '../widgets/admin_dialog_save_actions.dart';

/// Recurring IST demo times (`analysis_slot_templates`) — same slots every bookable day on the app.
class SlotsManagementPage extends StatefulWidget {
  const SlotsManagementPage({super.key});

  @override
  State<SlotsManagementPage> createState() => _SlotsManagementPageState();
}

class _SlotsManagementPageState extends State<SlotsManagementPage> {
  CollectionReference<Map<String, dynamic>> get _col =>
      FirestoreDb.instance.collection('analysis_slot_templates');

  int _startHour = 10;
  int _startMinute = 0;
  int _durationMins = 60;
  int _capacity = 1;
  bool _creating = false;

  static const _timePresets = <({String label, int hour, int minute})>[
    (label: '10:00 AM', hour: 10, minute: 0),
    (label: '2:30 PM', hour: 14, minute: 30),
    (label: '6:00 PM', hour: 18, minute: 0),
    (label: '8:00 PM', hour: 20, minute: 0),
  ];

  void _snack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade800 : null,
      ),
    );
  }

  Future<bool> _createTemplate() async {
    setState(() => _creating = true);
    try {
      await _col.add({
        ...AnalysisSlotTemplate(
          id: '',
          istHour: _startHour,
          istMinute: _startMinute,
          durationMinutes: _durationMins,
          capacity: _capacity,
        ).toFirestore(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return true;
      _snack(
        'Time slot saved. It applies every day — students book for IST tomorrow only.',
      );
      return true;
    } catch (e) {
      _snack('Could not save slot: $e', isError: true);
      return false;
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _setAvailability(String docId, bool available) async {
    try {
      await _col.doc(docId).set({
        'isAvailable': available,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      _snack('Update failed: $e', isError: true);
    }
  }

  Future<void> _deleteTemplate(String docId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete time slot?'),
        content: const Text(
          'This recurring IST time will be removed from the mobile app for all days.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _col.doc(docId).delete();
      _snack('Slot deleted.');
    } catch (e) {
      _snack('Delete failed: $e', isError: true);
    }
  }

  Widget _buildCreatePanel() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add recurring time slot (IST)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            const Text(
              'No date needed — each time applies to every bookable day. '
              'On the app, parents only see slots for IST tomorrow (not today).',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _timePresets.map((p) {
                final selected =
                    _startHour == p.hour && _startMinute == p.minute;
                return ChoiceChip(
                  label: Text(p.label),
                  selected: selected,
                  onSelected: (_) => setState(() {
                    _startHour = p.hour;
                    _startMinute = p.minute;
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _startHour,
                    decoration: const InputDecoration(
                      labelText: 'Hour (IST)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: List.generate(24, (i) => i)
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(e.toString().padLeft(2, '0')),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _startHour = v ?? _startHour),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _startMinute,
                    decoration: const InputDecoration(
                      labelText: 'Minute',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [0, 15, 30, 45]
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(e.toString().padLeft(2, '0')),
                          ),
                        )
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _startMinute = v ?? _startMinute),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _durationMins,
                    decoration: const InputDecoration(
                      labelText: 'Duration',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [30, 45, 60, 90, 120]
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text('$e min'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _durationMins = v ?? _durationMins),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                SizedBox(
                  width: 120,
                  child: TextFormField(
                    initialValue: '$_capacity',
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Capacity',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) => _capacity =
                        (int.tryParse(v.trim()) ?? 1).clamp(1, 99),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _creating ? null : () => _createTemplate(),
                  icon: _creating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_rounded),
                  label: Text(_creating ? 'Saving…' : 'Add time slot'),
                ),
              ],
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCreatePanel(),
          const SizedBox(height: 16),
          Text(
            'Active recurring slots (IST)',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Students pick one of these times for tomorrow (IST) in their own timezone on the app.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _col.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  final err = snapshot.error.toString();
                  final denied = err.contains('permission-denied');
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.lock_outline, size: 40),
                          const SizedBox(height: 12),
                          Text(
                            denied
                                ? 'Firestore permission denied'
                                : 'Could not load slots',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(err, textAlign: TextAlign.center),
                          if (denied) ...[
                            const SizedBox(height: 12),
                            const Text(
                              'Deploy rules from neetprep_flutter:\n'
                              'firebase deploy --only firestore:default:rules\n\n'
                              'You must be signed in as owner or moderator. '
                              'Collection: analysis_slot_templates',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data?.docs ?? const [];
                final templates = docs
                    .map(AnalysisSlotTemplate.fromDoc)
                    .toList()
                  ..sort((a, b) => a.sortKey.compareTo(b.sortKey));

                if (templates.isEmpty) {
                  return const Center(
                    child: Text(
                      'No time slots yet.\nAdd IST times above — they apply to all bookable days.',
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: templates.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, index) {
                    final t = templates[index];
                    return Card(
                      child: ListTile(
                        title: Text('${t.istTimeLabel} · ${t.durationLabel}'),
                        subtitle: Text(
                          t.isAvailable
                              ? 'Shown on app · capacity ${t.capacity} · next bookable: ${t.previewTomorrowLabel}'
                              : 'Hidden on app · capacity ${t.capacity}',
                        ),
                        leading: Switch(
                          value: t.isAvailable,
                          onChanged: (v) => _setAvailability(t.id, v),
                        ),
                        trailing: IconButton(
                          tooltip: 'Delete',
                          onPressed: () => _deleteTemplate(t.id),
                          icon: const Icon(Icons.delete_outline),
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
