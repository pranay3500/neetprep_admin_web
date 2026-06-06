import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/admin_email/admin_email_config.dart';
import '../services/admin_email/admin_email_dispatcher.dart';
import '../services/firestore_db.dart';
import '../widgets/admin_dialog_save_actions.dart';
import 'dashboard_banners_settings_tab.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _senderName = TextEditingController();
  final _fromEmail = TextEditingController();
  final _replyToEmail = TextEditingController();
  final _adminRecipients = TextEditingController();
  final _smtpHost = TextEditingController();
  final _smtpPort = TextEditingController();
  final _smtpUsername = TextEditingController();
  final _smtpPassword = TextEditingController();
  final _apiEndpoint = TextEditingController();
  final _apiKey = TextEditingController();
  final _relayUrl = TextEditingController();
  final _contactEmail = TextEditingController();
  final _whatsappNumber = TextEditingController();
  final _websiteUrl = TextEditingController();
  final _aboutVersion = TextEditingController();
  final _aboutBlurb = TextEditingController();
  final _aboutWebsiteUrl = TextEditingController();
  final _privacyPolicyContent = TextEditingController();
  final _termsOfServiceContent = TextEditingController();
  final _androidRatingUrl = TextEditingController();
  final _iosRatingUrl = TextEditingController();
  final _previewFraction = TextEditingController(text: '0.38');
  final _freeUnitIndexMax = TextEditingController(text: '3');
  final _freeSiblingIndexMax = TextEditingController(text: '3');
  final _alwaysFreeNodeIds = TextEditingController();
  final _alwaysLockedNodeIds = TextEditingController();

  bool _loaded = false;
  bool _supportLoaded = false;
  bool _aboutLoaded = false;
  bool _contentLibLoaded = false;
  bool _contentGatingEnabled = true;
  bool _isSaving = false;
  bool _masterEnabled = false;
  bool _smtpSsl = true;
  String _provider = 'SMTP';
  Map<String, bool> _triggers = Map<String, bool>.from(_defaultTriggers);
  Map<String, dynamic> _templates = {};

  DocumentReference<Map<String, dynamic>> get _doc =>
      FirestoreDb.instance.collection('admin_settings').doc('email');

  DocumentReference<Map<String, dynamic>> get _supportDoc =>
      FirestoreDb.instance.collection('cms_support').doc('main');

  DocumentReference<Map<String, dynamic>> get _aboutDoc =>
      FirestoreDb.instance.collection('cms_about').doc('main');

  DocumentReference<Map<String, dynamic>> get _contentLibraryDoc =>
      FirestoreDb.instance.collection('cms_content_library').doc('main');

  @override
  void dispose() {
    _senderName.dispose();
    _fromEmail.dispose();
    _replyToEmail.dispose();
    _adminRecipients.dispose();
    _smtpHost.dispose();
    _smtpPort.dispose();
    _smtpUsername.dispose();
    _smtpPassword.dispose();
    _apiEndpoint.dispose();
    _apiKey.dispose();
    _relayUrl.dispose();
    _contactEmail.dispose();
    _whatsappNumber.dispose();
    _websiteUrl.dispose();
    _aboutVersion.dispose();
    _aboutBlurb.dispose();
    _aboutWebsiteUrl.dispose();
    _privacyPolicyContent.dispose();
    _termsOfServiceContent.dispose();
    _androidRatingUrl.dispose();
    _iosRatingUrl.dispose();
    _previewFraction.dispose();
    _freeUnitIndexMax.dispose();
    _freeSiblingIndexMax.dispose();
    _alwaysFreeNodeIds.dispose();
    _alwaysLockedNodeIds.dispose();
    super.dispose();
  }

  void _hydrate(Map<String, dynamic> data) {
    if (_loaded) return;
    _loaded = true;
    _masterEnabled = data['masterEnabled'] == true;
    final savedProvider = _text(data['provider'], 'SMTP');
    _provider = _providerOptions.contains(savedProvider) ? savedProvider : 'SMTP';
    _senderName.text = _text(data['senderName'], 'TestprepKart NEET');
    _fromEmail.text = _text(data['fromEmail'], '');
    _replyToEmail.text = _text(data['replyToEmail'], '');
    _adminRecipients.text = _listText(data['adminRecipients']);
    final smtp = _map(data['smtp']);
    _smtpHost.text = _text(smtp['host'], '');
    _smtpPort.text = _text(smtp['port'], '587');
    _smtpUsername.text = _text(smtp['username'], '');
    _smtpPassword.text = _text(smtp['password'], '');
    _smtpSsl = smtp['useSsl'] != false;
    final api = _map(data['api']);
    _apiEndpoint.text = _text(api['endpoint'], '');
    _apiKey.text = _text(api['apiKey'], '');
    _relayUrl.text = _text(data['relayUrl'], AdminEmailConfig.defaultRelayUrl);
    _triggers = {
      ..._defaultTriggers,
      ..._map(data['triggers']).map(
        (key, value) => MapEntry(key, value == true),
      ),
    };
    _templates = _map(data['templates']);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
      child: Column(
        children: [
          const Material(
            color: Colors.white,
            child: TabBar(
              isScrollable: true,
              tabs: [
                Tab(icon: Icon(Icons.email_outlined), text: 'Email Config'),
                Tab(icon: Icon(Icons.contact_support_outlined), text: 'Contact Us'),
                Tab(icon: Icon(Icons.quiz_outlined), text: 'FAQ'),
                Tab(icon: Icon(Icons.policy_outlined), text: 'About & Legal'),
                Tab(icon: Icon(Icons.lock_open_rounded), text: 'Content Library'),
                Tab(icon: Icon(Icons.view_carousel_outlined), text: 'Home Banners'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _emailConfigurationTab(),
                _contactUsTab(),
                _faqTab(),
                _aboutLegalTab(),
                _contentLibraryTab(),
                const DashboardBannersSettingsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emailConfigurationTab() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _doc.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !_loaded) {
          return const Center(child: CircularProgressIndicator());
        }
        _hydrate(snapshot.data?.data() ?? const <String, dynamic>{});
        return Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Email Configuration',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Switch(
                    value: _masterEnabled,
                    onChanged: (value) =>
                        setState(() => _masterEnabled = value),
                  ),
                  const SizedBox(width: 8),
                  Text(_masterEnabled ? 'Enabled' : 'Disabled'),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Emails are sent from this admin web app (no Firebase Blaze). '
                'While you are signed in, the app watches Firestore and sends mail through your Email Relay URL using the provider below.',
              ),
              const SizedBox(height: 18),
              _section(
                title: 'Email relay (required)',
                children: [
                  _field(
                    _relayUrl,
                    'Email Relay URL',
                    keyboardType: TextInputType.url,
                  ),
                  const Text(
                    'Host the Node relay from deploy/email_relay on Satlas (same server). '
                    'Default: https://neetappadmin.satlas.org/api/send-email',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
              _section(
                title: 'Sender Details',
                children: [
                  _row([
                    _field(_senderName, 'Sender Name'),
                    _field(
                      _fromEmail,
                      'From Email',
                      keyboardType: TextInputType.emailAddress,
                      requiredEmail: true,
                    ),
                  ]),
                  _row([
                    _field(
                      _replyToEmail,
                      'Reply-To Email',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    _field(
                      _adminRecipients,
                      'Admin Alert Recipients (comma-separated)',
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ]),
                ],
              ),
              _section(
                title: 'Provider Settings',
                children: [
                  DropdownButtonFormField<String>(
                    value: _provider,
                    decoration: const InputDecoration(
                      labelText: 'Email Provider',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'SMTP', child: Text('SMTP')),
                      DropdownMenuItem(
                        value: 'SendGrid',
                        child: Text('SendGrid / API Provider'),
                      ),
                      DropdownMenuItem(
                        value: 'Firebase Extension',
                        child: Text('Firebase Extension'),
                      ),
                      DropdownMenuItem(
                        value: 'Custom API',
                        child: Text('Custom API'),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _provider = value ?? 'SMTP'),
                  ),
                  const SizedBox(height: 12),
                  if (_provider == 'SMTP') ...[
                    const _SmtpHostingerHint(),
                    _row([
                      _field(_smtpHost, 'SMTP Host'),
                      _field(
                        _smtpPort,
                        'SMTP Port',
                        keyboardType: TextInputType.number,
                      ),
                    ]),
                    _row([
                      _field(_smtpUsername, 'SMTP Username'),
                      _field(
                        _smtpPassword,
                        'SMTP Password / App Password',
                        obscureText: true,
                      ),
                    ]),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _smtpSsl,
                      onChanged: (value) => setState(() => _smtpSsl = value),
                      title: const Text('Use SSL / TLS'),
                    ),
                  ] else ...[
                    _row([
                      _field(_apiEndpoint, 'API Endpoint / Extension Path'),
                      _field(_apiKey, 'API Key / Token', obscureText: true),
                    ]),
                  ],
                ],
              ),
              _section(
                title: 'Email Trigger Instances',
                children: _triggerLabels.entries.map((entry) {
                  final key = entry.key;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SwitchListTile(
                        contentPadding:
                            const EdgeInsets.fromLTRB(12, 4, 8, 4),
                        value: _triggers[key] ?? false,
                        onChanged: (value) =>
                            setState(() => _triggers[key] = value),
                        title: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 10,
                          runSpacing: 4,
                          children: [
                            Text(entry.value),
                            TextButton.icon(
                              onPressed: () =>
                                  _openTemplateEditor(key, 'user'),
                              icon: const Icon(Icons.person_outline, size: 16),
                              label: const Text('User HTML template'),
                            ),
                            TextButton.icon(
                              onPressed: () =>
                                  _openTemplateEditor(key, 'admin'),
                              icon: const Icon(
                                Icons.admin_panel_settings_outlined,
                                size: 16,
                              ),
                              label: const Text('Admin HTML template'),
                            ),
                          ],
                        ),
                        subtitle: Text(_triggerDescriptions[key] ?? ''),
                      ),
                    ),
                  );
                }).toList(),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_isSaving ? 'Saving...' : 'Save Settings'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _contactUsTab() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _supportDoc.snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? const <String, dynamic>{};
        if (!_supportLoaded) {
          _supportLoaded = true;
          _contactEmail.text =
              _text(data['contactEmail'], 'neetapp@testprepkart.in');
          _whatsappNumber.text =
              _text(data['whatsappNumber'], '+15107069331');
          _websiteUrl.text =
              _text(data['websiteUrl'], 'https://www.testprepkart.com');
        }
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Contact Us',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'These values are consumed by the mobile Help & Support page, so contact details can change without an app release.',
            ),
            const SizedBox(height: 18),
            _section(
              title: 'Mobile Help & Support Cards',
              children: [
                _row([
                  _field(
                    _contactEmail,
                    'Support Email',
                    keyboardType: TextInputType.emailAddress,
                    requiredEmail: true,
                  ),
                  _field(_whatsappNumber, 'WhatsApp Number'),
                ]),
                _row([
                  _field(
                    _websiteUrl,
                    'Website URL',
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox.shrink(),
                ]),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _saveContactSettings,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save Contact Us'),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _faqTab() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _supportDoc.snapshots(),
      builder: (context, snapshot) {
        final faqs = _faqList(snapshot.data?.data()?['faqs']);
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FAQ Management',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'FAQs publish directly to the mobile Help & Support page.',
                        ),
                      ],
                    ),
                  ),
                  if (faqs.isEmpty) ...[
                    OutlinedButton.icon(
                      onPressed: _publishSampleFaqs,
                      icon: const Icon(Icons.auto_awesome_outlined),
                      label: const Text('Publish sample FAQs'),
                    ),
                    const SizedBox(width: 10),
                  ],
                  FilledButton.icon(
                    onPressed: () => _openFaqEditor(faqs),
                    icon: const Icon(Icons.add),
                    label: const Text('Add FAQ'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: faqs.isEmpty
                  ? const Center(
                      child: Text(
                        'No FAQs yet. Publish sample FAQs or add your own.',
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      itemCount: faqs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final faq = faqs[index];
                        return Card(
                          child: ListTile(
                            title: Text(_text(faq['question'], 'Question')),
                            subtitle: Text(
                              _text(faq['answer'], ''),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Wrap(
                              spacing: 4,
                              children: [
                                IconButton(
                                  tooltip: 'Edit',
                                  onPressed: () =>
                                      _openFaqEditor(faqs, index: index),
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                                IconButton(
                                  tooltip: 'Delete',
                                  onPressed: () async {
                                    final next = [...faqs]..removeAt(index);
                                    await _supportDoc.set({
                                      'faqs': next,
                                      'updatedAt':
                                          FieldValue.serverTimestamp(),
                                    }, SetOptions(merge: true));
                                  },
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            ),
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

  Widget _aboutLegalTab() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _aboutDoc.snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? const <String, dynamic>{};
        if (!_aboutLoaded) {
          _aboutLoaded = true;
          _aboutVersion.text = _text(data['version'], '1.0.0');
          _aboutBlurb.text = _text(
            data['blurb'],
            'TestprepKart NEET Prep helps NRI students and parents track NEET preparation, admissions, courses, counselling, and important updates.',
          );
          _aboutWebsiteUrl.text =
              _text(data['websiteUrl'], 'https://www.testprepkart.com');
          _privacyPolicyContent.text = _text(
            data['privacyPolicyContent'],
            _defaultPrivacyPolicyContent,
          );
          _termsOfServiceContent.text = _text(
            data['termsOfServiceContent'],
            _defaultTermsOfServiceContent,
          );
          _androidRatingUrl.text = _text(data['androidRatingUrl'], '');
          _iosRatingUrl.text = _text(data['iosRatingUrl'], '');
        }
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'About App & Legal Pages',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'These fields publish directly to Profile > About NEET Prep in the mobile app. Privacy Policy and Terms open as in-app pages.',
            ),
            const SizedBox(height: 18),
            _section(
              title: 'About NEET Prep',
              children: [
                _row([
                  _field(_aboutVersion, 'App Version'),
                  _field(
                    _aboutWebsiteUrl,
                    'Official Website URL',
                    keyboardType: TextInputType.url,
                  ),
                ]),
                _field(
                  _aboutBlurb,
                  'About Page Description',
                  maxLines: 4,
                ),
              ],
            ),
            _section(
              title: 'Legal Content',
              children: [
                _field(
                  _privacyPolicyContent,
                  'Privacy Policy Content',
                  maxLines: 12,
                ),
                const SizedBox(height: 14),
                _field(
                  _termsOfServiceContent,
                  'Terms of Service Content',
                  maxLines: 12,
                ),
              ],
            ),
            _section(
              title: 'Rate Our App Links',
              children: [
                _row([
                  _field(
                    _androidRatingUrl,
                    'Android Play Store Rating URL',
                    keyboardType: TextInputType.url,
                  ),
                  _field(
                    _iosRatingUrl,
                    'iPhone App Store Rating URL',
                    keyboardType: TextInputType.url,
                  ),
                ]),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _saveAboutLegalSettings,
                icon: const Icon(Icons.publish_outlined),
                label: const Text('Publish About & Legal'),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _contentLibraryTab() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _contentLibraryDoc.snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? const <String, dynamic>{};
        if (!_contentLibLoaded) {
          _contentLibLoaded = true;
          _contentGatingEnabled = data['gatingEnabled'] != false;
          _previewFraction.text =
              (data['previewVisibleFraction'] ?? 0.38).toString();
          _freeUnitIndexMax.text =
              (data['freeUnitIndexMax'] ?? 3).toString();
          _freeSiblingIndexMax.text =
              (data['freeSiblingIndexMax'] ?? 3).toString();
          final free =
              data['alwaysFreeNodeIds'] ?? data['freeFullAccessNodeIds'];
          final locked = data['alwaysLockedNodeIds'] ?? data['lockedNodeIds'];
          if (free is List) {
            _alwaysFreeNodeIds.text =
                free.map((e) => e?.toString() ?? '').join(', ');
          }
          if (locked is List) {
            _alwaysLockedNodeIds.text =
                locked.map((e) => e?.toString() ?? '').join(', ');
          }
        }
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Content Library access',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Controls free vs premium for the mobile Content Library: tier defaults, locked reading pages (blur + CTA), and per-node overrides. Stored at cms_content_library/main. Operations can also set per-node Auto / Lock / Free toggles on Content Library → Imported Hierarchy (same lists below).',
            ),
            const SizedBox(height: 18),
            Card(
              margin: const EdgeInsets.only(bottom: 18),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Enable paywall / gating',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Switch(
                          value: _contentGatingEnabled,
                          onChanged: (v) =>
                              setState(() => _contentGatingEnabled = v),
                        ),
                        Text(_contentGatingEnabled ? 'On' : 'Off'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'When off, all signed-in users see full content (same as premium). Guest mode follows app fixtures.',
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ),
            _section(
              title: 'Tier defaults',
              children: [
                _row([
                  _field(
                    _previewFraction,
                    'Preview height when locked (0.12–0.9)',
                    keyboardType: TextInputType.number,
                  ),
                  _field(
                    _freeUnitIndexMax,
                    'Free unit index max (units with index ≤ this are listed)',
                    keyboardType: TextInputType.number,
                  ),
                ]),
                _field(
                  _freeSiblingIndexMax,
                  'Free sibling slots (first N indices under each parent)',
                  keyboardType: TextInputType.number,
                ),
                const Text(
                  'Defaults match the previous app behavior: units 1–3 and the first three chapters/topics under a free unit.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
            _section(
              title: 'Node overrides',
              children: [
                _field(
                  _alwaysFreeNodeIds,
                  'Always-unlocked node IDs (comma-separated)',
                  maxLines: 2,
                ),
                const SizedBox(height: 14),
                _field(
                  _alwaysLockedNodeIds,
                  'Always-locked node IDs for non-premium (comma-separated)',
                  maxLines: 2,
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _saveContentLibrarySettings,
                icon: const Icon(Icons.publish_outlined),
                label: const Text('Publish Content Library rules'),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveContentLibrarySettings() async {
    final user = FirebaseAuth.instance.currentUser;
    final frac =
        double.tryParse(_previewFraction.text.trim()) ?? 0.38;
    await _contentLibraryDoc.set({
      'gatingEnabled': _contentGatingEnabled,
      'previewVisibleFraction': frac.clamp(0.12, 0.9),
      'freeUnitIndexMax': int.tryParse(_freeUnitIndexMax.text.trim()) ?? 3,
      'freeSiblingIndexMax':
          int.tryParse(_freeSiblingIndexMax.text.trim()) ?? 3,
      'alwaysFreeNodeIds': _splitCsv(_alwaysFreeNodeIds.text),
      'alwaysLockedNodeIds': _splitCsv(_alwaysLockedNodeIds.text),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': user?.email ?? user?.uid ?? 'unknown',
    }, SetOptions(merge: true));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Content Library rules published.'),
        ),
      );
    }
  }

  Widget _section({required String title, required List<Widget> children}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 18),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _row(List<Widget> children) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 720) {
          return Column(
            children: children
                .map(
                  (child) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: child,
                  ),
                )
                .toList(),
          );
        }
        return Row(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              Expanded(child: children[i]),
              if (i != children.length - 1) const SizedBox(width: 14),
            ],
          ],
        );
      },
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    bool obscureText = false,
    bool requiredEmail = false,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: maxLines == 1 && obscureText,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (requiredEmail && text.isEmpty) return 'Required';
        if (text.isNotEmpty &&
            keyboardType == TextInputType.emailAddress &&
            !text.contains('@')) {
          return 'Enter a valid email';
        }
        return null;
      },
    );
  }

  void applyHostingerSmtpPreset() {
    setState(() {
      _provider = 'SMTP';
      _smtpHost.text = 'smtp.hostinger.com';
      _smtpPort.text = '465';
      _smtpSsl = true;
      if (_smtpUsername.text.trim().isEmpty) {
        _smtpUsername.text = 'neetapp@testprepkart.in';
      }
      if (_fromEmail.text.trim().isEmpty) {
        _fromEmail.text = 'neetapp@testprepkart.in';
      }
      if (_replyToEmail.text.trim().isEmpty) {
        _replyToEmail.text = 'neetapp@testprepkart.in';
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Hostinger SMTP defaults applied. Enter your mailbox password and Save.',
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);
    final user = FirebaseAuth.instance.currentUser;
    final payload = {
      'masterEnabled': _masterEnabled,
      'provider': _provider,
      'senderName': _senderName.text.trim(),
      'fromEmail': _fromEmail.text.trim(),
      'replyToEmail': _replyToEmail.text.trim(),
      'adminRecipients': _splitCsv(_adminRecipients.text),
      'smtp': {
        'host': _smtpHost.text.trim(),
        'port': int.tryParse(_smtpPort.text.trim()) ?? 587,
        'username': _smtpUsername.text.trim(),
        'password': _smtpPassword.text,
        'useSsl': _smtpSsl,
      },
      'api': {
        'endpoint': _apiEndpoint.text.trim(),
        'apiKey': _apiKey.text,
      },
      'relayUrl': _text(
        _relayUrl.text,
        AdminEmailConfig.defaultRelayUrl,
      ),
      'triggers': _triggers,
      'templates': _templates,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': user?.email ?? user?.uid ?? 'unknown',
    };
    try {
      await _doc.set(payload, SetOptions(merge: true));
      AdminEmailDispatcher.instance.invalidateSettingsCache();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email settings saved.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save settings: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _openTemplateEditor(String triggerKey, String audience) async {
    final triggerTemplates = _map(_templates[triggerKey]);
    final template = _map(triggerTemplates[audience]);
    final subject = TextEditingController(
      text: _text(
        template['subject'],
        _defaultSubject(triggerKey, audience),
      ),
    );
    final html = TextEditingController(
      text: _text(
        template['html'],
        _defaultHtml(triggerKey, audience),
      ),
    );
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            '${audience == 'user' ? 'User' : 'Admin'} template - ${_triggerLabels[triggerKey]}',
          ),
          content: SizedBox(
            width: 860,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: subject,
                    decoration: const InputDecoration(
                      labelText: 'Email Subject',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: html,
                    minLines: 18,
                    maxLines: 28,
                    decoration: const InputDecoration(
                      alignLabelWithHint: true,
                      labelText: 'HTML Body',
                      helperText:
                          'Allowed placeholders: {userName}, {studentName}, {courseName}, {sessionDate}, {sessionTime}, {updateTitle}, {messageTopic}, {collegeName}, {appName}, {adminNotes}',
                      border: OutlineInputBorder(),
                    ),
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            OutlinedButton(
              onPressed: () {
                html.text = _defaultHtml(triggerKey, audience);
                subject.text = _defaultSubject(triggerKey, audience);
              },
              child: const Text('Reset default'),
            ),
            AdminDialogSaveActions(
              dialogContext: dialogContext,
              showCancel: false,
              saveLabel: 'Save',
              savedMessage: 'Email template saved.',
              onSave: () async {
                final subjectText = subject.text.trim();
                final htmlText = html.text.trim();
                if (subjectText.isEmpty || htmlText.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Subject and HTML body are required.'),
                    ),
                  );
                  return false;
                }
                setState(() {
                  final updatedTrigger = _map(_templates[triggerKey]);
                  updatedTrigger[audience] = {
                    'subject': subjectText,
                    'html': htmlText,
                    'updatedAtLocal': DateTime.now().toIso8601String(),
                  };
                  _templates = {
                    ..._templates,
                    triggerKey: updatedTrigger,
                  };
                });
                await _doc.set({
                  'templates': _templates,
                  'updatedAt': FieldValue.serverTimestamp(),
                  'updatedBy': FirebaseAuth.instance.currentUser?.email ??
                      FirebaseAuth.instance.currentUser?.uid ??
                      'unknown',
                }, SetOptions(merge: true));
                return true;
              },
            ),
          ],
        );
      },
    );
    subject.dispose();
    html.dispose();
  }

  Future<void> _saveAboutLegalSettings() async {
    await _aboutDoc.set({
      'version': _text(_aboutVersion.text, '1.0.0'),
      'blurb': _aboutBlurb.text.trim(),
      'websiteUrl': _text(
        _aboutWebsiteUrl.text,
        'https://www.testprepkart.com',
      ),
      'privacyPolicyContent': _privacyPolicyContent.text.trim(),
      'termsOfServiceContent': _termsOfServiceContent.text.trim(),
      'androidRatingUrl': _androidRatingUrl.text.trim(),
      'iosRatingUrl': _iosRatingUrl.text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': FirebaseAuth.instance.currentUser?.email ??
          FirebaseAuth.instance.currentUser?.uid ??
          'unknown',
    }, SetOptions(merge: true));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('About & Legal settings published.')),
      );
    }
  }

  Future<void> _saveContactSettings() async {
    final email = _contactEmail.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid support email.')),
      );
      return;
    }
    await _supportDoc.set({
      'contactEmail': email,
      'whatsappNumber': _whatsappNumber.text.trim(),
      'websiteUrl': _websiteUrl.text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': FirebaseAuth.instance.currentUser?.email ??
          FirebaseAuth.instance.currentUser?.uid ??
          'unknown',
    }, SetOptions(merge: true));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contact Us settings saved.')),
      );
    }
  }

  Future<void> _publishSampleFaqs() async {
    await _supportDoc.set({
      'faqs': _sampleFaqs,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': FirebaseAuth.instance.currentUser?.email ??
          FirebaseAuth.instance.currentUser?.uid ??
          'unknown',
    }, SetOptions(merge: true));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sample FAQs published.')),
      );
    }
  }

  Future<void> _openFaqEditor(
    List<Map<String, dynamic>> faqs, {
    int? index,
  }) async {
    final existing = index == null ? const <String, dynamic>{} : faqs[index];
    final question = TextEditingController(
      text: _text(existing['question'], ''),
    );
    final answer = TextEditingController(
      text: _text(existing['answer'], ''),
    );
    final category = TextEditingController(
      text: _text(existing['category'], 'General'),
    );
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(index == null ? 'Add FAQ' : 'Edit FAQ'),
        content: SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: question,
                decoration: const InputDecoration(labelText: 'Question'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: answer,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Answer',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: category,
                decoration: const InputDecoration(labelText: 'Category'),
              ),
            ],
          ),
        ),
        actions: [
          AdminDialogSaveActions(
            dialogContext: dialogContext,
            saveLabel: 'Save',
            savedMessage: 'FAQ saved.',
            onSave: () async {
              final q = question.text.trim();
              final a = answer.text.trim();
              if (q.isEmpty || a.isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text('Question and answer are required.'),
                  ),
                );
                return false;
              }
              final next = [...faqs];
              final item = {
                'question': q,
                'answer': a,
                'category': _text(category.text.trim(), 'General'),
              };
              if (index == null) {
                next.add(item);
              } else {
                next[index] = item;
              }
              await _supportDoc.set({
                'faqs': next,
                'updatedAt': FieldValue.serverTimestamp(),
                'updatedBy': FirebaseAuth.instance.currentUser?.email ??
                    FirebaseAuth.instance.currentUser?.uid ??
                    'unknown',
              }, SetOptions(merge: true));
              return true;
            },
          ),
        ],
      ),
    );
    question.dispose();
    answer.dispose();
    category.dispose();
  }
}

