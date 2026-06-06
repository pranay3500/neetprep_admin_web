import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../services/firestore_db.dart';
import '../widgets/admin_dialog_save_actions.dart';

class HowItWorksCmsPage extends StatelessWidget {
  const HowItWorksCmsPage({super.key});

  CollectionReference<Map<String, dynamic>> get _col => FirestoreDb.instance
      .collection('content_library')
      .doc('expected_score')
      .collection('how_it_works');

  Future<void> _seedDefaults(BuildContext context) async {
    try {
      final snapshot = await _col.limit(1).get();
      if (snapshot.docs.isNotEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('How-It-Works already has data. Seed skipped.'),
            ),
          );
        }
        return;
      }
      final defaults = [
        {
          'title': 'Submit your details',
          'description':
              'Share current grade, target score and preferred subjects for review.',
          'order': 1,
          'iconKey': 'calendar',
          'colorKey': 'purple',
        },
        {
          'title': 'Get expert analysis',
          'description':
              'Our academics team evaluates profile and NEET readiness.',
          'order': 2,
          'iconKey': 'analysis',
          'colorKey': 'blue',
        },
        {
          'title': 'Receive strategy plan',
          'description':
              'Get a practical roadmap with milestones and score-improvement guidance.',
          'order': 3,
          'iconKey': 'score',
          'colorKey': 'green',
        },
      ];
      final batch = FirestoreDb.instance.batch();
      for (final item in defaults) {
        final doc = _col.doc();
        batch.set(doc, {
          ...item,
          'isPublished': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Seeded starter How-It-Works steps.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Seed failed: $e')));
      }
    }
  }

  Future<void> _openEditor(
    BuildContext context, {
    DocumentSnapshot<Map<String, dynamic>>? doc,
  }) async {
    final data = doc?.data() ?? <String, dynamic>{};
    final title = TextEditingController(text: data['title']?.toString() ?? '');
    final desc = TextEditingController(
      text: data['description']?.toString() ?? '',
    );
    final order = TextEditingController(text: (data['order'] ?? 1).toString());
    String iconKey = data['iconKey']?.toString() ?? 'analysis';
    String colorKey = data['colorKey']?.toString() ?? 'purple';
    bool isPublished = data['isPublished'] != false;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
            title: Text(doc == null ? 'Add Step' : 'Edit Step'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    TextField(
                      controller: title,
                      decoration: const InputDecoration(labelText: 'Title'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: desc,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: order,
                      decoration: const InputDecoration(labelText: 'Order'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: iconKey,
                      items: const ['calendar', 'analysis', 'score']
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setState(() => iconKey = v ?? 'analysis'),
                      decoration: const InputDecoration(labelText: 'Icon Key'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: colorKey,
                      items: const ['purple', 'blue', 'green']
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setState(() => colorKey = v ?? 'purple'),
                      decoration: const InputDecoration(labelText: 'Color Key'),
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      value: isPublished,
                      onChanged: (v) => setState(() => isPublished = v),
                      title: const Text('Published'),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              AdminDialogSaveActions(
                dialogContext: ctx,
                savedMessage: 'Step saved.',
                onSave: () async {
                  final payload = <String, dynamic>{
                    'title': title.text.trim(),
                    'description': desc.text.trim(),
                    'order': int.tryParse(order.text.trim()) ?? 1,
                    'iconKey': iconKey,
                    'colorKey': colorKey,
                    'isPublished': isPublished,
                    'updatedAt': FieldValue.serverTimestamp(),
                  };
                  if (doc == null) {
                    await _col.add({
                      ...payload,
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                  } else {
                    await _col
                        .doc(doc.id)
                        .set(payload, SetOptions(merge: true));
                  }
                  return true;
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () => _seedDefaults(context),
                icon: const Icon(Icons.auto_fix_high_rounded),
                label: const Text('Seed Starter Data'),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: () => _openEditor(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Step'),
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
                  return _FirestoreErrorState(
                    message: snapshot.error.toString(),
                    projectId: Firebase.app().options.projectId,
                  );
                }
                final docs = snapshot.data?.docs ?? const [];
                if (docs.isEmpty) {
                  return _EmptyHowItWorksState(
                    onSeed: () => _seedDefaults(context),
                  );
                }
                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (_, index) {
                    final doc = docs[index];
                    final d = doc.data();
                    return Card(
                      child: ListTile(
                        title: Text(d['title']?.toString() ?? 'Untitled'),
                        subtitle: Text(d['description']?.toString() ?? ''),
                        leading: CircleAvatar(
                          child: Text('${d['order'] ?? index + 1}'),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () => _openEditor(context, doc: doc),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
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

class _EmptyHowItWorksState extends StatelessWidget {
  const _EmptyHowItWorksState({required this.onSeed});

  final VoidCallback onSeed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.inbox_outlined, size: 34),
                const SizedBox(height: 10),
                const Text(
                  'No steps configured yet',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Collection is connected but empty. Seed starter records or add your first step.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: onSeed,
                  icon: const Icon(Icons.auto_fix_high_rounded),
                  label: const Text('Seed Starter Data'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FirestoreErrorState extends StatelessWidget {
  const _FirestoreErrorState({required this.message, required this.projectId});

  final String message;
  final String projectId;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.error_outline_rounded, color: Color(0xFFC62828)),
                    SizedBox(width: 8),
                    Text(
                      'Firestore load failed',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text('Project: $projectId'),
                const SizedBox(height: 6),
                Text(message),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
