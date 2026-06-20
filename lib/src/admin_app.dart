import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'pages/demo_request_page.dart';
import 'pages/courses_cms_page.dart';
import 'pages/content_library_import_page.dart';
import 'pages/content_library_editor_page.dart';
import 'pages/eligibility_tool_page.dart';
import 'pages/exam_date_cms_page.dart';
import 'pages/medical_colleges_cms_page.dart';
import 'pages/seat_allotment_page.dart';
import 'pages/messages_page.dart';
import 'pages/timeline_cms_page.dart';
import 'pages/updates_cms_page.dart';
import 'pages/users_page.dart';
import 'pages/webinars_cms_page.dart';
import 'pages/settings_page.dart';
import 'pages/sign_in_page.dart';
import 'pages/unsubscribe_page.dart';
import 'pages/unsubscribe_requests_page.dart';
import 'pages/subscription_cms_page.dart';
import 'admin_auth_constants.dart';
import 'services/admin_auth_eligibility.dart';
import 'services/admin_email/admin_email_listener.dart';
import 'services/firestore_db.dart';
import 'widgets/responsive_layout.dart';
import 'widgets/testprepkart_logo.dart';

const bool kEnforceAdminRoleGuard = true;
const String kOwnerAdminEmail = AdminAuthConstants.ownerAdminEmail;

class AdminApp extends StatelessWidget {
  const AdminApp({super.key, required this.firebaseReady});

  final bool firebaseReady;

  @override
  Widget build(BuildContext context) {
    final home = _resolveHome(firebaseReady);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NEET Prep Admin',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5E35B1)),
        useMaterial3: true,
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      home: home,
    );
  }
}

/// Public `/unsubscribe` (Google Play account deletion URL) vs admin shell.
Widget _resolveHome(bool firebaseReady) {
  if (_isPublicUnsubscribePath(Uri.base.path)) {
    return firebaseReady
        ? const UnsubscribePage()
        : const _FirebaseSetupRequiredPage();
  }
  return firebaseReady
      ? const AdminAuthGate()
      : const _FirebaseSetupRequiredPage();
}

bool _isPublicUnsubscribePath(String path) {
  final normalized = path.trim();
  if (normalized.isEmpty || normalized == '/') return false;
  final withoutTrailing = normalized.endsWith('/')
      ? normalized.substring(0, normalized.length - 1)
      : normalized;
  return withoutTrailing == '/unsubscribe';
}

class AdminAuthGate extends StatelessWidget {
  const AdminAuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      // Avoid an indefinite spinner on web before the first auth event.
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, snapshot) {
        final user = snapshot.data ?? FirebaseAuth.instance.currentUser;
        if (snapshot.connectionState == ConnectionState.waiting &&
            user == null) {
          return const SignInPage();
        }
        if (user == null) return const SignInPage();
        final email = (user.email ?? '').trim();
        if (user.isAnonymous || email.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            FirebaseAuth.instance.signOut();
          });
          return const SignInPage();
        }
        if (!kEnforceAdminRoleGuard) return const AdminHomeShell();
        return _AdminRoleGate(user: user);
      },
    );
  }
}

class _AdminRoleGate extends StatelessWidget {
  const _AdminRoleGate({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final email = (user.email ?? '').trim().toLowerCase();
    if (email == kOwnerAdminEmail) {
      return const AdminHomeShell();
    }
    return FutureBuilder<bool>(
      future: AdminAuthEligibility.hasActiveAdminAccess(
        email: email,
        uid: user.uid,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _AdminAccessPendingPage(email: user.email ?? email);
        }
        if (snapshot.hasError) {
          debugPrint(
            '[TPK][ADMIN] Admin access check failed: ${snapshot.error}',
          );
        }
        if (snapshot.data == true) {
          return const AdminHomeShell();
        }
        return _UnauthorizedPage(
          email: user.email ?? 'unknown',
          uid: user.uid,
          reason:
              'Signed in to Firebase, but this account is not an active admin or moderator on '
              'Firestore users/${user.uid}. On App Users, grant moderator for this email again, '
              'then sign in with that email (not the UID).',
        );
      },
    );
  }
}

