import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firestore_db.dart';
import '../widgets/admin_dialog_save_actions.dart';

/// CRUD for `medical_colleges` (same collection as the NEET Prep Flutter app).
class MedicalCollegesCmsPage extends StatelessWidget {
  const MedicalCollegesCmsPage({super.key});

  CollectionReference<Map<String, dynamic>> get _col =>
      FirestoreDb.instance.collection('medical_colleges');

  static const _types = ['GOVT', 'CENTRAL', 'PRIVATE', 'DEEMED'];

  int _asInt(dynamic v, [int def = 0]) {
    if (v == null) return def;
    if (v is int) return v;
    if (v is double) return v.round();
    return int.tryParse(v.toString()) ?? def;
  }

  Future<void> _openEditor(
    BuildContext context, {
    DocumentSnapshot<Map<String, dynamic>>? doc,
  }) async {
    final data = doc?.data() ?? <String, dynamic>{};
    final rank = TextEditingController(text: '${_asInt(data['rank'], 1)}');
    final stateRank = TextEditingController(
      text: data['stateRank'] != null ? '${_asInt(data['stateRank'])}' : '',
    );
    final collegeName = TextEditingController(
      text: data['collegeName']?.toString() ?? data['name']?.toString() ?? '',
    );
    final city = TextEditingController(text: data['city']?.toString() ?? '');
    final state = TextEditingController(text: data['state']?.toString() ?? '');
    String collegeType =
        '${data['collegeType'] ?? data['type'] ?? 'GOVT'}'.toUpperCase();
    if (!_types.contains(collegeType)) collegeType = 'GOVT';

    final annualFee = TextEditingController(
      text: '${_asInt(data['annualFeeInr'] ?? data['annualTuitionINR'])}',
    );
    final totalFee = TextEditingController(
      text: '${_asInt(data['totalFeeInr'] ?? data['totalCourseFeeINR'])}',
    );
    final stateCutoff = TextEditingController(
      text: '${_asInt(data['stateCutoff'] ?? data['generalCutoff'])}',
    );
    final aiqCutoff = TextEditingController(
      text: '${_asInt(data['aiqCutoff'] ?? data['aiqGeneral'])}',
    );
    final seats = TextEditingController(
      text: '${_asInt(data['seats'] ?? data['totalMBBSSeats'], 150)}',
    );
    final establishedYear = TextEditingController(
      text: '${_asInt(data['establishedYear'] ?? data['established_year'], 1950)}',
    );
    final nirfRank = TextEditingController(
      text: data['nirfRank'] != null ? '${_asInt(data['nirfRank'])}' : '',
    );

    bool isActive = data['isActive'] != false && data['is_active'] != false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(doc == null ? 'Add Medical College' : 'Edit Medical College'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (doc != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SelectableText(
                        'Firestore document id: ${doc.id}',
                        style: Theme.of(ctx).textTheme.bodySmall,
                      ),
                    ),
                  TextField(
                    controller: rank,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Rank (national sort)'),
                  ),
                  TextField(
                    controller: stateRank,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'State rank (optional)',
                    ),
                  ),
                  TextField(
                    controller: collegeName,
                    decoration: const InputDecoration(labelText: 'College name'),
                  ),
                  TextField(
                    controller: city,
                    decoration: const InputDecoration(labelText: 'City'),
                  ),
                  TextField(
                    controller: state,
                    decoration: const InputDecoration(labelText: 'State / UT'),
                  ),
                  DropdownButtonFormField<String>(
                    value: collegeType,
                    items: _types
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) => setState(() => collegeType = v ?? 'GOVT'),
                    decoration: const InputDecoration(labelText: 'College type'),
                  ),
                  TextField(
                    controller: annualFee,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Annual fee (INR)'),
                  ),
                  TextField(
                    controller: totalFee,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Total course fee (INR)'),
                  ),
                  TextField(
                    controller: stateCutoff,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'State cutoff'),
                  ),
                  TextField(
                    controller: aiqCutoff,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'AIQ cutoff'),
                  ),
                  TextField(
                    controller: seats,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'MBBS seats'),
                  ),
                  TextField(
                    controller: establishedYear,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Established year'),
                  ),
                  TextField(
                    controller: nirfRank,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'NIRF rank (optional)'),
                  ),
                  SwitchListTile(
                    value: isActive,
                    title: const Text('Active (visible in app)'),
                    onChanged: (v) => setState(() => isActive = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            AdminDialogSaveActions(
              dialogContext: ctx,
              savedMessage: 'College saved.',
              onSave: () async {
                final r = int.tryParse(rank.text.trim()) ?? 9999;
                final srRaw = stateRank.text.trim();
                final sr = srRaw.isEmpty ? null : int.tryParse(srRaw);
                final af = int.tryParse(annualFee.text.trim()) ?? 0;
                final tfRaw = totalFee.text.trim();
                final tf = tfRaw.isEmpty
                    ? (af > 0 ? (af * 55 ~/ 10) : 0)
                    : (int.tryParse(tfRaw) ?? 0);

                final payload = <String, dynamic>{
                  'rank': r,
                  if (sr != null) 'stateRank': sr,
                  'collegeName': collegeName.text.trim(),
                  'city': city.text.trim(),
                  'state': state.text.trim(),
                  'collegeType': collegeType,
                  'annualFeeInr': af,
                  'totalFeeInr': tf,
                  'stateCutoff': int.tryParse(stateCutoff.text.trim()) ?? 0,
                  'aiqCutoff': int.tryParse(aiqCutoff.text.trim()) ?? 0,
                  'seats': int.tryParse(seats.text.trim()) ?? 150,
                  'establishedYear':
                      int.tryParse(establishedYear.text.trim()) ?? 1950,
                  'isActive': isActive,
                  'updatedAt': FieldValue.serverTimestamp(),
                };
                final nirf = nirfRank.text.trim();
                if (nirf.isEmpty) {
                  payload['nirfRank'] = FieldValue.delete();
                } else {
                  final n = int.tryParse(nirf);
                  if (n != null) payload['nirfRank'] = n;
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

    rank.dispose();
    stateRank.dispose();
    collegeName.dispose();
    city.dispose();
    state.dispose();
    annualFee.dispose();
    totalFee.dispose();
    stateCutoff.dispose();
    aiqCutoff.dispose();
    seats.dispose();
    establishedYear.dispose();
    nirfRank.dispose();
  }

  Future<void> _confirmDeactivate(BuildContext context, String docId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deactivate college'),
        content: const Text(
          'The app hides inactive rows (favorites may still reference this id). '
          'You can restore it by editing and turning Active back on.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await _col.doc(docId).set(
        {'isActive': false, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () => _openEditor(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add college'),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _col.orderBy('rank').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Failed to load medical colleges.\n'
                        'Create a composite index if Firestore asks for '
                        '`rank` ascending (check console link in error).\n\n'
                        '${snapshot.error}',
                      ),
                    ),
                  );
                }
                final docs = snapshot.data?.docs ?? const [];
                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No documents in medical_colleges. Add rows here or populate from the app seed.',
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, index) {
                    final doc = docs[index];
                    final d = doc.data();
                    final name =
                        d['collegeName']?.toString() ?? d['name']?.toString() ?? '?';
                    final active = d['isActive'] != false && d['is_active'] != false;
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(child: Text('${d['rank'] ?? '-'}')),
                        title: Text(name),
                        subtitle: Text(
                          '${d['city'] ?? ''}, ${d['state'] ?? ''} · '
                          '${d['collegeType'] ?? d['type'] ?? '-'} '
                          '(${active ? 'active' : 'inactive'})',
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Edit',
                              onPressed: () => _openEditor(context, doc: doc),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              tooltip: 'Deactivate',
                              onPressed: active
                                  ? () => _confirmDeactivate(context, doc.id)
                                  : null,
                              icon: const Icon(Icons.visibility_off_outlined),
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
