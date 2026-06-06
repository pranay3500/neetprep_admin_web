import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/firestore_db.dart';
import '../widgets/admin_dialog_save_actions.dart';

class SupportCmsPage extends StatefulWidget {
  const SupportCmsPage({super.key});

  @override
  State<SupportCmsPage> createState() => _SupportCmsPageState();
}

class _SupportCmsPageState extends State<SupportCmsPage> {
  final _db = FirestoreDb.instance;
  
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  
  final _versionCtrl = TextEditingController();
  final _blurbCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _privacyCtrl = TextEditingController();
  final _termsCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final supportDoc = await _db.collection('cms_support').doc('main').get();
    if (supportDoc.exists) {
      final data = supportDoc.data()!;
      _emailCtrl.text = data['contactEmail'] ?? '';
      _phoneCtrl.text = data['contactPhone'] ?? '';
      _whatsappCtrl.text = data['whatsappNumber'] ?? '';
    }

    final aboutDoc = await _db.collection('cms_about').doc('main').get();
    if (aboutDoc.exists) {
      final data = aboutDoc.data()!;
      _versionCtrl.text = data['version'] ?? '';
      _blurbCtrl.text = data['blurb'] ?? '';
      _websiteCtrl.text = data['websiteUrl'] ?? '';
      _privacyCtrl.text = data['privacyPolicyContent'] ?? '';
      _termsCtrl.text = data['termsOfServiceContent'] ?? '';
    }
  }

  Future<void> _saveSupport() async {
    await _db.collection('cms_support').doc('main').set({
      'contactEmail': _emailCtrl.text.trim(),
      'contactPhone': _phoneCtrl.text.trim(),
      'whatsappNumber': _whatsappCtrl.text.trim(),
    }, SetOptions(merge: true));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Support settings saved')));
  }

  Future<void> _saveAbout() async {
    await _db.collection('cms_about').doc('main').set({
      'version': _versionCtrl.text.trim(),
      'blurb': _blurbCtrl.text.trim(),
      'websiteUrl': _websiteCtrl.text.trim(),
      'privacyPolicyContent': _privacyCtrl.text.trim(),
      'termsOfServiceContent': _termsCtrl.text.trim(),
    }, SetOptions(merge: true));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('About settings saved')));
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: const TabBar(
          tabs: [
            Tab(text: 'Contact Info'),
            Tab(text: 'FAQ Management'),
            Tab(text: 'About App'),
          ],
        ),
        body: TabBarView(
          children: [
            _buildContactTab(),
            _buildFaqTab(),
            _buildAboutTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildContactTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextField('Contact Email', _emailCtrl),
          const SizedBox(height: 16),
          _buildTextField('Contact Phone', _phoneCtrl),
          const SizedBox(height: 16),
          _buildTextField('WhatsApp Number', _whatsappCtrl),
          const SizedBox(height: 32),
          FilledButton(onPressed: _saveSupport, child: const Text('Save Contact Info')),
        ],
      ),
    );
  }

  Widget _buildAboutTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextField('App Version', _versionCtrl),
          const SizedBox(height: 16),
          _buildTextField('About Blurb', _blurbCtrl, maxLines: 4),
          const SizedBox(height: 16),
          _buildTextField('Website URL', _websiteCtrl),
          const SizedBox(height: 16),
          _buildTextField('Privacy Policy Content', _privacyCtrl, maxLines: 6),
          const SizedBox(height: 16),
          _buildTextField('Terms of Service Content', _termsCtrl, maxLines: 6),
          const SizedBox(height: 32),
          FilledButton(onPressed: _saveAbout, child: const Text('Save About Info')),
        ],
      ),
    );
  }

  Widget _buildFaqTab() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _db.collection('cms_support').doc('main').snapshots(),
      builder: (context, snapshot) {
        final faqs = (snapshot.data?.data()?['faqs'] as List? ?? []);
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () => _openFaqEditor(faqs),
                  icon: const Icon(Icons.add),
                  label: const Text('Add FAQ'),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: faqs.length,
                itemBuilder: (context, index) {
                  final faq = faqs[index];
                  return ListTile(
                    title: Text(faq['question'] ?? ''),
                    subtitle: Text(faq['answer'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(onPressed: () => _openFaqEditor(faqs, index: index), icon: const Icon(Icons.edit)),
                        IconButton(
                          onPressed: () {
                            final newList = List.from(faqs)..removeAt(index);
                            _db.collection('cms_support').doc('main').update({'faqs': newList});
                          },
                          icon: const Icon(Icons.delete),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openFaqEditor(List faqs, {int? index}) async {
    final qCtrl = TextEditingController(text: index != null ? faqs[index]['question'] : '');
    final aCtrl = TextEditingController(text: index != null ? faqs[index]['answer'] : '');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(index == null ? 'Add FAQ' : 'Edit FAQ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: qCtrl, decoration: const InputDecoration(labelText: 'Question')),
            TextField(controller: aCtrl, decoration: const InputDecoration(labelText: 'Answer'), maxLines: 3),
          ],
        ),
        actions: [
          AdminDialogSaveActions(
            dialogContext: ctx,
            savedMessage: 'FAQ saved.',
            onSave: () async {
              final newList = List.from(faqs);
              final item = {'question': qCtrl.text, 'answer': aCtrl.text};
              if (index == null) {
                newList.add(item);
              } else {
                newList[index] = item;
              }
              await _db.collection('cms_support').doc('main').update({
                'faqs': newList,
              });
              return true;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController ctrl, {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
