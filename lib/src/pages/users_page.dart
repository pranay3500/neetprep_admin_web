import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../admin_auth_constants.dart';
import '../services/admin_auth_eligibility.dart';
import '../services/admin_session.dart';
import '../services/firestore_db.dart';
import '../utils/country_iso_resolver.dart';
import '../utils/csv_download_web.dart';
import '../widgets/responsive_layout.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  final _searchController = TextEditingController();
  String _query = '';
  _UserFilter _filter = _UserFilter.all;
  DateTime? _dateFrom;
  DateTime? _dateTo;

  CollectionReference<Map<String, dynamic>> get _users =>
      FirestoreDb.instance.collection('users');

  bool get _isOwner => AdminSession.isOwner;

  static const _compactIconConstraints = BoxConstraints(
    minWidth: 32,
    minHeight: 32,
  );

  Future<void> _patchUser(
    String userId, {
    required Map<String, dynamic> fields,
    required String successMessage,
  }) async {
    final admin = FirebaseAuth.instance.currentUser;
    await _users.doc(userId).set({
      ...fields,
      'updatedAt': FieldValue.serverTimestamp(),
      if (admin != null) 'updatedBy': admin.uid,
    }, SetOptions(merge: true));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(successMessage)));
  }

  Future<void> _grantModerator(String userId, String email) async {
    final admin = FirebaseAuth.instance.currentUser;
    final normalized = email.trim().toLowerCase();
    try {
      await AdminAuthEligibility.grantModeratorOnUid(
        uid: userId,
        email: normalized,
        grantedByEmail: admin?.email,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not save moderator access (check Firestore rules): $e',
          ),
        ),
      );
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Moderator granted.\n'
          'They must sign in at ${AdminAuthConstants.passwordResetContinueUrl} with email:\n'
          '$normalized\n'
          '(same password as the mobile app — not their UID).',
        ),
        duration: const Duration(seconds: 8),
      ),
    );
  }

  Future<void> _revokePanelAccess(String userId, String email) async {
    final admin = FirebaseAuth.instance.currentUser;
    await _patchUser(
      userId,
      fields: {
        'role': 'user',
        'panelAccessRevokedAt': FieldValue.serverTimestamp(),
        if (admin?.email != null) 'panelAccessRevokedBy': admin!.email,
      },
      successMessage:
          'Admin panel access revoked for $email. They can still use the mobile app.',
    );
  }

  Future<void> _setRole(String userId, String role) async {
    await _patchUser(
      userId,
      fields: {'role': role},
      successMessage: 'Role updated to $role',
    );
  }

  Future<void> _clearSubscriptionRequest(String userId) async {
    await _patchUser(
      userId,
      fields: {
        'subscriptionRequestPending': false,
        'subscriptionRequestHandledAt': FieldValue.serverTimestamp(),
      },
      successMessage: 'Subscription request marked as handled.',
    );
  }

  Future<void> _clearRegistrationUnread(String userId) async {
    await _patchUser(
      userId,
      fields: {
        'adminRegistrationUnread': false,
        'adminRegistrationSeenAt': FieldValue.serverTimestamp(),
      },
      successMessage: 'New registration marked as seen.',
    );
  }

  Future<void> _markAllNewRegistrationsSeen() async {
    try {
      final snap = await _users
          .where('adminRegistrationUnread', isEqualTo: true)
          .limit(200)
          .get();
      if (snap.docs.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No new registrations to mark.')),
        );
        return;
      }
      final batch = FirestoreDb.instance.batch();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {
          'adminRegistrationUnread': false,
          'adminRegistrationSeenAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Marked ${snap.docs.length} new registration(s) as seen.',
          ),
        ),
      );
    } catch (e) {
      debugPrint('[UsersPage] mark new registrations seen: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update registrations: $e')),
      );
    }
  }

  Future<void> _approveSubscriptionRequest(String userId, String email) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve paid subscription?'),
        content: Text(
          'Mark $email as a paid (premium) user and clear the pending request?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    await _patchUser(
      userId,
      fields: {
        'isPremium': true,
        'subscriptionRequestPending': false,
        'subscriptionRequestHandledAt': FieldValue.serverTimestamp(),
        'subscriptionApprovedAt': FieldValue.serverTimestamp(),
      },
      successMessage: 'Subscription approved for $email (premium enabled).',
    );
  }

  Future<void> _confirmResetSubscription(
    BuildContext context,
    String userId,
    String email,
    Map<String, dynamic> u,
  ) async {
    final isPremium = u['isPremium'] == true;
    final hasPending = u['subscriptionRequestPending'] == true;
    final expiry = u['subscriptionExpiry']?.toString() ?? '';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset subscription?'),
        content: Text(
          'Reset premium and subscription request state for $email?\n\n'
          'Current: ${isPremium ? 'Premium' : 'Free'}'
          '${hasPending ? ' · Request pending' : ''}'
          '${expiry.isNotEmpty ? '\nExpiry: $expiry' : ''}\n\n'
          'The user will be treated as a free user in the app after their next sync.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: const Text('Reset subscription'),
          ),
        ],
      ),
    );
    if (ok == true) await _resetSubscription(userId, email);
  }

  Future<void> _resetSubscription(String userId, String email) async {
    await _patchUser(
      userId,
      fields: {
        'isPremium': false,
        'subscriptionExpiry': FieldValue.delete(),
        'subscriptionRequestPending': false,
        'subscriptionRequestHandledAt': FieldValue.serverTimestamp(),
        'subscriptionResetAt': FieldValue.serverTimestamp(),
      },
      successMessage: 'Subscription reset for $email (free plan).',
    );
  }

  String _subscriptionStatusLabel(Map<String, dynamic> u) {
    if (u['subscriptionRequestPending'] == true) return 'Request pending';
    if (u['isPremium'] == true) return 'Premium';
    return 'Free';
  }

  Widget _subscriptionIconRow(String userId, Map<String, dynamic> u) {
    final pending = u['subscriptionRequestPending'] == true;
    final isPremium = u['isPremium'] == true;

    final IconData statusIcon;
    final Color statusColor;
    final String statusTooltip;
    if (pending) {
      statusIcon = Icons.mark_email_unread_rounded;
      statusColor = const Color(0xFFE65100);
      statusTooltip = _isOwner
          ? 'Premium requested — tap to approve and mark paid'
          : 'Premium subscription requested';
    } else if (isPremium) {
      statusIcon = Icons.workspace_premium_rounded;
      statusColor = const Color(0xFF2E7D32);
      statusTooltip = 'Premium (paid) user';
    } else {
      statusIcon = Icons.person_outline_rounded;
      statusColor = Colors.grey.shade700;
      statusTooltip = 'Free user';
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(statusIcon, color: statusColor, size: 22),
          tooltip: statusTooltip,
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: _compactIconConstraints,
          onPressed: pending && _isOwner
              ? () => _approveSubscriptionRequest(
                    userId,
                    (u['email'] ?? '').toString(),
                  )
              : null,
        ),
        if (pending && _isOwner)
          IconButton(
            icon: Icon(Icons.task_alt_rounded, color: Colors.grey.shade700, size: 20),
            tooltip: 'Mark request handled without changing subscription',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: _compactIconConstraints,
            onPressed: () => _clearSubscriptionRequest(userId),
          ),
        if (_isOwner)
          IconButton(
            icon: Icon(Icons.restart_alt_rounded, color: Colors.red.shade700, size: 20),
            tooltip: 'Reset subscription to free',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: _compactIconConstraints,
            onPressed: () => _confirmResetSubscription(
              context,
              userId,
              (u['email'] ?? '').toString(),
              u,
            ),
          ),
      ],
    );
  }

  Future<void> _confirmGrant(BuildContext context, String userId, String email) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Grant moderator access?'),
        content: Text(
          '$email will sign in at the admin website (not with a UID).\n\n'
          'Firebase user id for this row:\n$userId\n\n'
          'They must use the same email/password as the mobile app.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Grant')),
        ],
      ),
    );
    if (ok == true) await _grantModerator(userId, email);
  }

  Future<void> _confirmRevoke(BuildContext context, String userId, String email) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revoke admin panel access?'),
        content: Text(
          '$email will no longer be able to sign in to the admin website. Their mobile app account is unchanged.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
    if (ok == true) await _revokePanelAccess(userId, email);
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final initial = isFrom
        ? (_dateFrom ?? _dateTo ?? now)
        : (_dateTo ?? _dateFrom ?? now);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 1)),
      helpText: isFrom ? 'From date' : 'To date',
    );
    if (picked == null) return;
    setState(() {
      final day = DateTime(picked.year, picked.month, picked.day);
      if (isFrom) {
        _dateFrom = day;
        if (_dateTo != null && day.isAfter(_dateTo!)) {
          _dateTo = day;
        }
      } else {
        _dateTo = day;
        if (_dateFrom != null && day.isBefore(_dateFrom!)) {
          _dateFrom = day;
        }
      }
    });
  }

  void _clearDateFilters() => setState(() {
        _dateFrom = null;
        _dateTo = null;
      });

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  DateTime? _parseCreatedAt(dynamic value) {
    if (value is Timestamp) return value.toDate().toLocal();
    if (value is DateTime) return value.toLocal();
    if (value is String) return DateTime.tryParse(value)?.toLocal();
    return null;
  }

  String _fmtDateTable(dynamic value) {
    final date = _parseCreatedAt(value);
    if (date == null) return '-';
    return DateFormat('dd MMM yyyy').format(date);
  }

  String _fmtDateExport(dynamic value) {
    final date = _parseCreatedAt(value);
    if (date == null) return '';
    return DateFormat('yyyy-MM-dd HH:mm').format(date);
  }

  String _studentClass(Map<String, dynamic> u) {
    final grade =
        (u['currentGrade'] ?? u['grade'] ?? u['studentGrade'] ?? '').toString().trim();
    return grade.isEmpty ? '-' : grade;
  }

  String _countryIso2(Map<String, dynamic> u) {
    return CountryIsoResolver.resolveIso2(
      storedIso2: (u['countryIso2'] ??
              u['countryISO2'] ??
              u['country_code'] ??
              u['countryCode2'])
          ?.toString(),
      countryName: (u['country'] ?? '').toString(),
      dialCode: (u['countryCode'] ?? u['dialCode'] ?? '').toString(),
      phone: (u['phone'] ?? '').toString(),
    );
  }

  String _flagEmojiFromIso2(String iso2) =>
      CountryIsoResolver.flagEmojiFromIso2(iso2);

  bool _matchesSearch(Map<String, dynamic> u) {
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    final values = [
      u['fullName'],
      u['name'],
      u['email'],
      u['phone'],
      u['country'],
      u['state'],
      u['city'],
      u['visaType'],
      u['counsellingTrack'],
      u['currentGrade'],
      u['grade'],
    ].map((e) => e?.toString().toLowerCase() ?? '');
    return values.any((v) => v.contains(q));
  }

  bool _matchesFilter(Map<String, dynamic> u) {
    final role = (u['role'] ?? 'user').toString().toLowerCase();
    final panelActive = u['isActive'] != false && AdminSession.roleIsStaff(role);
    switch (_filter) {
      case _UserFilter.all:
        return true;
      case _UserFilter.appUsers:
        return !panelActive;
      case _UserFilter.panelAccess:
        return panelActive;
      case _UserFilter.subscriptionRequests:
        return u['subscriptionRequestPending'] == true;
      case _UserFilter.newRegistrations:
        return u['adminRegistrationUnread'] == true;
    }
  }

  bool _matchesDateRange(Map<String, dynamic> u) {
    if (_dateFrom == null && _dateTo == null) return true;
    final created = _parseCreatedAt(u['createdAt']);
    if (created == null) return false;
    final day = DateTime(created.year, created.month, created.day);
    if (_dateFrom != null && day.isBefore(_dateFrom!)) return false;
    if (_dateTo != null && day.isAfter(_dateTo!)) return false;
    return true;
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filterDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> allDocs,
  ) {
    return allDocs
        .where(
          (d) =>
              _matchesSearch(d.data()) &&
              _matchesFilter(d.data()) &&
              _matchesDateRange(d.data()),
        )
        .toList();
  }

  String _csvCell(String value) {
    final s = value.replaceAll('"', '""');
    if (s.contains(',') || s.contains('"') || s.contains('\n') || s.contains('\r')) {
      return '"$s"';
    }
    return s;
  }

  String _panelAccessLabel(Map<String, dynamic> u) {
    final email = (u['email'] ?? '').toString();
    final role = (u['role'] ?? 'user').toString().toLowerCase();
    final panelActive = u['isActive'] != false && AdminSession.roleIsStaff(role);
    if (AdminSession.isOwnerEmail(email)) return 'owner';
    if (panelActive) return role;
    return 'app user';
  }

  void _exportCsv(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    if (docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No users to export for the current filters.')),
      );
      return;
    }

    final rows = <String>[
      'Date,Name,Email,Phone,Country,Student Class,Subscription,App Role,Admin Panel,User ID',
    ];
    for (final doc in docs) {
      final u = doc.data();
      final name = (u['fullName'] ?? u['name'] ?? '').toString();
      rows.add([
        _csvCell(_fmtDateExport(u['createdAt'])),
        _csvCell(name),
        _csvCell((u['email'] ?? '').toString()),
        _csvCell((u['phone'] ?? '').toString()),
        _csvCell((u['country'] ?? '').toString()),
        _csvCell(_studentClass(u)),
        _csvCell(_subscriptionStatusLabel(u)),
        _csvCell((u['role'] ?? 'user').toString()),
        _csvCell(_panelAccessLabel(u)),
        _csvCell(doc.id),
      ].join(','));
    }

    final fromPart = _dateFrom == null
        ? 'all'
        : DateFormat('yyyyMMdd').format(_dateFrom!);
    final toPart =
        _dateTo == null ? 'all' : DateFormat('yyyyMMdd').format(_dateTo!);
    final filename = 'testprepkart_users_${fromPart}_$toPart.csv';

    try {
      downloadCsvOnWeb(filename: filename, contents: rows.join('\n'));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exported ${docs.length} user(s) to $filename')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  Widget _panelAccessCell(String userId, Map<String, dynamic> u) {
    final email = (u['email'] ?? '').toString();
    final role = (u['role'] ?? 'user').toString().toLowerCase();
    final panelActive = u['isActive'] != false && AdminSession.roleIsStaff(role);

    if (!_isOwner) {
      return Tooltip(
        message: panelActive ? 'Admin panel: $role' : 'App user only',
        child: Icon(
          panelActive ? Icons.shield_outlined : Icons.smartphone_outlined,
          size: 20,
          color: panelActive ? Colors.green.shade700 : Colors.grey.shade600,
        ),
      );
    }

    if (AdminSession.isOwnerEmail(email)) {
      return const Tooltip(
        message: 'Owner account',
        child: Icon(Icons.verified_user_rounded, size: 20, color: Color(0xFF5E35B1)),
      );
    }

    if (panelActive) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Tooltip(
            message: 'Moderator/admin ($role)',
            child: Icon(Icons.shield_outlined, size: 20, color: Colors.green.shade700),
          ),
          IconButton(
            icon: Icon(Icons.person_remove_alt_1_rounded, color: Colors.red.shade700, size: 20),
            tooltip: 'Revoke admin panel access',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: _compactIconConstraints,
            onPressed: () => _confirmRevoke(context, userId, email),
          ),
        ],
      );
    }

    return IconButton(
      icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
      color: Theme.of(context).colorScheme.primary,
      tooltip: 'Grant moderator access',
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: _compactIconConstraints,
      onPressed:
          email.contains('@') ? () => _confirmGrant(context, userId, email) : null,
    );
  }

  Widget _selectableCell(String value) {
    return SelectableText(
      value,
      style: const TextStyle(fontSize: 13),
      enableInteractiveSelection: true,
    );
  }

  String _userDisplayName(Map<String, dynamic> u) =>
      (u['fullName'] ?? u['name'] ?? '-').toString();

  String _formatUserDetailsClipboard(Map<String, dynamic> u) {
    return [
      'Name: ${_userDisplayName(u)}',
      'Email: ${(u['email'] ?? '-').toString()}',
      'Phone: ${(u['phone'] ?? '-').toString()}',
      'Country: ${(u['country'] ?? '-').toString()}',
      'Class: ${_studentClass(u)}',
    ].join('\n');
  }

  Future<void> _copyUserDetails(Map<String, dynamic> u) async {
    await Clipboard.setData(
      ClipboardData(text: _formatUserDetailsClipboard(u)),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied details for ${_userDisplayName(u)}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _userDetailLine(String label, String value) {
    final style = Theme.of(context).textTheme.bodySmall;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: SelectableText.rich(
        TextSpan(
          style: style,
          children: [
            TextSpan(
              text: '$label: ',
              style: style?.copyWith(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  Widget _copyableUserRow({
    required Map<String, dynamic> user,
    required Widget child,
  }) {
    return GestureDetector(
      onLongPress: () => _copyUserDetails(user),
      behavior: HitTestBehavior.opaque,
      child: child,
    );
  }

  Widget _buildMobileUserCard(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final u = doc.data();
    final name = _userDisplayName(u);
    final iso2 = _countryIso2(u);
    final flag = _flagEmojiFromIso2(iso2);
    final role = (u['role'] ?? 'user').toString();
    final email = (u['email'] ?? '-').toString();
    final isNewRegistration = u['adminRegistrationUnread'] == true;

    return _copyableUserRow(
      user: u,
      child: Card(
        color: isNewRegistration ? const Color(0x14E53935) : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isNewRegistration)
                    IconButton(
                      icon: const Icon(
                        Icons.fiber_manual_record,
                        color: Color(0xFFE53935),
                        size: 12,
                      ),
                      tooltip: 'New registration — mark seen',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: _compactIconConstraints,
                      onPressed: () => _clearRegistrationUnread(doc.id),
                    ),
                  if (flag.isNotEmpty) ...[
                    Text(flag, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: SelectableText(
                      name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _userDetailLine('Date', _fmtDateTable(u['createdAt'])),
              _userDetailLine('Email', email),
              _userDetailLine('Phone', (u['phone'] ?? '-').toString()),
              _userDetailLine('Country', (u['country'] ?? '-').toString()),
              _userDetailLine('Class', _studentClass(u)),
              const SizedBox(height: 4),
              Text(
                'Long-press card to copy all details',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
              const SizedBox(height: 8),
              Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _subscriptionIconRow(doc.id, u),
                if (_isOwner) _panelAccessCell(doc.id, u),
                if (_isOwner)
                  PopupMenuButton<String>(
                    tooltip: 'Change app role',
                    onSelected: (v) => _setRole(doc.id, v),
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'user', child: Text('user')),
                      PopupMenuItem(value: 'moderator', child: Text('moderator')),
                      PopupMenuItem(value: 'admin', child: Text('admin')),
                    ],
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          role,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const Icon(Icons.arrow_drop_down_rounded, size: 20),
                      ],
                    ),
                  )
                else
                  Chip(
                    label: Text(role),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                if (_isOwner && !AdminSession.isOwnerEmail(email))
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Active', style: TextStyle(fontSize: 12)),
                      Switch(
                        value: u['isActive'] != false,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onChanged: (v) => _patchUser(
                          doc.id,
                          fields: {'isActive': v},
                          successMessage: v
                              ? 'Panel login enabled'
                              : 'Panel login blocked',
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildUsersTable(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return SelectionArea(
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Scrollbar(
        thumbVisibility: true,
        child: SingleChildScrollView(
          primary: false,
          child: Scrollbar(
            thumbVisibility: true,
            notificationPredicate: (n) => n.depth == 1,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              primary: false,
              child: DataTable(
                columnSpacing: 16,
                horizontalMargin: 16,
                headingRowHeight: 40,
                dataRowMinHeight: 48,
                dataRowMaxHeight: 72,
                columns: [
                  const DataColumn(label: Text('Date')),
                  const DataColumn(label: Text('Name')),
                  const DataColumn(label: Text('Email')),
                  const DataColumn(label: Text('Phone')),
                  const DataColumn(label: Text('Country')),
                  const DataColumn(label: Text('Class')),
                  const DataColumn(label: Text('Subscription')),
                  if (_isOwner) const DataColumn(label: Text('Admin')),
                  const DataColumn(label: Text('App role')),
                ],
                rows: docs.map((doc) {
                  final u = doc.data();
                  final name = _userDisplayName(u);
                  final iso2 = _countryIso2(u);
                  final flag = _flagEmojiFromIso2(iso2);
                  final role = (u['role'] ?? 'user').toString();
                  final email = (u['email'] ?? '-').toString();
                  final isNewRegistration =
                      u['adminRegistrationUnread'] == true;
                  return DataRow(
                    color: isNewRegistration
                        ? WidgetStateProperty.all(const Color(0x14E53935))
                        : null,
                    cells: [
                      DataCell(
                        _copyableUserRow(
                          user: u,
                          child: _selectableCell(_fmtDateTable(u['createdAt'])),
                        ),
                      ),
                      DataCell(
                        _copyableUserRow(
                          user: u,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isNewRegistration) ...[
                                IconButton(
                                  icon: const Icon(
                                    Icons.fiber_manual_record,
                                    color: Color(0xFFE53935),
                                    size: 12,
                                  ),
                                  tooltip: 'New registration — mark seen',
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: _compactIconConstraints,
                                  onPressed: () =>
                                      _clearRegistrationUnread(doc.id),
                                ),
                                const SizedBox(width: 4),
                              ],
                              if (flag.isNotEmpty) ...[
                                Text(
                                  flag,
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const SizedBox(width: 6),
                              ],
                              _selectableCell(name),
                            ],
                          ),
                        ),
                      ),
                      DataCell(
                        _copyableUserRow(
                          user: u,
                          child: _selectableCell(email),
                        ),
                      ),
                      DataCell(
                        _copyableUserRow(
                          user: u,
                          child: _selectableCell((u['phone'] ?? '-').toString()),
                        ),
                      ),
                      DataCell(
                        _copyableUserRow(
                          user: u,
                          child: _selectableCell((u['country'] ?? '-').toString()),
                        ),
                      ),
                      DataCell(
                        _copyableUserRow(
                          user: u,
                          child: _selectableCell(_studentClass(u)),
                        ),
                      ),
                      DataCell(_subscriptionIconRow(doc.id, u)),
                      if (_isOwner) DataCell(_panelAccessCell(doc.id, u)),
                      DataCell(
                        _isOwner
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  PopupMenuButton<String>(
                                    tooltip: 'Change app role',
                                    onSelected: (v) => _setRole(doc.id, v),
                                    itemBuilder: (context) => const [
                                      PopupMenuItem(
                                        value: 'user',
                                        child: Text('user'),
                                      ),
                                      PopupMenuItem(
                                        value: 'moderator',
                                        child: Text('moderator'),
                                      ),
                                      PopupMenuItem(
                                        value: 'admin',
                                        child: Text('admin'),
                                      ),
                                    ],
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            role,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const Icon(
                                            Icons.arrow_drop_down_rounded,
                                            size: 20,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Tooltip(
                                    message: 'Panel login active switch',
                                    child: Switch(
                                      value: u['isActive'] != false,
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      onChanged: AdminSession.isOwnerEmail(email)
                                          ? null
                                          : (v) => _patchUser(
                                                doc.id,
                                                fields: {'isActive': v},
                                                successMessage: v
                                                    ? 'Panel login enabled'
                                                    : 'Panel login blocked',
                                              ),
                                    ),
                                  ),
                                ],
                              )
                            : _selectableCell(role),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildModeratorInfoCard({required bool compact}) {
    if (compact) {
      return Card(
        color: const Color(0xFFF3E5F5),
        margin: EdgeInsets.zero,
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          leading: Icon(
            Icons.groups_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
          title: Text(
            'App moderators',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          subtitle: const Text(
            'Tap to view setup steps',
            style: TextStyle(fontSize: 12),
          ),
          children: [
            const Text(
              '1. Person registers on the mobile app (same email they will use for admin).\n'
              '2. Find them below and tap Grant moderator.\n'
              '3. They sign in at the admin website with that email and password.\n'
              '4. Use Revoke to remove admin access anytime (mobile app login stays).',
              style: TextStyle(fontSize: 13, height: 1.35),
            ),
            if (!_isOwner) ...[
              const SizedBox(height: 8),
              Text(
                'Only the owner account can grant or revoke moderator access.',
                style: TextStyle(
                  color: Colors.orange.shade900,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Card(
      color: const Color(0xFFF3E5F5),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.groups_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'App moderators',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '1. Person registers on the mobile app (same email they will use for admin).\n'
              '2. Find them below and tap Grant moderator.\n'
              '3. They sign in at the admin website with that email and password.\n'
              '4. Use Revoke to remove admin access anytime (mobile app login stays).',
            ),
            if (!_isOwner) ...[
              const SizedBox(height: 8),
              Text(
                'Only the owner account can grant or revoke moderator access.',
                style: TextStyle(
                  color: Colors.orange.shade900,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDateFilters({required bool compact}) {
    final fromLabel = _dateFrom == null
        ? 'From'
        : DateFormat('dd MMM yy').format(_dateFrom!);
    final toLabel =
        _dateTo == null ? 'To' : DateFormat('dd MMM yy').format(_dateTo!);

    if (compact) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _pickDate(isFrom: true),
              icon: const Icon(Icons.calendar_today_outlined, size: 16),
              label: Text(fromLabel),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                textStyle: const TextStyle(fontSize: 13),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _pickDate(isFrom: false),
              icon: const Icon(Icons.event_outlined, size: 16),
              label: Text(toLabel),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                textStyle: const TextStyle(fontSize: 13),
              ),
            ),
          ),
          if (_dateFrom != null || _dateTo != null) ...[
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Clear date range',
              onPressed: _clearDateFilters,
              icon: const Icon(Icons.clear_rounded, size: 20),
              visualDensity: VisualDensity.compact,
              constraints: _compactIconConstraints,
            ),
          ],
        ],
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: () => _pickDate(isFrom: true),
          icon: const Icon(Icons.calendar_today_outlined, size: 18),
          label: Text(
            _dateFrom == null
                ? 'From date'
                : DateFormat('dd MMM yyyy').format(_dateFrom!),
          ),
        ),
        OutlinedButton.icon(
          onPressed: () => _pickDate(isFrom: false),
          icon: const Icon(Icons.event_outlined, size: 18),
          label: Text(
            _dateTo == null
                ? 'To date'
                : DateFormat('dd MMM yyyy').format(_dateTo!),
          ),
        ),
        if (_dateFrom != null || _dateTo != null)
          IconButton(
            tooltip: 'Clear date range',
            onPressed: _clearDateFilters,
            icon: const Icon(Icons.clear_rounded),
          ),
      ],
    );
  }

  Widget _buildSearchField({required bool compact}) {
    return TextField(
      controller: _searchController,
      onChanged: (v) => setState(() => _query = v.trim()),
      decoration: InputDecoration(
        hintText: compact
            ? 'Search users…'
            : 'Search by name, email, phone, country, class...',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: _query.isNotEmpty
            ? IconButton(
                tooltip: 'Clear search',
                onPressed: () {
                  _searchController.clear();
                  setState(() => _query = '');
                },
                icon: const Icon(Icons.clear_rounded),
              )
            : null,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }

  Widget _buildFilterChips({required bool compact}) {
    if (compact) {
      return SizedBox(
        height: 38,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _UserFilter.values.length,
          separatorBuilder: (context, index) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final f = _UserFilter.values[index];
            return FilterChip(
              label: Text(
                f.mobileLabel,
                style: const TextStyle(fontSize: 12),
              ),
              selected: _filter == f,
              onSelected: (_) => setState(() => _filter = f),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            );
          },
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _UserFilter.values.map((f) {
        return FilterChip(
          label: Text(f.label),
          selected: _filter == f,
          onSelected: (_) => setState(() => _filter = f),
        );
      }).toList(),
    );
  }

  Widget _buildResultsToolbar(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, {
    required bool compact,
  }) {
    final countText =
        '${docs.length} user(s)${_dateFrom != null || _dateTo != null ? ' in range' : ''}';

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            countText,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _markAllNewRegistrationsSeen,
                  icon: const Icon(Icons.done_all_rounded, size: 16),
                  label: const Text('Mark seen'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: docs.isEmpty ? null : () => _exportCsv(docs),
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text('Export'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return responsiveToolbar(
      context: context,
      leading: Text(
        countText,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      actions: [
        OutlinedButton.icon(
          onPressed: _markAllNewRegistrationsSeen,
          icon: const Icon(Icons.done_all_rounded, size: 18),
          label: const Text('Mark new registrations seen'),
        ),
        FilledButton.icon(
          onPressed: docs.isEmpty ? null : () => _exportCsv(docs),
          icon: const Icon(Icons.download_rounded, size: 18),
          label: const Text('Export CSV'),
        ),
      ],
    );
  }

  Widget _buildMobileScrollView(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildModeratorInfoCard(compact: true),
                const SizedBox(height: 10),
                _buildDateFilters(compact: true),
                const SizedBox(height: 10),
                _buildSearchField(compact: true),
                const SizedBox(height: 8),
                _buildFilterChips(compact: true),
                const SizedBox(height: 10),
                _buildResultsToolbar(docs, compact: true),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        if (docs.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: Text('No users found.')),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => Padding(
                  padding: EdgeInsets.only(bottom: index < docs.length - 1 ? 8 : 0),
                  child: _buildMobileUserCard(docs[index]),
                ),
                childCount: docs.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDesktopLayout(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildModeratorInfoCard(compact: false),
          const SizedBox(height: 12),
          _buildDateFilters(compact: false),
          const SizedBox(height: 10),
          responsiveToolbar(
            context: context,
            leading: _buildSearchField(compact: false),
            actions: [
              OutlinedButton.icon(
                onPressed: () {
                  _searchController.clear();
                  setState(() => _query = '');
                },
                icon: const Icon(Icons.clear_rounded),
                label: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildFilterChips(compact: false),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildResultsToolbar(docs, compact: false),
          ),
          Expanded(
            child: docs.isEmpty
                ? const Center(child: Text('No users found.'))
                : _buildUsersTable(docs),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = isAdminCompactLayout(context);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _users.orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Failed to load users: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final allDocs = snapshot.data?.docs ?? const [];
          final docs = _filterDocs(allDocs);

          if (compact) {
            return _buildMobileScrollView(docs);
          }
          return _buildDesktopLayout(docs);
        },
      );
  }
}

enum _UserFilter {
  all('All users', 'All'),
  appUsers('App users only', 'App'),
  panelAccess('Admin / moderators', 'Admin'),
  newRegistrations('New registrations', 'New'),
  subscriptionRequests('Subscription requests', 'Subs');

  const _UserFilter(this.label, this.mobileLabel);
  final String label;
  final String mobileLabel;
}
