import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/firestore_db.dart';
import '../utils/country_iso_resolver.dart';

/// Opens a dialog to start a new admin → user conversation.
///
/// Returns `true` if a message was sent.
Future<bool> showAdminComposeUserMessageDialog(
  BuildContext context, {
  String? preselectedUserId,
  String? preselectedUserName,
  String? preselectedUserEmail,
  String? preselectedCountry,
  bool? preselectedIsPremium,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _AdminComposeUserMessageDialog(
      preselectedUserId: preselectedUserId,
      preselectedUserName: preselectedUserName,
      preselectedUserEmail: preselectedUserEmail,
      preselectedCountry: preselectedCountry,
      preselectedIsPremium: preselectedIsPremium,
    ),
  );
  return result == true;
}

class _AdminComposeUserMessageDialog extends StatefulWidget {
  const _AdminComposeUserMessageDialog({
    this.preselectedUserId,
    this.preselectedUserName,
    this.preselectedUserEmail,
    this.preselectedCountry,
    this.preselectedIsPremium,
  });

  final String? preselectedUserId;
  final String? preselectedUserName;
  final String? preselectedUserEmail;
  final String? preselectedCountry;
  final bool? preselectedIsPremium;

  @override
  State<_AdminComposeUserMessageDialog> createState() =>
      _AdminComposeUserMessageDialogState();
}

