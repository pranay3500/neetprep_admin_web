import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/firestore_db.dart';
import '../utils/country_iso_resolver.dart';

class MessagesPage extends StatelessWidget {
  const MessagesPage({super.key});

  CollectionReference<Map<String, dynamic>> get _threads =>
      FirestoreDb.instance.collection('threads');

  CollectionReference<Map<String, dynamic>> get _users =>
      FirestoreDb.instance.collection('users');

  String _formatDate(dynamic raw) {
    DateTime? date;
    if (raw is Timestamp) date = raw.toDate().toLocal();
    if (raw is DateTime) date = raw.toLocal();
    if (date == null) return '-';
    return DateFormat('dd MMM yyyy, hh:mm a').format(date);
  }

  DateTime _dateFrom(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _displayUserName(
    Map<String, dynamic> thread,
    Map<String, dynamic>? user,
  ) {
    final candidates = [
      thread['userName'],
      user?['fullName'],
      user?['name'],
      user?['displayName'],
      user?['studentName'],
      user?['email'],
    ];
    for (final raw in candidates) {
      final value = raw?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return 'Unknown user';
  }

  String _country(Map<String, dynamic> thread, Map<String, dynamic>? user) {
    final candidates = [thread['country'], user?['country']];
    for (final raw in candidates) {
      final value = raw?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '-';
  }

  String _countryIso2(Map<String, dynamic> thread, Map<String, dynamic>? user) {
    return CountryIsoResolver.resolveIso2(
      storedIso2: (user?['countryIso2'] ??
              user?['countryISO2'] ??
              user?['country_code'] ??
              user?['countryCode2'])
          ?.toString(),
      countryName: _country(thread, user),
      dialCode: (user?['countryCode'] ?? user?['dialCode'] ?? '').toString(),
      phone: (user?['phone'] ?? '').toString(),
    );
  }

  String _flagEmojiFromIso2(String iso2) =>
      CountryIsoResolver.flagEmojiFromIso2(iso2);

  bool _isPaid(Map<String, dynamic> thread, Map<String, dynamic>? user) {
    return thread['isPremium'] == true || user?['isPremium'] == true;
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _sorted(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final list = docs.toList();
    list.sort((a, b) {
      final aData = a.data();
      final bData = b.data();
      final aUnread = aData['adminUnread'] == true;
      final bUnread = bData['adminUnread'] == true;
      if (aUnread != bUnread) return aUnread ? -1 : 1;
      return _dateFrom(
        bData['lastActivity'],
      ).compareTo(_dateFrom(aData['lastActivity']));
    });
    return list;
  }

  Future<void> _sendReply(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String text,
  ) async {
    final data = doc.data();
    final uid = data['userId']?.toString() ?? '';
    final admin = FirebaseAuth.instance.currentUser;
    final adminName = admin?.email ?? 'TestprepKart Admin';
    final threadRef = _threads.doc(doc.id);
    final batch = FirestoreDb.instance.batch();

    batch.set(threadRef.collection('messages').doc(), {
      'senderId': admin?.uid ?? 'admin',
      'senderName': adminName,
      'content': text,
      'timestamp': FieldValue.serverTimestamp(),
      'isMe': false,
      'isAdmin': true,
    });
    batch.set(threadRef, {
      'lastActivity': FieldValue.serverTimestamp(),
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageContent': text,
      'lastMessageSenderId': admin?.uid ?? 'admin',
      'adminUnread': false,
      'unreadCount': FieldValue.increment(1),
      'counselorMessageCount': FieldValue.increment(1),
      'status': 'Open',
    }, SetOptions(merge: true));

    if (uid.isNotEmpty) {
      batch.set(_users.doc(uid).collection('notifications').doc(), {
        'title': 'New message reply',
        'description': 'TestprepKart has replied to your message.',
        'longContent': text,
        'type': 'message',
        'isRead': false,
        'icon': 'message',
        'color': '#5E35B1',
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  Future<void> _markAsRead(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    if (data['adminUnread'] != true) return;

    try {
      await _threads.doc(doc.id).set(
        {'adminUnread': false},
        SetOptions(merge: true),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Marked as read.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not mark as read: $e')),
        );
      }
    }
  }

  void _openConversation(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String userName,
  ) {
    final reply = TextEditingController();
    var isSending = false;
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          insetPadding: const EdgeInsets.all(24),
          child: SizedBox(
            width: 760,
            height: 700,
            child: Column(
              children: [
                ListTile(
                  title: Text(
                    userName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(doc.data()['topic']?.toString() ?? '-'),
                  trailing: IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _threads
                        .doc(doc.id)
                        .collection('messages')
                        .orderBy('timestamp', descending: false)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final messages = snapshot.data?.docs ?? const [];
                      if (messages.isEmpty) {
                        return const Center(child: Text('No conversation yet.'));
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: messages.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final msg = messages[index].data();
                          final isAdmin =
                              msg['isAdmin'] == true ||
                              msg['isMe'] == false ||
                              msg['senderId'] == 'auto_reply';
                          final sender =
                              msg['senderName']?.toString() ??
                              (isAdmin ? 'Admin' : userName);
                          final content = msg['content']?.toString() ?? '';
                          return Align(
                            alignment: isAdmin
                                ? Alignment.centerLeft
                                : Alignment.centerRight,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 520),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: isAdmin
                                      ? const Color(0xFFF3E5F5)
                                      : const Color(0xFFE8F5E9),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        sender,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(content),
                                      const SizedBox(height: 6),
                                      Text(
                                        _formatDate(msg['timestamp']),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: reply,
                          minLines: 2,
                          maxLines: 5,
                          maxLength: 1000,
                          decoration: const InputDecoration(
                            labelText: 'Reply to this conversation',
                            border: OutlineInputBorder(),
                            counterText: '',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: isSending
                            ? null
                            : () async {
                                final text = reply.text.trim();
                                if (text.isEmpty) return;
                                setDialogState(() => isSending = true);
                                try {
                                  await _sendReply(doc, text);
                                  reply.clear();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Reply sent to user.'),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Could not send: $e'),
                                      ),
                                    );
                                  }
                                } finally {
                                  if (ctx.mounted) {
                                    setDialogState(() => isSending = false);
                                  }
                                }
                              },
                        icon: isSending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.reply_rounded),
                        label: Text(isSending ? 'Sending...' : 'Send Reply'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(reply.dispose);
  }

  Widget _table(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    Map<String, Map<String, dynamic>> users,
  ) {
    if (docs.isEmpty) {
      return const Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No messages found.'),
        ),
      );
    }

    return Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: double.infinity,
        child: Scrollbar(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 1220),
              child: DataTable(
                columnSpacing: 18,
                horizontalMargin: 16,
                columns: const [
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('User Name')),
                  DataColumn(label: Text('Country')),
                  DataColumn(label: Text('Topic')),
                  DataColumn(label: Text('Questions')),
                  DataColumn(label: Text('Action')),
                ],
                rows: docs.map((doc) {
                  final d = doc.data();
                  final uid = d['userId']?.toString() ?? '';
                  final user = users[uid];
                  final userName = _displayUserName(d, user);
                  final iso2 = _countryIso2(d, user);
                  final flag = _flagEmojiFromIso2(iso2);
                  final firstQuestion =
                      d['firstMessageContent']?.toString().trim() ?? '';
                  final lastMessage =
                      d['lastMessageContent']?.toString().trim() ?? '';
                  final question = firstQuestion.isNotEmpty
                      ? firstQuestion
                      : lastMessage;
                  final hasPending = d['adminUnread'] == true;
                  return DataRow(
                    color: WidgetStateProperty.resolveWith(
                      (_) => hasPending
                          ? const Color(0xFFFFF8E1)
                          : Colors.transparent,
                    ),
                    cells: [
                      DataCell(Text(_formatDate(d['lastActivity']))),
                      DataCell(
                        InkWell(
                          onTap: () =>
                              _openConversation(context, doc, userName),
                          child: SizedBox(
                            width: 180,
                            child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (flag.isNotEmpty)
                                Text(flag, style: const TextStyle(fontSize: 16))
                              else if (iso2.isNotEmpty)
                                const Icon(Icons.flag_outlined, size: 14),
                              if (flag.isNotEmpty || iso2.isNotEmpty)
                                const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  userName,
                                  style: const TextStyle(
                                    color: Color(0xFF5E35B1),
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 150,
                          child: Row(
                            children: [
                              if (flag.isNotEmpty)
                                Text(flag, style: const TextStyle(fontSize: 16)),
                              if (flag.isNotEmpty) const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _country(d, user),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 170,
                          child: Text(
                            d['topic']?.toString() ?? '-',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(
                        Tooltip(
                          message: question.isEmpty ? '-' : question,
                          waitDuration: const Duration(milliseconds: 250),
                          child: SizedBox(
                            width: 260,
                            child: Text(
                              question.isEmpty ? '-' : question,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'View and reply',
                              onPressed: () =>
                                  _openConversation(context, doc, userName),
                              icon: const Icon(Icons.visibility_rounded),
                            ),
                            IconButton(
                              tooltip: hasPending
                                  ? 'Mark as read'
                                  : 'Already read',
                              onPressed: hasPending
                                  ? () => _markAsRead(context, doc)
                                  : null,
                              icon: Icon(
                                Icons.mark_email_read_outlined,
                                color: hasPending
                                    ? const Color(0xFF5E35B1)
                                    : Colors.black26,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _threads.snapshots(),
      builder: (context, threadSnapshot) {
        if (threadSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final threadDocs = _sorted(threadSnapshot.data?.docs ?? const []);
        if (threadDocs.isEmpty) {
          return const Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No user messages found.'),
            ),
          );
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _users.snapshots(),
          builder: (context, userSnapshot) {
            final userDocs = userSnapshot.data?.docs ?? const [];
            final users = {for (final doc in userDocs) doc.id: doc.data()};
            final paid = threadDocs
                .where(
                  (doc) => _isPaid(doc.data(), users[doc.data()['userId']]),
                )
                .toList();
            final free = threadDocs
                .where(
                  (doc) => !_isPaid(doc.data(), users[doc.data()['userId']]),
                )
                .toList();

            return DefaultTabController(
              length: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Material(
                    child: TabBar(
                      tabs: [
                        Tab(text: 'Free User'),
                        Tab(text: 'Paid User'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: _table(context, free, users),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: _table(context, paid, users),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