class _AdminAccessPendingPage extends StatelessWidget {
  const _AdminAccessPendingPage({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Checking admin access for $email…',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => FirebaseAuth.instance.signOut(),
                child: const Text('Sign out and use another account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnauthorizedPage extends StatelessWidget {
  const _UnauthorizedPage({
    required this.email,
    required this.uid,
    required this.reason,
  });

  final String email;
  final String uid;
  final String reason;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.block_rounded, color: Color(0xFFC62828)),
                      SizedBox(width: 8),
                      Text(
                        'Admin access denied',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text('Signed in as: $email'),
                  const SizedBox(height: 4),
                  SelectableText(
                    'Firebase UID: $uid',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(reason),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: () => FirebaseAuth.instance.signOut(),
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Sign out'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FirebaseSetupRequiredPage extends StatelessWidget {
  const _FirebaseSetupRequiredPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFFEF6C00),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Firebase setup required',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Admin web app could not initialize Firebase. Add Firebase web configuration for this project and restart.',
                  ),
                  const SizedBox(height: 12),
                  const Text('Next steps:'),
                  const SizedBox(height: 6),
                  const Text(
                    '1) Run: flutterfire configure (inside neetprep_admin_web)',
                  ),
                  const Text(
                    '2) Ensure firebase_options.dart is generated for web',
                  ),
                  const Text(
                    '3) Initialize Firebase with options in main.dart',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AdminHomeShell extends StatefulWidget {
  const AdminHomeShell({super.key});

  @override
  State<AdminHomeShell> createState() => _AdminHomeShellState();
}

class _AdminHomeShellState extends State<AdminHomeShell> {
  int _tab = 0;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    AdminEmailListener.instance.start();
  }

  @override
  void dispose() {
    AdminEmailListener.instance.stop();
    super.dispose();
  }

  final _pages = const [
    DemoRequestPage(),
    ExamDateCmsPage(),
    EligibilityToolPage(),
    MessagesPage(),
    ContentLibraryImportPage(),
    ContentLibraryEditorPage(),
    UpdatesCmsPage(),
    TimelineCmsPage(),
    SubscriptionCmsPage(),
    MedicalCollegesCmsPage(),
    SeatAllotmentPage(),
    CoursesCmsPage(),
    WebinarsCmsPage(),
    SettingsPage(),
    UnsubscribeRequestsPage(),
    UsersPage(),
  ];

  final _titles = const [
    'Demo Request',
    'NEET Exam Date & Parent Guide CMS',
    'Eligibility Tool',
    'Messages',
    'Content Library Import',
    'Content Library Editor',
    'NEET Updates CMS',
    'NEET Timelines CMS',
    'Subscription CMS',
    'Medical Colleges CMS',
    'Seat Allotment',
    'Courses CMS',
    'Webinars CMS',
    'Settings',
    'Unsubscribe Request',
    'App Users',
  ];

  void _selectTab(int index) {
    setState(() => _tab = index);
    if (isAdminCompactLayout(context)) {
      _scaffoldKey.currentState?.closeDrawer();
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = isAdminCompactLayout(context);

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        automaticallyImplyLeading: compact,
        leadingWidth: compact ? 56 : 188,
        leading: compact
            ? null
            : const Padding(
                padding: EdgeInsets.fromLTRB(14, 10, 8, 10),
                child: TestprepKartLogo(height: 34, maxWidth: 160),
              ),
        centerTitle: false,
        title: Text(
          _titles[_tab],
          overflow: TextOverflow.ellipsis,
        ),
        iconTheme: IconThemeData(
          color: Theme.of(context).colorScheme.onSurface,
        ),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      drawer: compact
          ? Drawer(
              child: _AdminNavigationRail(
                selectedIndex: _tab,
                onDestinationSelected: _selectTab,
                expanded: true,
              ),
            )
          : null,
      body: compact
          ? ColoredBox(
              color: Theme.of(context).colorScheme.surface,
              child: _pages[_tab],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _AdminNavigationRail(
                  selectedIndex: _tab,
                  onDestinationSelected: _selectTab,
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: ColoredBox(
                    color: Theme.of(context).colorScheme.surface,
                    child: _pages[_tab],
                  ),
                ),
              ],
            ),
    );
  }
}

class _AdminNavDestination {
  const _AdminNavDestination({
    required this.index,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.showBadge = false,
  });

  final int index;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool showBadge;
}

/// Scrollable side nav (NavigationRail + SingleChildScrollView breaks on web).
class _AdminNavigationRail extends StatelessWidget {
  const _AdminNavigationRail({
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.expanded = false,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool expanded;

  static const List<_AdminNavDestination> _destinations = [
    _AdminNavDestination(
      index: 0,
      icon: Icons.video_settings_outlined,
      selectedIcon: Icons.video_settings_rounded,
      label: 'Demo Request',
    ),
    _AdminNavDestination(
      index: 1,
      icon: Icons.event_note_outlined,
      selectedIcon: Icons.event_note_rounded,
      label: 'Exam Date',
    ),
    _AdminNavDestination(
      index: 2,
      icon: Icons.rule_folder_outlined,
      selectedIcon: Icons.rule_folder_rounded,
      label: 'Eligibility',
    ),
    _AdminNavDestination(
      index: 3,
      icon: Icons.chat_bubble_outline_rounded,
      selectedIcon: Icons.chat_bubble_rounded,
      label: 'Messages',
    ),
    _AdminNavDestination(
      index: 4,
      icon: Icons.library_books_outlined,
      selectedIcon: Icons.library_books_rounded,
      label: 'CL Import',
    ),
    _AdminNavDestination(
      index: 5,
      icon: Icons.edit_note_outlined,
      selectedIcon: Icons.edit_note_rounded,
      label: 'CL Editor',
    ),
    _AdminNavDestination(
      index: 6,
      icon: Icons.newspaper_outlined,
      selectedIcon: Icons.newspaper_rounded,
      label: 'Updates',
    ),
    _AdminNavDestination(
      index: 7,
      icon: Icons.timeline_outlined,
      selectedIcon: Icons.timeline_rounded,
      label: 'Timelines',
    ),
    _AdminNavDestination(
      index: 8,
      icon: Icons.workspace_premium_outlined,
      selectedIcon: Icons.workspace_premium_rounded,
      label: 'Subscription',
    ),
    _AdminNavDestination(
      index: 9,
      icon: Icons.account_balance_outlined,
      selectedIcon: Icons.account_balance_rounded,
      label: 'Colleges',
    ),
    _AdminNavDestination(
      index: 10,
      icon: Icons.event_seat_outlined,
      selectedIcon: Icons.event_seat_rounded,
      label: 'Seat Allotment',
    ),
    _AdminNavDestination(
      index: 11,
      icon: Icons.school_outlined,
      selectedIcon: Icons.school_rounded,
      label: 'Courses',
    ),
    _AdminNavDestination(
      index: 12,
      icon: Icons.live_tv_outlined,
      selectedIcon: Icons.live_tv_rounded,
      label: 'Webinar',
    ),
    _AdminNavDestination(
      index: 13,
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings_rounded,
      label: 'Settings',
    ),
    _AdminNavDestination(
      index: 14,
      icon: Icons.person_remove_outlined,
      selectedIcon: Icons.person_remove_rounded,
      label: 'Unsubscribe',
    ),
    _AdminNavDestination(
      index: 15,
      icon: Icons.people_outline_rounded,
      selectedIcon: Icons.people_alt_rounded,
      label: 'Users',
    ),
  ];

  List<_AdminNavDestination> _withBadges({
    required bool hasPendingDemoRequests,
    required bool hasPendingMessages,
    required bool hasPendingCourses,
    required bool hasPendingSubscriptionRequests,
    required bool hasPendingUnsubscribeRequests,
    required bool hasNewUserRegistrations,
  }) {
    final hasUsersMenuAttention =
        hasPendingSubscriptionRequests || hasNewUserRegistrations;
    return _destinations
        .map(
          (d) => _AdminNavDestination(
            index: d.index,
            icon: d.icon,
            selectedIcon: d.selectedIcon,
            label: d.label,
            showBadge: (d.index == 0 && hasPendingDemoRequests) ||
                (d.index == 3 && hasPendingMessages) ||
                (d.index == 11 && hasPendingCourses) ||
                (d.index == 14 && hasPendingUnsubscribeRequests) ||
                (d.index == 15 && hasUsersMenuAttention),
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreDb.instance
          .collection('threads')
          .where('adminUnread', isEqualTo: true)
          .limit(1)
          .snapshots(),
      builder: (context, messageSnapshot) {
        final hasPendingMessages =
            (messageSnapshot.data?.docs ?? const []).isNotEmpty;
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirestoreDb.instance
              .collection('analysis_session_requests')
              .where('status', isEqualTo: 'pending_confirmation')
              .limit(1)
              .snapshots(),
          builder: (context, demoRequestSnapshot) {
            final hasPendingDemoRequests =
                (demoRequestSnapshot.data?.docs ?? const []).isNotEmpty;
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirestoreDb.instance
                  .collection('course_inquiries')
                  .where('isRead', isEqualTo: false)
                  .limit(1)
                  .snapshots(),
              builder: (context, inquirySnapshot) {
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirestoreDb.instance
                      .collection('course_demo_bookings')
                      .where('isRead', isEqualTo: false)
                      .limit(1)
                      .snapshots(),
                  builder: (context, courseDemoSnapshot) {
                    final hasPendingCourses =
                        (inquirySnapshot.data?.docs ?? const []).isNotEmpty ||
                            (courseDemoSnapshot.data?.docs ?? const [])
                                .isNotEmpty;
                    return StreamBuilder<
                        QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirestoreDb.instance
                          .collection('account_deletion_requests')
                          .where('isRead', isEqualTo: false)
                          .limit(1)
                          .snapshots(),
                      builder: (context, unsubscribeSnapshot) {
                        final hasPendingUnsubscribeRequests =
                            (unsubscribeSnapshot.data?.docs ?? const [])
                                .isNotEmpty;
                        return StreamBuilder<
                            QuerySnapshot<Map<String, dynamic>>>(
                          stream: FirestoreDb.instance
                              .collection('users')
                              .where('subscriptionRequestPending',
                                  isEqualTo: true)
                              .limit(1)
                              .snapshots(),
                          builder: (context, subscriptionSnapshot) {
                            final hasPendingSubscriptionRequests =
                                (subscriptionSnapshot.data?.docs ?? const [])
                                    .isNotEmpty;
                            return StreamBuilder<
                                QuerySnapshot<Map<String, dynamic>>>(
                              stream: FirestoreDb.instance
                                  .collection('users')
                                  .where('adminRegistrationUnread',
                                      isEqualTo: true)
                                  .limit(1)
                                  .snapshots(),
                              builder: (context, registrationSnapshot) {
                                final hasNewUserRegistrations =
                                    (registrationSnapshot.data?.docs ??
                                            const [])
                                        .isNotEmpty;
                                final items = _withBadges(
                                  hasPendingDemoRequests:
                                      hasPendingDemoRequests,
                                  hasPendingMessages: hasPendingMessages,
                                  hasPendingCourses: hasPendingCourses,
                                  hasPendingSubscriptionRequests:
                                      hasPendingSubscriptionRequests,
                                  hasPendingUnsubscribeRequests:
                                      hasPendingUnsubscribeRequests,
                                  hasNewUserRegistrations:
                                      hasNewUserRegistrations,
                                );
                                final navList = Material(
                                  color: colorScheme.surfaceContainerHighest
                                      .withValues(alpha: 0.35),
                                  child: ListView.builder(
                                    padding: EdgeInsets.symmetric(
                                      vertical: expanded ? 0 : 8,
                                    ),
                                    itemCount: items.length,
                                    itemBuilder: (context, i) {
                                      final item = items[i];
                                      final selected =
                                          selectedIndex == item.index;
                                      return ListTile(
                                        dense: true,
                                        selected: selected,
                                        leading: _PendingBadgeIcon(
                                          icon: selected
                                              ? item.selectedIcon
                                              : item.icon,
                                          showBadge: item.showBadge,
                                        ),
                                        title: Text(
                                          item.label,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: selected
                                                ? FontWeight.w600
                                                : FontWeight.w400,
                                          ),
                                        ),
                                        onTap: () =>
                                            onDestinationSelected(item.index),
                                      );
                                    },
                                  ),
                                );

                                if (expanded) {
                                  return SafeArea(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            16,
                                            16,
                                            16,
                                            8,
                                          ),
                                          child: const TestprepKartLogo(
                                            height: 36,
                                            maxWidth: 180,
                                          ),
                                        ),
                                        const Divider(height: 1),
                                        Expanded(child: navList),
                                      ],
                                    ),
                                  );
                                }

                                return SizedBox(width: 220, child: navList);
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class _PendingBadgeIcon extends StatelessWidget {
  const _PendingBadgeIcon({required this.icon, required this.showBadge});

  final IconData icon;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        if (showBadge)
          const Positioned(
            right: -2,
            top: -2,
            child: CircleAvatar(radius: 4, backgroundColor: Color(0xFFE53935)),
          ),
      ],
    );
  }
}