class _AdminComposeUserMessageDialogState
    extends State<_AdminComposeUserMessageDialog> {
  final _topic = TextEditingController();
  final _body = TextEditingController();
  final _search = TextEditingController();

  String? _selectedUserId;
  String _selectedUserName = '';
  String _selectedUserEmail = '';
  String _selectedCountry = '';
  bool _selectedIsPremium = false;
  bool _sending = false;
  String? _error;

  CollectionReference<Map<String, dynamic>> get _users =>
      FirestoreDb.instance.collection('users');
  CollectionReference<Map<String, dynamic>> get _threads =>
      FirestoreDb.instance.collection('threads');

  @override
  void initState() {
    super.initState();
    if (widget.preselectedUserId != null &&
        widget.preselectedUserId!.trim().isNotEmpty) {
      _selectedUserId = widget.preselectedUserId!.trim();
      _selectedUserName = (widget.preselectedUserName ?? '').trim();
      _selectedUserEmail = (widget.preselectedUserEmail ?? '').trim();
      _selectedCountry = (widget.preselectedCountry ?? '').trim();
      _selectedIsPremium = widget.preselectedIsPremium == true;
    }
  }

  @override
  void dispose() {
    _topic.dispose();
    _body.dispose();
    _search.dispose();
    super.dispose();
  }

  String _displayName(Map<String, dynamic> u) {
    for (final key in [
      'fullName',
      'name',
      'displayName',
      'studentName',
      'email',
    ]) {
      final v = u[key]?.toString().trim() ?? '';
      if (v.isNotEmpty) return v;
    }
    return 'Unknown user';
  }

  bool _matchesSearch(Map<String, dynamic> u, String q) {
    if (q.isEmpty) return true;
    final hay = [
      u['fullName'],
      u['name'],
      u['studentName'],
      u['email'],
      u['phone'],
      u['country'],
    ].map((e) => (e ?? '').toString().toLowerCase()).join(' ');
    return hay.contains(q);
  }

  Future<void> _send() async {
    final uid = _selectedUserId?.trim() ?? '';
    final topic = _topic.text.trim();
    final text = _body.text.trim();
    if (uid.isEmpty) {
      setState(() => _error = 'Please select a user.');
      return;
    }
    if (topic.isEmpty) {
      setState(() => _error = 'Please enter a topic.');
      return;
    }
    if (text.isEmpty) {
      setState(() => _error = 'Please enter a message.');
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      final admin = FirebaseAuth.instance.currentUser;
      final adminName = admin?.email ?? 'TestprepKart Admin';
      final threadRef = _threads.doc();
      final batch = FirestoreDb.instance.batch();

      batch.set(threadRef, {
        'userId': uid,
        'userName': _selectedUserName.isNotEmpty
            ? _selectedUserName
            : (_selectedUserEmail.isNotEmpty ? _selectedUserEmail : 'User'),
        'country': _selectedCountry,
        'isPremium': _selectedIsPremium,
        'topic': topic,
        'status': 'Open',
        'startedByAdmin': true,
        'adminUnread': false,
        'unreadCount': 1,
        'counselorMessageCount': 1,
        'userMessageCount': 0,
        'firstMessageContent': text,
        'lastMessageContent': text,
        'lastMessageSenderId': admin?.uid ?? 'admin',
        'createdAt': FieldValue.serverTimestamp(),
        'lastActivity': FieldValue.serverTimestamp(),
        'lastMessageAt': FieldValue.serverTimestamp(),
      });

      batch.set(threadRef.collection('messages').doc(), {
        'senderId': admin?.uid ?? 'admin',
        'senderName': adminName,
        'content': text,
        'timestamp': FieldValue.serverTimestamp(),
        'isMe': false,
        'isAdmin': true,
      });

      batch.set(_users.doc(uid).collection('notifications').doc(), {
        'title': 'New message from TestprepKart',
        'description': topic,
        'longContent': text,
        'type': 'message',
        'threadId': threadRef.id,
        'isRead': false,
        'icon': 'message',
        'color': '#5E35B1',
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = 'Could not send: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lockedUser = widget.preselectedUserId != null &&
        widget.preselectedUserId!.trim().isNotEmpty;

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: SizedBox(
        width: 640,
        height: lockedUser ? 520 : 680,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              title: const Text(
                'New message to user',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text(
                'Creates a new conversation. The user will see it in Messages and get a notification.',
              ),
              trailing: IconButton(
                onPressed: _sending ? null : () => Navigator.pop(context, false),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (lockedUser) ...[
                      InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'To',
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          [
                            if (_selectedUserName.isNotEmpty) _selectedUserName,
                            if (_selectedUserEmail.isNotEmpty)
                              _selectedUserEmail,
                          ].join(' · '),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ] else ...[
                      TextField(
                        controller: _search,
                        decoration: const InputDecoration(
                          labelText: 'Search users',
                          hintText: 'Name, email, phone, country…',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: _users.limit(500).snapshots(),
                          builder: (context, snap) {
                            if (!snap.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            final q = _search.text.trim().toLowerCase();
                            final docs = snap.data!.docs
                                .where((d) => _matchesSearch(d.data(), q))
                                .take(80)
                                .toList();
                            if (docs.isEmpty) {
                              return const Center(
                                child: Text('No matching users.'),
                              );
                            }
                            return ListView.separated(
                              itemCount: docs.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, i) {
                                final doc = docs[i];
                                final u = doc.data();
                                final name = _displayName(u);
                                final email = (u['email'] ?? '').toString();
                                final country =
                                    (u['country'] ?? '').toString();
                                final iso2 = CountryIsoResolver.resolveIso2(
                                  storedIso2: (u['countryIso2'] ?? '').toString(),
                                  countryName: country,
                                  dialCode:
                                      (u['countryCode'] ?? '').toString(),
                                  phone: (u['phone'] ?? '').toString(),
                                );
                                final flag =
                                    CountryIsoResolver.flagEmojiFromIso2(iso2);
                                final selected = _selectedUserId == doc.id;
                                return ListTile(
                                  selected: selected,
                                  leading: Text(
                                    flag.isNotEmpty ? flag : '🌐',
                                    style: const TextStyle(fontSize: 18),
                                  ),
                                  title: Text(name),
                                  subtitle: Text(
                                    [
                                      if (email.isNotEmpty) email,
                                      if (country.isNotEmpty) country,
                                    ].join(' · '),
                                  ),
                                  trailing: selected
                                      ? const Icon(
                                          Icons.check_circle,
                                          color: Color(0xFF5E35B1),
                                        )
                                      : null,
                                  onTap: () => setState(() {
                                    _selectedUserId = doc.id;
                                    _selectedUserName = name;
                                    _selectedUserEmail = email;
                                    _selectedCountry = country;
                                    _selectedIsPremium =
                                        u['isPremium'] == true;
                                    _error = null;
                                  }),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: _topic,
                      maxLength: 120,
                      decoration: const InputDecoration(
                        labelText: 'Topic',
                        border: OutlineInputBorder(),
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _body,
                      minLines: 3,
                      maxLines: 6,
                      maxLength: 2000,
                      decoration: const InputDecoration(
                        labelText: 'Message',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: const TextStyle(color: Color(0xFFC62828)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        _sending ? null : () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                    label: Text(_sending ? 'Sending…' : 'Send message'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