const _defaultTriggers = {
  'userRegistered': true,
  'updatePublished': true,
  'breakingUpdate': true,
  'demoRequestCreated': true,
  'analysisSessionStatusChanged': true,
  'courseInquiryCreated': true,
  'courseDemoBooked': true,
  'messageReceived': true,
  'collegeAlertUpdate': true,
  'subscriptionPurchase': true,
  'accountDeletionRequested': true,
  'accountDeletionCompleted': true,
  'accountDeletionRejected': true,
};

const _providerOptions = {
  'SMTP',
  'SendGrid',
  'Firebase Extension',
  'Custom API',
};

const _triggerLabels = {
  'userRegistered': 'New app user registered (welcome email)',
  'updatePublished': 'NEET Pulse update published',
  'breakingUpdate': 'Breaking / urgent update published',
  'demoRequestCreated': 'Expected Score demo request created',
  'analysisSessionStatusChanged': 'Analysis session approved/rescheduled/cancelled',
  'courseInquiryCreated': 'Course inquiry received',
  'courseDemoBooked': 'Course demo booked',
  'messageReceived': 'New user message received',
  'collegeAlertUpdate': 'College fee/cutoff alert update',
  'subscriptionPurchase': 'Subscription purchase / upgrade',
  'accountDeletionRequested': 'Account deletion requested (user + admin alert)',
  'accountDeletionCompleted': 'Account deletion completed',
  'accountDeletionRejected': 'Account deletion request rejected / cancelled',
};

