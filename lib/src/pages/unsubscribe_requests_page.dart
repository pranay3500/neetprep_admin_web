import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../services/account_deletion_request_service.dart';
import '../services/firestore_db.dart';

/// Admin panel: review public account-deletion requests from /unsubscribe.
class UnsubscribeRequestsPage extends StatelessWidget {
  const UnsubscribeRequestsPage({super.key});

  static const _statuses = [
    'New',
    'In Progress',
    'Completed',
    'Rejected',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Requests from www.testprepkart.com/unsubscribe. Deletion is manual: '
            'Firebase Authentication (remove user) + Firestore users/{uid} and related data. '
            'Mark Completed only after deletion; Rejected cancels the request. '
            'Emails are sent to the user on request (when admin is open), Completed, and Rejected.',
            style: GoogleFonts.poppins(
              fontSize: 13,
              height: 1.45,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirestoreDb.instance
                  .collection(AccountDeletionRequestService.collection)
                  .limit(300)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Failed to load: ${snapshot.error}'),
                  );
                }
                final docs = List<
                        QueryDocumentSnapshot<Map<String, dynamic>>>.from(
                  snapshot.data?.docs ?? const [],
                )..sort(
                    (a, b) =>
                        _createdAt(b.data()).compareTo(_createdAt(a.data())),
                  );
                if (docs.isEmpty) {
                  return const Center(child: Text('No requests yet.'));
                }
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      primary: false,
                      child: DataTable(
                        columnSpacing: 20,
                        horizontalMargin: 16,
                        headingRowHeight: 44,
                        dataRowMinHeight: 48,
                        dataRowMaxHeight: 72,
                        columns: const [
                          DataColumn(
                            label: SizedBox(
                              width: 168,
                              child: Text('Date'),
                            ),
                          ),
                          DataColumn(label: Text('Email')),
                          DataColumn(label: Text('Source')),
                          DataColumn(label: Text('Status')),
                        ],
                        rows: docs.map((doc) {
                          final data = doc.data();
                          final status =
                              _text(data['status'], 'New');
                          final selected = _statuses.contains(status)
                              ? status
                              : 'New';
                          final unread = data['isRead'] != true;
                          return DataRow(
                            cells: [
                              DataCell(
                                SizedBox(
                                  width: 168,
                                  child: InkWell(
                                    onTap: () => AccountDeletionRequestService
                                        .markRead(doc.id),
                                    child: Row(
                                      children: [
                                        if (unread)
                                          const Padding(
                                            padding: EdgeInsets.only(right: 6),
                                            child: CircleAvatar(
                                              radius: 4,
                                              backgroundColor: Color(0xFFE53935),
                                            ),
                                          ),
                                        Expanded(
                                          child: Text(
                                            _fmtTs(data),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                SelectableText(_text(data['email'], '-')),
                              ),
                              DataCell(
                                Text(_text(data['source'], '-')),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 140,
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      isDense: true,
                                      isExpanded: true,
                                      value: selected,
                                      items: _statuses
                                          .map(
                                            (s) => DropdownMenuItem(
                                              value: s,
                                              child: Text(s),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (v) {
                                        if (v == null) return;
                                        AccountDeletionRequestService
                                            .updateStatus(doc.id, v);
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
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

String _text(dynamic v, String fallback) {
  final s = v?.toString().trim();
  if (s == null || s.isEmpty) return fallback;
  return s;
}

String _fmtTs(Map<String, dynamic> data) {
  final c = data['createdAt'];
  if (c is Timestamp) {
    return DateFormat('dd MMM yyyy, h:mm a').format(c.toDate().toLocal());
  }
  final loc = data['createdAtLocal']?.toString();
  final p = loc != null ? DateTime.tryParse(loc) : null;
  if (p != null) {
    return DateFormat('dd MMM yyyy, h:mm a').format(p.toLocal());
  }
  return '-';
}

DateTime _createdAt(Map<String, dynamic> data) {
  final c = data['createdAt'];
  if (c is Timestamp) return c.toDate();
  final loc = data['createdAtLocal']?.toString();
  return DateTime.tryParse(loc ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
}