const _triggerDescriptions = {
  'userRegistered':
      'Welcome email to the user and alert to admin when a new users/ doc appears (admin app must be open).',
  'updatePublished': 'Email users subscribed to the update category.',
  'breakingUpdate': 'Email all matching users for high-priority notices.',
  'demoRequestCreated': 'Email admin recipients when a parent books analysis.',
  'analysisSessionStatusChanged': 'Email the user when admin changes session status.',
  'courseInquiryCreated': 'Email admin recipients for new course inquiries.',
  'courseDemoBooked': 'Email admin recipients and optionally the user.',
  'messageReceived': 'Email admin recipients for unread support messages.',
  'collegeAlertUpdate': 'Email users tracking the affected college.',
  'subscriptionPurchase': 'Email receipt/confirmation after upgrade.',
  'accountDeletionRequested':
      'User confirmation + admin alert when a deletion request is recorded (admin panel should be open, or backfill on next login).',
  'accountDeletionCompleted':
      'Email user when admin sets status to Completed (after manual deletion in Firebase).',
  'accountDeletionRejected':
      'Email user when admin sets status to Rejected (request cancelled).',
};

const _sampleFaqs = [
  {
    'question': 'How can I contact TestprepKart support?',
    'answer':
        'Use the Email or WhatsApp options on this Help & Support page. Our academic support team will respond as soon as possible.',
    'category': 'Support',
  },
  {
    'question': 'Can NRI parents use the app from outside India?',
    'answer':
        'Yes. The app is designed for students and parents in India, the US, UAE, Saudi Arabia, Qatar, Kuwait, Bahrain, and Oman.',
    'category': 'NRI Parents',
  },
  {
    'question': 'Where can I see NEET updates and deadlines?',
    'answer':
        'Open NEET Pulse from the home page to view exam updates, deadlines, admission reminders, and important notices.',
    'category': 'Updates',
  },
  {
    'question': 'How do I request course guidance?',
    'answer':
        'Open Courses, choose a program, and tap Inquire or Book Demo. Our TestprepKart academic counselor will follow up.',
    'category': 'Courses',
  },
];

const _defaultPrivacyPolicyContent = '''
Privacy Policy

TestprepKart NEET Prep collects only the information needed to provide app access, counselling support, course inquiries, notifications, and learning progress features.

Information We Use
- Account details such as name, email, phone number, class, country, and student profile.
- App activity such as saved colleges, alerts, course inquiries, demo bookings, bookmarks, and support messages.
- Device notification tokens when you enable phone notifications.

How We Use Information
- To provide NEET preparation, admission guidance, support responses, reminders, and app notifications.
- To improve app reliability and personalize the student or parent experience.
- To contact users when they submit an inquiry, demo request, support message, or opt in to updates.

We do not sell personal data. You can edit and publish this policy from Admin Settings.
''';

const _defaultTermsOfServiceContent = '''
Terms of Service

By using TestprepKart NEET Prep, you agree to use the app for lawful educational and admission-support purposes.

User Responsibilities
- Keep your login details secure.
- Provide accurate profile, contact, and student information.
- Verify official admission, counselling, fee, and deadline information from the relevant authorities before making final decisions.

Service Notes
- App content, college data, course information, and alerts are provided for guidance and may change.
- Paid services, demo bookings, and inquiries are subject to TestprepKart policies communicated at the time of purchase or enrollment.

You can edit and publish these terms from Admin Settings.
''';

List<Map<String, dynamic>> _faqList(Object? raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

Map<String, dynamic> _map(Object? raw) =>
    raw is Map ? Map<String, dynamic>.from(raw) : {};

String _text(Object? raw, String fallback) {
  final text = raw?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String _listText(Object? raw) {
  if (raw is List) return raw.map((item) => item.toString()).join(', ');
  return raw?.toString() ?? '';
}

List<String> _splitCsv(String raw) => raw
    .split(',')
    .map((item) => item.trim())
    .where((item) => item.isNotEmpty)
    .toList();

String _defaultSubject(String triggerKey, String audience) {
  final isAdmin = audience == 'admin';
  switch (triggerKey) {
    case 'updatePublished':
      return isAdmin
          ? 'NEET Pulse update published: {updateTitle}'
          : '{updateTitle}';
    case 'breakingUpdate':
      return isAdmin
          ? 'Breaking NEET alert sent: {updateTitle}'
          : 'Important NEET update: {updateTitle}';
    case 'demoRequestCreated':
      return isAdmin
          ? 'New expected score demo request from {studentName}'
          : 'We received your demo request';
    case 'analysisSessionStatusChanged':
      return isAdmin
          ? 'Analysis session status changed for {studentName}'
          : 'Your analysis session is {status}';
    case 'courseInquiryCreated':
      return isAdmin
          ? 'New course inquiry: {courseName}'
          : 'Thanks for contacting TestprepKart';
    case 'courseDemoBooked':
      return isAdmin
          ? 'New course demo booking: {courseName}'
          : 'Your course demo request is confirmed';
    case 'messageReceived':
      return isAdmin
          ? 'New user message: {messageTopic}'
          : 'We received your message';
    case 'collegeAlertUpdate':
      return isAdmin
          ? 'College alert update sent: {collegeName}'
          : 'Update for {collegeName}';
    case 'subscriptionPurchase':
      return isAdmin
          ? 'Subscription purchase by {userName}'
          : 'Your TestprepKart subscription is active';
    default:
      return isAdmin
          ? 'Admin notification from {appName}'
          : 'Notification from {appName}';
  }
}

String _defaultHtml(String triggerKey, String audience) {
  final isAdmin = audience == 'admin';
  final greeting = isAdmin ? 'Hello Admin,' : 'Hello {userName},';
  final ctaLabel = isAdmin ? 'Open Admin Panel' : 'Open TestprepKart';
  final body = _defaultTemplateBody(triggerKey, audience);

  return '''
<!doctype html>
<html>
  <body style="margin:0;background:#f6f7fb;font-family:Arial,Helvetica,sans-serif;color:#111827;">
    <table width="100%" cellpadding="0" cellspacing="0" role="presentation" style="background:#f6f7fb;padding:24px 0;">
      <tr>
        <td align="center">
          <table width="600" cellpadding="0" cellspacing="0" role="presentation" style="max-width:600px;width:100%;background:#ffffff;border-radius:16px;overflow:hidden;border:1px solid #e5e7eb;">
            <tr>
              <td style="background:#4f46e5;padding:18px 24px;color:#ffffff;font-size:20px;font-weight:700;">
                {appName}
              </td>
            </tr>
            <tr>
              <td style="padding:28px 24px;">
                <p style="margin:0 0 16px;font-size:16px;line-height:1.5;">$greeting</p>
                $body
                <p style="margin:24px 0 0;">
                  <a href="{actionUrl}" style="display:inline-block;background:#4f46e5;color:#ffffff;text-decoration:none;padding:12px 18px;border-radius:10px;font-size:14px;font-weight:700;">$ctaLabel</a>
                </p>
              </td>
            </tr>
            <tr>
              <td style="padding:16px 24px;background:#f9fafb;color:#6b7280;font-size:12px;line-height:1.5;">
                This email was sent by {appName}. If you were not expecting this message, please contact support.
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
</html>
''';
}

String _defaultTemplateBody(String triggerKey, String audience) {
  final isAdmin = audience == 'admin';
  switch (triggerKey) {
    case 'updatePublished':
      return isAdmin
          ? '<p style="margin:0 0 12px;font-size:15px;line-height:1.6;">A NEET Pulse update has been published.</p><p style="margin:0;font-size:15px;line-height:1.6;"><strong>Update:</strong> {updateTitle}</p>'
          : '<p style="margin:0 0 12px;font-size:15px;line-height:1.6;">A new NEET Pulse update is available for you.</p><p style="margin:0;font-size:15px;line-height:1.6;"><strong>{updateTitle}</strong></p>';
    case 'breakingUpdate':
      return isAdmin
          ? '<p style="margin:0 0 12px;font-size:15px;line-height:1.6;">A breaking or urgent NEET update was sent.</p><p style="margin:0;font-size:15px;line-height:1.6;"><strong>Update:</strong> {updateTitle}</p>'
          : '<p style="margin:0 0 12px;font-size:15px;line-height:1.6;">There is an important NEET update that may need your attention.</p><p style="margin:0;font-size:15px;line-height:1.6;"><strong>{updateTitle}</strong></p>';
    case 'demoRequestCreated':
      return isAdmin
          ? '<p style="margin:0 0 12px;font-size:15px;line-height:1.6;">A new expected score demo request has been submitted.</p><p style="margin:0;font-size:15px;line-height:1.6;"><strong>Student:</strong> {studentName}<br><strong>Email:</strong> {email}</p>'
          : '<p style="margin:0 0 12px;font-size:15px;line-height:1.6;">Thanks for requesting an expected score demo. Our team will review the details and contact you soon.</p>';
    case 'analysisSessionStatusChanged':
      return isAdmin
          ? '<p style="margin:0 0 12px;font-size:15px;line-height:1.6;">An analysis session status was updated.</p><p style="margin:0;font-size:15px;line-height:1.6;"><strong>Student:</strong> {studentName}<br><strong>Status:</strong> {status}<br><strong>Schedule:</strong> {sessionDate} {sessionTime}</p>'
          : '<p style="margin:0 0 12px;font-size:15px;line-height:1.6;">Your analysis session status has been updated.</p><p style="margin:0;font-size:15px;line-height:1.6;"><strong>Status:</strong> {status}<br><strong>Schedule:</strong> {sessionDate} {sessionTime}</p>';
    case 'courseInquiryCreated':
      return isAdmin
          ? '<p style="margin:0 0 12px;font-size:15px;line-height:1.6;">A new course inquiry has arrived.</p><p style="margin:0;font-size:15px;line-height:1.6;"><strong>Course:</strong> {courseName}<br><strong>Student:</strong> {studentName}<br><strong>Email:</strong> {email}</p>'
          : '<p style="margin:0 0 12px;font-size:15px;line-height:1.6;">Thanks for connecting with the TestprepKart preparation team. We have received your query and our academic counselor will soon get in touch with you.</p><p style="margin:0;font-size:15px;line-height:1.6;"><strong>Course:</strong> {courseName}</p>';
    case 'courseDemoBooked':
      return isAdmin
          ? '<p style="margin:0 0 12px;font-size:15px;line-height:1.6;">A new course demo booking has been created.</p><p style="margin:0;font-size:15px;line-height:1.6;"><strong>Course:</strong> {courseName}<br><strong>Student:</strong> {studentName}<br><strong>Email:</strong> {email}</p>'
          : '<p style="margin:0 0 12px;font-size:15px;line-height:1.6;">Your free course demo request has been received. Our counselor will share the next steps shortly.</p><p style="margin:0;font-size:15px;line-height:1.6;"><strong>Course:</strong> {courseName}</p>';
    case 'messageReceived':
      return isAdmin
          ? '<p style="margin:0 0 12px;font-size:15px;line-height:1.6;">A user sent a new message.</p><p style="margin:0;font-size:15px;line-height:1.6;"><strong>Topic:</strong> {messageTopic}<br><strong>Email:</strong> {email}</p>'
          : '<p style="margin:0 0 12px;font-size:15px;line-height:1.6;">We received your message. The TestprepKart team will respond as soon as possible.</p><p style="margin:0;font-size:15px;line-height:1.6;"><strong>Topic:</strong> {messageTopic}</p>';
    case 'collegeAlertUpdate':
      return isAdmin
          ? '<p style="margin:0 0 12px;font-size:15px;line-height:1.6;">A college fee or cutoff alert update was sent.</p><p style="margin:0;font-size:15px;line-height:1.6;"><strong>College:</strong> {collegeName}</p>'
          : '<p style="margin:0 0 12px;font-size:15px;line-height:1.6;">There is an update for a college you are tracking.</p><p style="margin:0;font-size:15px;line-height:1.6;"><strong>College:</strong> {collegeName}</p>';
    case 'subscriptionPurchase':
      return isAdmin
          ? '<p style="margin:0 0 12px;font-size:15px;line-height:1.6;">A subscription purchase or upgrade has been completed.</p><p style="margin:0;font-size:15px;line-height:1.6;"><strong>User:</strong> {userName}<br><strong>Amount:</strong> {amount}</p>'
          : '<p style="margin:0 0 12px;font-size:15px;line-height:1.6;">Your TestprepKart subscription is now active. Thank you for upgrading.</p><p style="margin:0;font-size:15px;line-height:1.6;"><strong>Amount:</strong> {amount}</p>';
    default:
      return isAdmin
          ? '<p style="margin:0;font-size:15px;line-height:1.6;">A new admin notification is available.</p>'
          : '<p style="margin:0;font-size:15px;line-height:1.6;">You have a new notification from TestprepKart.</p>';
  }
}

/// Explains Hostinger (and similar) mailbox setup: SMTP sends mail; IMAP is not used here.
class _SmtpHostingerHint extends StatelessWidget {
  const _SmtpHostingerHint();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: const Color(0xFFE8F4FD),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: Colors.blue.shade800,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Hostinger / mailbox SMTP (sending only)',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Your Hostinger guide shows IMAP and SMTP. This admin panel only sends email, '
                'so choose provider SMTP and use the outgoing server — not IMAP.\n\n'
                'Suggested values:\n'
                '• SMTP Host: smtp.hostinger.com\n'
                '• Port: 465 (SSL on) or 587 (SSL/TLS on)\n'
                '• Username: full address (e.g. neetapp@testprepkart.in)\n'
                '• From Email: same mailbox address\n'
                '• Password: mailbox password from Hostinger\n\n'
                'IMAP (imap.hostinger.com) is only for reading mail in Outlook/Gmail — ignore it here.',
                style: TextStyle(fontSize: 12.5, height: 1.45),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  final state = context.findAncestorStateOfType<_SettingsPageState>();
                  state?.applyHostingerSmtpPreset();
                },
                icon: const Icon(Icons.auto_fix_high_outlined, size: 18),
                label: const Text('Fill Hostinger SMTP defaults'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
