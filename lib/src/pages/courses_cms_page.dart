import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/exchange_rate_service.dart';
import '../services/firestore_db.dart';
import '../widgets/admin_dialog_save_actions.dart';

class CoursesCmsPage extends StatelessWidget {
  const CoursesCmsPage({super.key});

  CollectionReference<Map<String, dynamic>> get _courses =>
      FirestoreDb.instance.collection('courses');

  DocumentReference<Map<String, dynamic>> get _settings =>
      FirestoreDb.instance.collection('course_page_config').doc('main');

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreDb.instance
          .collection('course_inquiries')
          .where('isRead', isEqualTo: false)
          .snapshots(),
      builder: (context, inquirySnapshot) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirestoreDb.instance
              .collection('course_demo_bookings')
              .where('isRead', isEqualTo: false)
              .snapshots(),
          builder: (context, demoSnapshot) {
            final inquiryCount = inquirySnapshot.data?.docs.length ?? 0;
            final demoCount = demoSnapshot.data?.docs.length ?? 0;
            return DefaultTabController(
              length: 4,
              child: Column(
                children: [
                  TabBar(
                    isScrollable: true,
                    tabs: [
                      const Tab(text: 'All Courses'),
                      Tab(child: _RequestTabLabel('Inquiries', inquiryCount)),
                      Tab(child: _RequestTabLabel('Demo Bookings', demoCount)),
                      const Tab(text: 'Page Settings'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _AllCoursesTab(courses: _courses),
                        const _RequestTable(collection: 'course_inquiries'),
                        const _RequestTable(collection: 'course_demo_bookings'),
                        _PageSettingsTab(settings: _settings),
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

class _RequestTabLabel extends StatelessWidget {
  const _RequestTabLabel(this.label, this.count);

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(count > 0 ? '$label ($count)' : label),
        if (count > 0) ...[
          const SizedBox(width: 6),
          const CircleAvatar(radius: 4, backgroundColor: Color(0xFFE53935)),
        ],
      ],
    );
  }
}

class _AllCoursesTab extends StatefulWidget {
  const _AllCoursesTab({required this.courses});

  final CollectionReference<Map<String, dynamic>> courses;

  @override
  State<_AllCoursesTab> createState() => _AllCoursesTabState();
}

class _AllCoursesTabState extends State<_AllCoursesTab> {
  bool _isEnsuringDefaults = false;
  String? _lastSeedError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _ensureDefaultCoursesInFirestore(
          showSuccessSnack: false,
          showErrorSnack: true,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Courses',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _isEnsuringDefaults
                    ? null
                    : () => _ensureDefaultCoursesInFirestore(
                          showSuccessSnack: true,
                          showErrorSnack: true,
                        ),
                icon: _isEnsuringDefaults
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_upload_rounded),
                label: const Text('Sync 5 templates'),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: () => _openEditor(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Course'),
              ),
            ],
          ),
          if (_lastSeedError != null) ...[
            const SizedBox(height: 10),
            Material(
              color: const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SelectableText(
                  _lastSeedError!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFB71C1C),
                    height: 1.35,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              // No server orderBy: docs missing meta.displayOrder still appear; we sort client-side.
              stream: widget.courses.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Failed: ${snapshot.error}'));
                }
                final rawDocs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
                  snapshot.data?.docs ?? const [],
                )..sort(
                    (a, b) => _courseDisplayOrder(a).compareTo(_courseDisplayOrder(b)),
                  );
                final docs = rawDocs;
                if (docs.isEmpty) {
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'No courses in Firestore yet.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _lastSeedError ??
                                'Tap “Sync 5 templates” above. You must be signed in; '
                                'Firestore rules must allow authenticated writes to collection '
                                '`courses` with document IDs: course_1yr_intensive, '
                                'course_2yr_program, course_foundation, course_crash, '
                                'course_test_series. Pasting JSON in chat does not import data — '
                                'sync uses built‑in payloads matching those IDs.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: Color(0xFF616161),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return Card(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(8),
                    itemCount: docs.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data();
                      final meta = _map(data['meta']);
                      final pricing =
                          _map(_read(data, 'detailPage.heroPricing'));
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text('${_int(meta['displayOrder'], index + 1)}'),
                        ),
                        title: Text(
                          _text(
                            _read(data, 'listingCard.naming.primaryName'),
                            'Untitled course',
                          ),
                        ),
                        subtitle: Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _Chip(
                              label: 'INR ${_int(pricing['inrCurrent'], 0)}',
                            ),
                            _Chip(
                              label: meta['isActive'] == false
                                  ? 'Inactive'
                                  : 'Active',
                            ),
                            if (meta['isFeatured'] == true)
                              const _Chip(label: 'Featured'),
                          ],
                        ),
                        trailing: Wrap(
                          spacing: 4,
                          children: [
                            IconButton(
                              tooltip: 'Edit',
                              onPressed: () => _openEditor(context, doc: doc),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              tooltip: meta['isActive'] == false
                                  ? 'Activate'
                                  : 'Deactivate',
                              onPressed: () => doc.reference.set({
                                'meta': {
                                  ...meta,
                                  'isActive': meta['isActive'] == false,
                                },
                                'updatedAt': FieldValue.serverTimestamp(),
                              }, SetOptions(merge: true)),
                              icon: Icon(
                                meta['isActive'] == false
                                    ? Icons.visibility_rounded
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Writes canonical course documents to Firestore for each template ID if that doc is missing.
  /// Failures are collected per document so one bad write does not block the other four.
  Future<void> _ensureDefaultCoursesInFirestore({
    bool showSuccessSnack = false,
    bool showErrorSnack = false,
  }) async {
    if (_isEnsuringDefaults) return;
    _isEnsuringDefaults = true;
    if (mounted) setState(() => _lastSeedError = null);

    var created = 0;
    final failures = <String>[];

    Future<void> upsertMissing() async {
      late final List<Map<String, dynamic>> payloads;
      try {
        payloads = _seedCoreCourses();
      } catch (e) {
        failures.add('build seed payloads → $e');
        return;
      }

      final byId = <String, Map<String, dynamic>>{};
      for (final p in payloads) {
        final id = p['id']?.toString() ?? '';
        if (id.isNotEmpty) byId[id] = p;
      }

      for (final entry in byId.entries) {
        final id = entry.key;
        try {
          final ref = widget.courses.doc(id);
          final doc = await ref.get();
          if (!doc.exists) {
            var data = Map<String, dynamic>.from(entry.value)..remove('id');
            try {
              data = _stripNullValuesFromMap(data);
            } catch (e) {
              failures.add('$id (strip nulls) → $e');
              continue;
            }
            await ref.set(data, SetOptions(merge: true));
            created++;
          }
        } catch (e) {
          failures.add('$id → $e');
        }
      }
    }

    try {
      await upsertMissing();
    } catch (e) {
      failures.add('bulk sync → $e');
    } finally {
      if (mounted) {
        setState(() {
          _lastSeedError =
              failures.isEmpty ? null : failures.join('\n');
          _isEnsuringDefaults = false;
        });
      } else {
        _isEnsuringDefaults = false;
      }
    }

    if (!mounted) return;

    if (failures.isNotEmpty && showErrorSnack) {
      final short = failures.length > 2
          ? '${failures.take(2).join(' | ')} (+${failures.length - 2} more)'
          : failures.join(' | ');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Course templates: write failed — $short'),
          backgroundColor: const Color(0xFFC62828),
          duration: const Duration(seconds: 8),
        ),
      );
    }
    if (showSuccessSnack && failures.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            created > 0
                ? 'Created $created missing template document(s) in courses.'
                : 'All 5 template course IDs already exist in Firestore.',
          ),
        ),
      );
    }
  }

  Future<void> _openEditor(
    BuildContext context, {
    DocumentSnapshot<Map<String, dynamic>>? doc,
  }) async {
    final data = doc?.data() ?? _defaultCoursePayload();
    final meta = _map(data['meta']);
    final name = TextEditingController(
      text: _text(_read(data, 'listingCard.naming.primaryName'), ''),
    );
    final usName = TextEditingController(
      text: _text(_read(data, 'listingCard.naming.localizedNameUS'), ''),
    );
    final tagline = TextEditingController(
      text: _text(_read(data, 'listingCard.naming.tagline'), ''),
    );
    final tierLabel = TextEditingController(
      text: _text(_read(data, 'listingCard.naming.tierLabel'), ''),
    );
    final tags = TextEditingController(
      text: _list(_read(data, 'listingCard.tags')).join(', '),
    );
    final cardColor = TextEditingController(
      text: _text(_read(data, 'listingCard.cardVisual.cardBackground'), '#1E3A8A'),
    );
    final accentColor = TextEditingController(
      text: _text(_read(data, 'listingCard.cardVisual.accentColor'), '#93C5FD'),
    );
    final videoId = TextEditingController(
      text: _text(_read(data, 'detailPage.videoSection.youtubeVideoId'), ''),
    );
    final videoTitle = TextEditingController(
      text: _text(_read(data, 'detailPage.videoSection.videoTitle'), ''),
    );
    final facultyName = TextEditingController(
      text: _text(_read(data, 'detailPage.facultySection.facultyName'), ''),
    );
    final facultyRole = TextEditingController(
      text: _text(_read(data, 'detailPage.facultySection.facultyRole'), ''),
    );
    final usaHeadline = TextEditingController(
      text: _text(_read(data, 'detailPage.usaBanner.headline'), ''),
    );
    final usaDetail = TextEditingController(
      text: _text(_read(data, 'detailPage.usaBanner.detailLine'), ''),
    );
    final features = TextEditingController(
      text: _itemsText(_read(data, 'detailPage.featuresSection.items')),
    );
    final curriculum = TextEditingController(
      text: _subjectsText(_read(data, 'detailPage.curriculumSection.subjects')),
    );
    final reviews = TextEditingController(
      text: _reviewsText(_read(data, 'detailPage.reviewsSection.reviewCards.items')),
    );
    final passRateController = TextEditingController(
      text: _text(_read(data, 'listingCard.statistics.stat2.value'), '94%'),
    );
    var displayOrder = _int(meta['displayOrder'], 1);
    var isActive = meta['isActive'] != false;
    var isFeatured = meta['isFeatured'] == true;
    var inrCurrent = _int(_read(data, 'detailPage.heroPricing.inrCurrent'), 49999);
    var inrOriginal =
        _int(_read(data, 'detailPage.heroPricing.inrOriginal'), 64999);
    final contentHtml = TextEditingController(
      text: _text(_read(data, 'detailPage.contentSection.html'), ''),
    );
    final classVideos = TextEditingController(
      text: _classVideosText(_read(data, 'detailPage.classVideosSection.items')),
    );
    final couponCode = TextEditingController(
      text: _text(_read(data, 'detailPage.pricingSection.couponCode'), ''),
    );
    var couponDiscountUsd =
        _int(_read(data, 'detailPage.pricingSection.couponDiscountUsd'), 100);
    final enrollmentForm = TextEditingController(
      text: _text(_read(data, 'detailPage.pricingSection.enrollmentForm.body'), ''),
    );
    final bankDetails = TextEditingController(
      text: _text(_read(data, 'detailPage.pricingSection.bankDetails.body'), ''),
    );
    final courseBrochure = TextEditingController(
      text: _text(_read(data, 'detailPage.pricingSection.courseBrochure.body'), ''),
    );
    final paymentMethods = TextEditingController(
      text: _text(_read(data, 'detailPage.pricingSection.paymentMethods.body'), ''),
    );
    var enrolled =
        _int(_read(data, 'listingCard.statistics.stat1.value'), 1847);
    var sessions = _int(_read(data, 'listingCard.statistics.stat3.value'), 48);

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(doc == null ? 'Add Course' : 'Edit Course'),
          content: SizedBox(
            width: 900,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionTitle('Listing Card'),
                  TextField(controller: name, decoration: const InputDecoration(labelText: 'Course Name')),
                  TextField(controller: usName, decoration: const InputDecoration(labelText: 'US Localized Name')),
                  TextField(controller: tagline, decoration: const InputDecoration(labelText: 'Tagline')),
                  TextField(controller: tierLabel, decoration: const InputDecoration(labelText: 'Tier Label')),
                  TextField(controller: tags, decoration: const InputDecoration(labelText: 'Feature Tags (comma separated)')),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: cardColor, decoration: const InputDecoration(labelText: 'Card Background Hex'))),
                      const SizedBox(width: 10),
                      Expanded(child: TextField(controller: accentColor, decoration: const InputDecoration(labelText: 'Accent Hex'))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _numberField('Display Order', displayOrder, (v) => setState(() => displayOrder = v))),
                      Expanded(child: _numberField('Enrolled', enrolled, (v) => setState(() => enrolled = v))),
                      Expanded(child: _numberField('Live Sessions', sessions, (v) => setState(() => sessions = v))),
                    ],
                  ),
                  TextField(
                    controller: passRateController,
                    decoration: const InputDecoration(labelText: 'Pass Rate'),
                  ),
                  SwitchListTile(value: isActive, onChanged: (v) => setState(() => isActive = v), title: const Text('Active')),
                  SwitchListTile(value: isFeatured, onChanged: (v) => setState(() => isFeatured = v), title: const Text('Featured')),
                  const SizedBox(height: 12),
                  _SectionTitle('Pricing (INR) + Course Video'),
                  Row(
                    children: [
                      Expanded(
                        child: _numberField(
                          'INR Current',
                          inrCurrent,
                          (v) => setState(() => inrCurrent = v),
                        ),
                      ),
                      Expanded(
                        child: _numberField(
                          'INR Original',
                          inrOriginal,
                          (v) => setState(() => inrOriginal = v),
                        ),
                      ),
                    ],
                  ),
                  const Text(
                    'USD is auto-calculated from INR using the live exchange rate when you save.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  TextField(
                    controller: videoId,
                    decoration: const InputDecoration(
                      labelText: 'Course Detail YouTube Video ID or URL',
                    ),
                  ),
                  TextField(
                    controller: videoTitle,
                    decoration: const InputDecoration(
                      labelText: 'Course Detail Video Title',
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionTitle('Detail Sections'),
                  TextField(
                    controller: facultyName,
                    decoration: const InputDecoration(labelText: 'Faculty Name'),
                  ),
                  TextField(
                    controller: facultyRole,
                    decoration: const InputDecoration(labelText: 'Faculty Role'),
                  ),
                  TextField(
                    controller: usaHeadline,
                    decoration: const InputDecoration(labelText: 'USA Banner Headline'),
                  ),
                  TextField(
                    controller: usaDetail,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'USA Banner Detail'),
                  ),
                  TextField(
                    controller: features,
                    minLines: 4,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      labelText:
                          "What's Included: title | description | icon (emoji or icon name like videocam_outlined), one per line",
                    ),
                  ),
                  TextField(
                    controller: contentHtml,
                    minLines: 4,
                    maxLines: 12,
                    decoration: const InputDecoration(
                      labelText: 'Course Detail HTML (shown after What\'s Included)',
                    ),
                  ),
                  TextField(
                    controller: classVideos,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText:
                          'Class videos (2x2 grid): title | YouTube URL | duration, one per line (max 4)',
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _numberField(
                          'Coupon discount (USD)',
                          couponDiscountUsd,
                          (v) => setState(() => couponDiscountUsd = v),
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: couponCode,
                          decoration: const InputDecoration(
                            labelText: 'Coupon code (auto if empty)',
                          ),
                        ),
                      ),
                    ],
                  ),
                  TextField(
                    controller: enrollmentForm,
                    minLines: 2,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Fill Enrollment Form — HTML or text',
                    ),
                  ),
                  TextField(
                    controller: bankDetails,
                    minLines: 2,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Bank & Account Details — HTML or text',
                    ),
                  ),
                  TextField(
                    controller: courseBrochure,
                    minLines: 2,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Course Brochure — HTML or text',
                    ),
                  ),
                  TextField(
                    controller: paymentMethods,
                    minLines: 2,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Payment Methods — HTML or text',
                    ),
                  ),
                  TextField(
                    controller: curriculum,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Curriculum: subject | topics | months, one per line',
                    ),
                  ),
                  TextField(
                    controller: reviews,
                    minLines: 4,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      labelText:
                          'Course Reviews: initials | name | meta | stars | text | tag | visible(true/false)',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            AdminDialogSaveActions(
              dialogContext: ctx,
              savedMessage: 'Course saved.',
              onSave: () async {
                final id = doc?.id ?? _slug(name.text);
                final rate = await AdminExchangeRateService.fetchInrToUsdRate();
                final usdCurrent =
                    AdminExchangeRateService.inrToUsd(inrCurrent, rate);
                final usdOriginal =
                    AdminExchangeRateService.inrToUsd(inrOriginal, rate);
                final resolvedCoupon = couponCode.text.trim().isEmpty
                    ? _generatedCouponCode(id, couponDiscountUsd)
                    : couponCode.text.trim();
                final payload = _coursePayload(
                  id: id,
                  name: name.text,
                  usName: usName.text,
                  tagline: tagline.text,
                  tierLabel: tierLabel.text,
                  tags: tags.text,
                  cardColor: cardColor.text,
                  accentColor: accentColor.text,
                  displayOrder: displayOrder,
                  isActive: isActive,
                  isFeatured: isFeatured,
                  enrolled: enrolled,
                  passRate: passRateController.text,
                  sessions: sessions,
                  inrCurrent: inrCurrent,
                  inrOriginal: inrOriginal,
                  usdCurrent: usdCurrent,
                  usdOriginal: usdOriginal,
                  videoId: videoId.text,
                  videoTitle: videoTitle.text,
                  facultyName: facultyName.text,
                  facultyRole: facultyRole.text,
                  usaHeadline: usaHeadline.text,
                  usaDetail: usaDetail.text,
                  features: features.text,
                  contentHtml: contentHtml.text,
                  classVideos: classVideos.text,
                  couponCode: resolvedCoupon,
                  couponDiscountUsd: couponDiscountUsd,
                  enrollmentForm: enrollmentForm.text,
                  bankDetails: bankDetails.text,
                  courseBrochure: courseBrochure.text,
                  paymentMethods: paymentMethods.text,
                  curriculum: curriculum.text,
                  reviews: reviews.text,
                );
                await widget.courses.doc(id).set(payload, SetOptions(merge: true));
                return true;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _numberField(String label, int value, ValueChanged<int> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: TextFormField(
        initialValue: '$value',
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label),
        onChanged: (v) => onChanged(int.tryParse(v) ?? value),
      ),
    );
  }
}

class _PageSettingsTab extends StatelessWidget {
  const _PageSettingsTab({required this.settings});

  final DocumentReference<Map<String, dynamic>> settings;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: settings.snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? _defaultSettingsPayload();
        return _PageSettingsForm(settings: settings, data: data);
      },
    );
  }
}

class _PageSettingsForm extends StatefulWidget {
  const _PageSettingsForm({required this.settings, required this.data});

  final DocumentReference<Map<String, dynamic>> settings;
  final Map<String, dynamic> data;

  @override
  State<_PageSettingsForm> createState() => _PageSettingsFormState();
}

class _PageSettingsFormState extends State<_PageSettingsForm> {
  late final TextEditingController title;
  late final TextEditingController subtitle;
  late final TextEditingController bg;
  late final TextEditingController countLabel;
  late final TextEditingController videoId;
  late final TextEditingController videoTitle;
  late final TextEditingController videoDuration;
  bool count = true;
  bool videoVisible = true;

  @override
  void initState() {
    super.initState();
    final video = _map(widget.data['featuredVideoBlock']);
    title = TextEditingController(text: _text(widget.data['pageTitle'], 'Courses'));
    subtitle = TextEditingController(text: _text(widget.data['pageSubtitle'], 'NEET coaching for NRI students'));
    bg = TextEditingController(text: _text(widget.data['backgroundColor'], '#F5F4F0'));
    countLabel = TextEditingController(text: _text(widget.data['coursesCountLabel'], '{n} courses'));
    videoId = TextEditingController(text: _text(video['youtubeVideoId'], ''));
    videoTitle = TextEditingController(text: _text(video['videoTitle'], 'NEET 2027 - Complete Roadmap'));
    videoDuration = TextEditingController(text: _text(video['videoDuration'], '14 min'));
    count = widget.data['coursesCountVisible'] != false;
    videoVisible = video['isVisible'] != false;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionTitle('Global Page Config'),
        TextField(controller: title, decoration: const InputDecoration(labelText: 'Page Title')),
        TextField(controller: subtitle, decoration: const InputDecoration(labelText: 'Page Subtitle')),
        TextField(controller: bg, decoration: const InputDecoration(labelText: 'Background Color Hex')),
        TextField(controller: countLabel, decoration: const InputDecoration(labelText: 'Course Count Label Format')),
        SwitchListTile(value: count, onChanged: (v) => setState(() => count = v), title: const Text('Show Course Count Label')),
        const SizedBox(height: 12),
        _SectionTitle('Default Course Page Video'),
        SwitchListTile(value: videoVisible, onChanged: (v) => setState(() => videoVisible = v), title: const Text('Show Video Section')),
        TextField(controller: videoId, decoration: const InputDecoration(labelText: 'Default YouTube Video ID or URL')),
        TextField(controller: videoTitle, decoration: const InputDecoration(labelText: 'Default Video Title')),
        TextField(controller: videoDuration, decoration: const InputDecoration(labelText: 'Video Duration')),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: () async {
              await widget.settings.set({
                'pageTitle': title.text.trim(),
                'pageSubtitle': subtitle.text.trim(),
                'backgroundColor': bg.text.trim(),
                'headerBellVisible': false,
                'coursesCountVisible': count,
                'coursesCountLabel': countLabel.text.trim(),
                'featuredVideoBlock': {
                  'isVisible': videoVisible,
                  'youtubeVideoId': _extractYoutubeId(videoId.text.trim()),
                  'videoTitle': videoTitle.text.trim(),
                  'videoDuration': videoDuration.text.trim(),
                  'placeholderBg1': '#0F172A',
                  'placeholderBg2': '#1E3A8A',
                  'height': 170,
                },
                'updatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Course page settings saved.')),
                );
              }
            },
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save Settings'),
          ),
        ),
      ],
    );
  }
}

class _RequestTable extends StatelessWidget {
  const _RequestTable({required this.collection});

  final String collection;

  static const _statuses = [
    'New',
    'Contacted',
    'Demo Booked',
    'Enrolled',
    'Not Interested',
    'No Response',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              // No server orderBy: documents missing createdAt still appear; sort client-side.
              stream: FirestoreDb.instance
                  .collection(collection)
                  .limit(200)
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
                final rawDocs =
                    List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
                  snapshot.data?.docs ?? const [],
                )..sort(
                    (a, b) => _requestCreatedAt(b.data())
                        .compareTo(_requestCreatedAt(a.data())),
                  );
                if (rawDocs.isEmpty) {
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
                        dataRowMinHeight: 52,
                        dataRowMaxHeight: 88,
                        columns: const [
                          DataColumn(label: Text('Date')),
                          DataColumn(label: Text('Name')),
                          DataColumn(label: Text('Email')),
                          DataColumn(label: Text('Class')),
                          DataColumn(label: Text('Course')),
                          DataColumn(label: Text('Phone')),
                          DataColumn(label: Text('Status')),
                        ],
                        rows: rawDocs.map((doc) {
                          final data = doc.data();
                          final status = _text(data['status'], 'New');
                          final selectedStatus =
                              _statuses.contains(status) ? status : 'New';
                          final unread = data['isRead'] != true;
                          void markSeen() {
                            doc.reference.set({
                              'isRead': true,
                              'updatedAt': FieldValue.serverTimestamp(),
                            }, SetOptions(merge: true));
                          }

                          return DataRow(
                            cells: [
                              DataCell(
                                InkWell(
                                  onTap: markSeen,
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (unread)
                                          const Padding(
                                            padding: EdgeInsets.only(right: 6),
                                            child: CircleAvatar(
                                              radius: 4,
                                              backgroundColor:
                                                  Color(0xFFE53935),
                                            ),
                                          ),
                                        Text(_fmtRequestTs(data)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(Text(_text(data['userName'], '-'))),
                              DataCell(Text(_text(data['email'], '-'))),
                              DataCell(Text(_text(data['class'], '-'))),
                              DataCell(
                                SizedBox(
                                  width: 220,
                                  child: Text(
                                    _text(data['courseName'], '-'),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              DataCell(Text(_text(data['phone'], '-'))),
                              DataCell(
                                SizedBox(
                                  width: 160,
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      isDense: true,
                                      isExpanded: true,
                                      value: selectedStatus,
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
                                        doc.reference.set({
                                          'status': v,
                                          'isRead': true,
                                          'updatedAt':
                                              FieldValue.serverTimestamp(),
                                        }, SetOptions(merge: true));
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
    );
  }
}

String _fmtRequestTs(Map<String, dynamic> data) {
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

DateTime _requestCreatedAt(Map<String, dynamic> data) {
  final c = data['createdAt'];
  if (c is Timestamp) return c.toDate();
  final loc = data['createdAtLocal']?.toString();
  final p = loc != null ? DateTime.tryParse(loc) : null;
  if (p != null) return p;
  return DateTime.fromMillisecondsSinceEpoch(0);
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Chip(label: Text(label), visualDensity: VisualDensity.compact);
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
    );
  }
}

/// Web + Firestore interop often expects `Map<String, Object>`, while Dart map
/// literals are [LinkedMap<String, dynamic>] — a cast error at runtime. Deep-copy
/// to plain `Map<String, dynamic>` (preserving [FieldValue] / [Timestamp]).
Map<String, dynamic> _materializeFirestoreMap(Map<String, dynamic> source) {
  final out = _materializeFirestoreValue(source);
  return out as Map<String, dynamic>;
}

dynamic _materializeFirestoreValue(dynamic v) {
  if (v == null) return null;
  if (v is FieldValue || v is Timestamp) return v;
  if (v is Map) {
    final m = <String, dynamic>{};
    v.forEach((key, val) {
      m[key.toString()] = _materializeFirestoreValue(val);
    });
    return m;
  }
  if (v is List) {
    return v.map(_materializeFirestoreValue).toList();
  }
  return v;
}

Map<String, dynamic> _coursePayload({
  required String? id,
  required String name,
  required String usName,
  required String tagline,
  required String tierLabel,
  required String tags,
  required String cardColor,
  required String accentColor,
  required int displayOrder,
  required bool isActive,
  required bool isFeatured,
  required int enrolled,
  required String passRate,
  required int sessions,
  required int inrCurrent,
  required int inrOriginal,
  required int usdCurrent,
  required int usdOriginal,
  required String videoId,
  required String videoTitle,
  required String facultyName,
  required String facultyRole,
  required String usaHeadline,
  required String usaDetail,
  required String features,
  required String contentHtml,
  required String classVideos,
  required String couponCode,
  required int couponDiscountUsd,
  required String enrollmentForm,
  required String bankDetails,
  required String courseBrochure,
  required String paymentMethods,
  required String curriculum,
  required String reviews,
}) {
  return _materializeFirestoreMap(<String, dynamic>{
    if (id != null && id.trim().isNotEmpty) 'id': id.trim(),
    'meta': {
      'isActive': isActive,
      'isFeatured': isFeatured,
      'displayOrder': displayOrder,
    },
    'listingCard': {
      'naming': {
        'primaryName': name.trim(),
        'localizedNameUS': usName.trim(),
        'localizedNameME': '',
        'tagline': tagline.trim(),
        'tierLabel': tierLabel.trim(),
      },
      'badges': {
        'badge1Text': 'Class 12',
        'badge1Bg': '#334D8D',
        'badge1Color': '#BFDBFE',
        'badge2Text': isFeatured ? 'Most Popular' : '',
        'badge2Bg': '#544C31',
        'badge2Color': '#FCD34D',
        'badge3Text': '12 Months',
        'badge3Bg': '#214D45',
        'badge3Color': '#6EE7B7',
      },
      'cardVisual': {
        'cardBackground': cardColor.trim(),
        'accentColor': accentColor.trim(),
        'tagBg': '#334D8D',
        'tagTextColor': '#BFDBFE',
        'cornerBadgeText': isFeatured ? 'Most Popular' : '',
      },
      'tags': _split(tags),
      'statistics': {
        'stat1': {'value': enrolled, 'label': 'Enrolled'},
        'stat2': {'value': passRate.trim(), 'label': 'Pass Rate'},
        'stat3': {'value': sessions, 'label': 'Live Sessions'},
      },
    },
    'detailPage': {
      'heroSection': {
        'courseName': name.trim(),
        'courseAlt': tagline.trim(),
        'ratingScore': 4.7,
        'reviewCount': 312,
        'reviewLabel': 'verified reviews',
      },
      'heroPricing': {
        'inrOriginal': inrOriginal,
        'inrCurrent': inrCurrent,
        'usdOriginal': usdOriginal,
        'usdCurrent': usdCurrent,
        'discountPercent': inrOriginal <= 0
            ? 0
            : (((inrOriginal - inrCurrent) / inrOriginal) * 100).round(),
        'emiAvailable': false,
        'showCurrencyToggle': true,
      },
      'videoSection': {
        'isVisible': true,
        'youtubeVideoId': _extractYoutubeId(videoId.trim()),
        'videoTitle': videoTitle.trim(),
        'videoDuration': '14 min',
        'gradientStart': '#0F172A',
        'gradientEnd': cardColor.trim(),
      },
      'featuresSection': {'sectionTitle': "What's Included", 'items': _featureRows(features)},
      'contentSection': {
        'sectionTitle': 'Course Detail',
        'isVisible': contentHtml.trim().isNotEmpty,
        'html': contentHtml.trim(),
      },
      'classVideosSection': {
        'sectionTitle': 'Class Videos',
        'items': _classVideoRows(classVideos),
      },
      'pricingSection': {
        'sectionTitle': 'Pricing',
        'couponDiscountUsd': couponDiscountUsd,
        'couponLabel': 'USD $couponDiscountUsd off Coupon Code',
        'couponCode': couponCode.trim(),
        'enrollmentForm': {
          'title': 'Fill Enrollment Form',
          'body': enrollmentForm.trim(),
        },
        'bankDetails': {
          'title': 'Bank & Account Details',
          'body': bankDetails.trim(),
        },
        'courseBrochure': {
          'title': 'Course Brochure',
          'body': courseBrochure.trim(),
        },
        'paymentMethods': {
          'title': 'Payment Methods',
          'body': paymentMethods.trim(),
        },
      },
      'curriculumSection': {'sectionTitle': 'Curriculum', 'subjects': _subjectRows(curriculum)},
      'facultySection': {
        'facultyName': facultyName.trim(),
        'facultyInitials': _initials(facultyName),
        'facultyRole': facultyRole.trim(),
        'facultyExperience': '14 yrs experience - 2,400+ students mentored',
      },
      'usaBanner': {
        'isVisible': true,
        'headline': usaHeadline.trim(),
        'detailLine': usaDetail.trim(),
      },
      'reviewsSection': {
        'sectionTitle': 'Course Review',
        'overallScore': 4.7,
        'totalReviews': 312,
        'reviewCards': {'items': _reviewRows(reviews)},
      },
      'stickyFooter': {
        'bookDemoButton': {'label': 'Book Demo'},
        'inquireButton': {'label': 'Inquire'},
      },
    },
    'updatedAt': FieldValue.serverTimestamp(),
  });
}

Map<String, dynamic> _defaultCoursePayload() => _coursePayload(
      id: 'course_1yr_intensive',
      name: '1-Year NEET Intensive',
      usName: 'Grade 12 Intensive Program',
      tagline: 'Senior Year Pre-Med Track - 12 Months',
      tierLabel: 'Most Popular - Class 12',
      tags: 'Live Classes, 10 Mock Tests, Doubt Sessions, Study Material',
      cardColor: '#1E3A8A',
      accentColor: '#93C5FD',
      displayOrder: 1,
      isActive: true,
      isFeatured: true,
      enrolled: 1847,
      passRate: '94%',
      sessions: 48,
      inrCurrent: 49999,
      inrOriginal: 64999,
      usdCurrent: 599,
      usdOriginal: 779,
      videoId: '',
      videoTitle: 'Course Overview - Watch Before Enrolling',
      facultyName: 'Dr. Arun Kumar',
      facultyRole: 'Lead Faculty - Biology & NEET Strategy',
      usaHeadline: '187 students from USA',
      usaDetail:
          'Classes at 7PM EST / 4PM PST. Weekend batches available. NRI counselor on call.',
      features:
          'Live Classes | 48 sessions, recorded for replay | videocam_outlined\nStudy Material | NCERT notes + chapter PDFs | menu_book_outlined\n10 Mock Tests | Full NEET-pattern with AI analysis | quiz\nNRI Schedule | EST/PST timings + weekends | schedule',
      contentHtml: '',
      classVideos: '',
      couponCode: '',
      couponDiscountUsd: 100,
      enrollmentForm: '',
      bankDetails: '',
      courseBrochure: '',
      paymentMethods: '',
      curriculum:
          'Physics | Mechanics - Optics - Modern Physics | 4\nChemistry | Organic - Inorganic - Physical Chemistry | 4\nBiology | Botany - Zoology - Genetics - Ecology | 4',
      reviews:
          'RP | Riya Patel | Parent - New Jersey, USA | 5 | My daughter improved 40 marks in 2 months. | NRI Parent - Verified',
    );

List<Map<String, dynamic>> _seedCoreCourses() => [
      _defaultCoursePayload(),
      ..._remainingCoursePayloads(),
    ];

List<Map<String, dynamic>> _remainingCoursePayloads() => [
      _presetCoursePayload(
        id: 'course_2yr_program',
        name: '2-Year NEET Program',
        usName: 'Pre-Med 2-Year Track',
        meName: 'Class 11 & 12 NEET Program',
        tagline: 'Junior + Senior Year - Complete NEET Preparation',
        tierLabel: 'Best Value - Class 11',
        displayOrder: 2,
        isFeatured: true,
        cardColor: '#6D28D9',
        accentColor: '#C4B5FD',
        tagTextColor: '#DDD6FE',
        cornerBadge: 'Best Value',
        badge1: 'Class 11',
        badge2: 'Best Value',
        badge3: '24 Months',
        tags: ['Live + Recorded', '20 Mock Tests', 'Doubt Sessions', 'NRI Friendly'],
        enrolled: 1243,
        passRate: '97%',
        stat3: 96,
        stat3Label: 'Sessions',
        inrCurrent: 84999,
        inrOriginal: 109999,
        usdCurrent: 999,
        usdOriginal: 1299,
        discountLabel: 'Combo Savings',
        emiMonths: 12,
        videoTitle: '2-Year Program - Full Walkthrough',
        videoDuration: '18 min',
        gradientStart: '#1A0A2E',
        facultyName: 'Dr. Sunita Rao',
        facultyRole: 'Lead Faculty - Chemistry & NEET Mentoring',
        usaHeadline: '234 students from USA',
        usaDetail:
            'Classes at 7PM EST / 4PM PST. 2-year structured batches. Dedicated NRI mentor assigned.',
        features:
            'Live + Recorded | 96 live sessions + full recorded library for 2 years\nFull Syllabus | Complete Class 11 + 12 NCERT coverage\n20 Mock Tests | NEET-pattern mocks across both years\nMonthly Reports | Parent progress reports every month\nDoubt Sessions | Weekly live Q&A + dedicated doubt chat\nNRI Mentor | Personal mentor assigned - US timezone',
        curriculum:
            'Physics | Mechanics - Thermodynamics - Electrostatics - Optics | 8\nChemistry | Physical - Organic - Inorganic Chemistry | 8\nBiology | Botany - Zoology - Genetics - Human Physiology | 8',
        reviews:
            'KP | Kavitha Pillai | Parent - Chicago, USA - Class 11 | 5 | Starting in Class 11 was the best decision. The 2-year structure ensures nothing is rushed. | NRI Parent - Verified\nRM | Rohan Mehta | Student - Florida, USA - Scored 630/720 | 5 | Two years felt short because every month had a clear plan. | Qualified NEET 2025 - Verified',
      ),
      _presetCoursePayload(
        id: 'course_foundation',
        name: 'NEET Foundation',
        usName: 'Pre-Med Foundation Track',
        meName: 'NEET Foundation Program',
        tagline: 'Middle School to High School - Grades 9 & 10',
        tierLabel: 'Early Start - Class 9 & 10',
        displayOrder: 3,
        isFeatured: false,
        cardColor: '#065F46',
        accentColor: '#6EE7B7',
        tagTextColor: '#A7F3D0',
        cornerBadge: '',
        badge1: 'Class 9 & 10',
        badge2: 'Early Start',
        badge3: '2 Years',
        tags: ['Concept Building', 'NCERT Focus', 'Regular Tests', 'Science Basics'],
        enrolled: 867,
        passRate: '89%',
        stat3: 72,
        stat3Label: 'Sessions',
        inrCurrent: 39999,
        inrOriginal: 49999,
        usdCurrent: 479,
        usdOriginal: 599,
        discountLabel: 'Foundation Offer',
        emiMonths: 12,
        videoTitle: 'Why Start NEET Prep in Grade 9?',
        videoDuration: '11 min',
        gradientStart: '#022C22',
        facultyName: 'Ms. Priya Menon',
        facultyRole: 'Lead Faculty - Foundation Science & Biology',
        usaHeadline: '142 students from USA',
        usaDetail:
            'Weekend batches at 10AM EST. Grade 9 & 10 friendly pace. Build the base before the race.',
        features:
            'Concept Building | Deep Science concepts from Grade 9 NCERT\nNCERT Focus | Complete Class 9 & 10 Science + Math\nChapter Tests | Monthly chapter tests to track progress\nParent Reports | Monthly progress reports sent to parents\nNEET Roadmap | Clear path from Grade 9 to NEET qualification\nWeekend Batches | US-friendly weekend scheduling available',
        curriculum:
            'Physics | Motion - Force - Light - Electricity - Energy | 8\nChemistry | Matter - Atoms - Acids & Bases - Carbon Compounds | 7\nBiology | Life Processes - Control - Reproduction - Environment | 9',
        reviews:
            'TR | Tanya Reddy | Parent - Georgia, USA - Class 9 | 5 | We enrolled our daughter in Grade 9 and the difference is clear. | NRI Parent - Verified\nNK | Nikhil Kumar | Student - Texas, USA - Moving to Class 11 prep | 5 | The foundation program made Class 11 feel easy. | Advanced to 2-Year Program - Verified',
      ),
      _presetCoursePayload(
        id: 'course_crash',
        name: 'NEET Crash Course',
        usName: '90-Day NEET Exam Sprint',
        meName: 'NEET Final Preparation Bootcamp',
        tagline: 'Fast Track - Final Exam Bootcamp',
        tierLabel: 'Fast Track - Class 12',
        displayOrder: 4,
        isFeatured: true,
        cardColor: '#9A3412',
        accentColor: '#FCD34D',
        tagTextColor: '#FDE68A',
        cornerBadge: 'High Demand',
        badge1: 'Class 12',
        badge2: 'High Demand',
        badge3: '90 Days',
        tags: ['Daily Intensive', '6 Full Mocks', 'Past Papers', 'Revision Focus'],
        enrolled: 2134,
        passRate: '91%',
        stat3: 90,
        stat3Label: 'Days',
        inrCurrent: 19999,
        inrOriginal: 24999,
        usdCurrent: 239,
        usdOriginal: 299,
        discountLabel: 'Season Discount',
        emiMonths: 0,
        videoTitle: '90 Days to NEET - How the Sprint Works',
        videoDuration: '9 min',
        gradientStart: '#431407',
        facultyName: 'Mr. Rajesh Iyer',
        facultyRole: 'Lead Faculty - Physics & Exam Strategy',
        usaHeadline: '267 students from USA',
        usaDetail:
            'Evening sprint sessions at 7:30PM EST. Mock tests on weekends. Perfect for exam-year students.',
        features:
            'Daily Sessions | 90 days of intensive daily 2-hr sessions\n6 Full Mock Tests | NEET-pattern timed mocks every 2 weeks\nPast 10-Year Papers | Complete solved papers from 2014-2024\nScore Analytics | Track score improvement week by week\nRapid Revision PDFs | Chapter-wise flash cards and formula sheets\nUS Evening Batches | 7:30PM EST - Weekend mocks included',
        curriculum:
            'Physics - High Yield | Electrostatics - Modern Physics - Optics - Mechanics | 1\nChemistry - High Yield | Organic Reactions - Coordination - Electrochemistry | 1\nBiology - High Yield | Genetics - Human Physiology - Ecology - Reproduction | 1',
        reviews:
            'SA | Smita Agarwal | Parent - California, USA - Class 12 | 5 | The 90-day structure with daily accountability changed everything. | NRI Parent - Verified\nVT | Vivek Thakur | Student - New York, USA - Scored 610/720 | 5 | I joined 90 days before the exam. The focus on high-yield topics and 6 mocks was exactly what I needed. | Qualified NEET 2025 - Verified',
      ),
      _presetCoursePayload(
        id: 'course_test_series',
        name: 'NEET Test Series Plan',
        usName: 'NEET Mock Test Subscription',
        meName: 'NEET Practice Test Series',
        tagline: 'Practice & Assess - Class 11 & 12',
        tierLabel: 'Practice Plan - Class 11 & 12',
        displayOrder: 5,
        isFeatured: false,
        cardColor: '#0E7490',
        accentColor: '#67E8F9',
        tagTextColor: '#A5F3FC',
        cornerBadge: '',
        badge1: 'Class 11 & 12',
        badge2: 'Anytime Access',
        badge3: '12 Months',
        tags: ['30 Mock Tests', 'Chapter Tests', 'AI Analysis', 'Score Trends'],
        enrolled: 3456,
        passRate: '88%',
        stat3: 24000,
        stat3Label: 'Tests Taken',
        inrCurrent: 8999,
        inrOriginal: 11999,
        usdCurrent: 109,
        usdOriginal: 144,
        discountLabel: 'Annual Plan',
        emiMonths: 0,
        videoTitle: 'How Our Test Series Prepares You for NEET',
        videoDuration: '7 min',
        gradientStart: '#083344',
        facultyName: 'Dr. Vikram Sinha',
        facultyRole: 'Head of Assessments - NEET Test Design',
        usaHeadline: '198 students from USA',
        usaDetail:
            'Attempt tests anytime - no fixed schedule. Perfect for NRI students with busy school timetables.',
        features:
            '30 Full Mocks | NEET-pattern 180-question timed tests\nAI Weak Area Alert | AI detects and flags your weak chapters\nScore Trend Graph | Track improvement over every test attempt\nNational Percentile | See where you rank among all NEET aspirants\n200+ Chapter Tests | Subject and chapter-wise practice tests\nAttempt Anytime | No fixed schedule - attempt at your own pace',
        curriculum:
            'Physics | All Class 11 + 12 chapters - 10 mocks - 60+ chapter tests | 12\nChemistry | All Class 11 + 12 chapters - 10 mocks - 80+ chapter tests | 12\nBiology | All Class 11 + 12 chapters - 10 mocks - 120+ chapter tests | 12',
        reviews:
            'AV | Ananya Verma | Student - New Jersey, USA - Class 12 | 5 | The AI weak area detection is genuinely useful. My score jumped 55 points in 6 weeks. | Active Subscriber - Verified\nKM | Kiran Malhotra | Parent - Virginia, USA - Class 11 | 4 | No fixed schedule is a blessing for us. | NRI Parent - Verified',
      ),
    ];

Map<String, dynamic> _presetCoursePayload({
  required String id,
  required String name,
  required String usName,
  required String meName,
  required String tagline,
  required String tierLabel,
  required int displayOrder,
  required bool isFeatured,
  required String cardColor,
  required String accentColor,
  required String tagTextColor,
  required String cornerBadge,
  required String badge1,
  required String badge2,
  required String badge3,
  required List<String> tags,
  required int enrolled,
  required String passRate,
  required int stat3,
  required String stat3Label,
  required int inrCurrent,
  required int inrOriginal,
  required int usdCurrent,
  required int usdOriginal,
  required String discountLabel,
  required int emiMonths,
  required String videoTitle,
  required String videoDuration,
  required String gradientStart,
  required String facultyName,
  required String facultyRole,
  required String usaHeadline,
  required String usaDetail,
  required String features,
  required String curriculum,
  required String reviews,
}) {
  final payload = _coursePayload(
    id: id,
    name: name,
    usName: usName,
    tagline: tagline,
    tierLabel: tierLabel,
    tags: tags.join(', '),
    cardColor: cardColor,
    accentColor: accentColor,
    displayOrder: displayOrder,
    isActive: true,
    isFeatured: isFeatured,
    enrolled: enrolled,
    passRate: passRate,
    sessions: stat3,
    inrCurrent: inrCurrent,
    inrOriginal: inrOriginal,
    usdCurrent: usdCurrent,
    usdOriginal: usdOriginal,
    videoId: '',
    videoTitle: videoTitle,
    facultyName: facultyName,
    facultyRole: facultyRole,
    usaHeadline: usaHeadline,
    usaDetail: usaDetail,
    features: features,
    contentHtml: '',
    classVideos: '',
    couponCode: '',
    couponDiscountUsd: 100,
    enrollmentForm: '',
    bankDetails: '',
    courseBrochure: '',
    paymentMethods: '',
    curriculum: curriculum,
    reviews: reviews,
  );
  payload['listingCard']['naming']['localizedNameME'] = meName;
  payload['listingCard']['badges'] = {
    'badge1Text': badge1,
    'badge1Bg': 'rgba(255,255,255,0.18)',
    'badge1Color': tagTextColor,
    'badge2Text': badge2,
    'badge2Bg': 'rgba(255,255,255,0.18)',
    'badge2Color': tagTextColor,
    'badge3Text': badge3,
    'badge3Bg': 'rgba(255,255,255,0.18)',
    'badge3Color': tagTextColor,
  };
  payload['listingCard']['cardVisual']['tagTextColor'] = tagTextColor;
  payload['listingCard']['cardVisual']['cornerBadgeText'] = cornerBadge;
  payload['listingCard']['statistics']['stat3']['label'] = stat3Label;
  payload['detailPage']['heroPricing']['discountLabel'] = discountLabel;
  payload['detailPage']['heroPricing']['emiAvailable'] = false;
  final dp = payload['detailPage'];
  if (dp is Map) {
    final hpRaw = dp['heroPricing'];
    if (hpRaw is Map) {
      final hp = Map<String, dynamic>.from(hpRaw);
      hp.remove('emiMonths');
      hp.remove('emiAmountINR');
      hp.remove('emiAmountUSD');
      dp['heroPricing'] = hp;
    }
  }
  payload['detailPage']['videoSection']['videoDuration'] = videoDuration;
  payload['detailPage']['videoSection']['gradientStart'] = gradientStart;
  payload['detailPage']['reviewsSection']['sectionTitle'] = 'Course Review';
  payload['detailPage']['stickyFooter']['bookDemoButton']['bg'] = cardColor;
  payload['detailPage']['stickyFooter']['inquireButton']['textColor'] = cardColor;
  return _materializeFirestoreMap(payload);
}

Map<String, dynamic> _defaultSettingsPayload() => {
      'pageTitle': 'Courses',
      'pageSubtitle': 'NEET coaching for NRI students',
      'backgroundColor': '#F5F4F0',
      'headerBellVisible': false,
      'coursesCountVisible': true,
      'coursesCountLabel': '{n} courses',
      'featuredVideoBlock': {
        'isVisible': true,
        'youtubeVideoId': '',
        'videoTitle': 'NEET 2027 - Complete Roadmap',
        'videoDuration': '14 min',
        'placeholderBg1': '#0F172A',
        'placeholderBg2': '#1E3A8A',
        'height': 170,
      },
    };

/// Removes null leaves so Firestore web SDK never receives `null` (JS interop:
/// `null` is not an [Object] in some paths). Keeps [FieldValue] and [Timestamp].
/// Uses [Map<dynamic, dynamic>.from] so JS-backed maps from web iterate safely.
Map<String, dynamic> _stripNullValuesFromMap(Map<String, dynamic> input) {
  final out = <String, dynamic>{};
  Map<dynamic, dynamic>.from(input).forEach((k, v) {
    if (k == null || v == null) return;
    final stripped = _stripNullDeep(v);
    if (stripped != null) out[k.toString()] = stripped;
  });
  return out;
}

dynamic _stripNullDeep(dynamic v) {
  if (v == null) return null;
  if (v is FieldValue || v is Timestamp) return v;
  if (v is Map) {
    final m = <String, dynamic>{};
    Map<dynamic, dynamic>.from(v).forEach((key, val) {
      if (key == null || val == null) return;
      final s = _stripNullDeep(val);
      if (s != null) m[key.toString()] = s;
    });
    return m;
  }
  if (v is List) {
    return v.map(_stripNullDeep).where((e) => e != null).toList();
  }
  return v;
}

Object? _read(Map<String, dynamic> data, String path) {
  Object? current = data;
  for (final part in path.split('.')) {
    if (current is Map) {
      current = current[part];
    } else {
      return null;
    }
  }
  if (current is Map && current.containsKey('value')) return current['value'];
  return current;
}

Map<String, dynamic> _map(Object? raw) =>
    raw is Map ? Map<String, dynamic>.from(raw) : {};

String _text(Object? raw, String fallback) {
  final text = raw?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

int _int(Object? raw, int fallback) {
  if (raw is num) return raw.toInt();
  return int.tryParse(raw?.toString() ?? '') ?? fallback;
}

/// Client-side sort key so courses without `meta.displayOrder` still list in Firestore.
int _courseDisplayOrder(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
  final meta = doc.data()['meta'];
  if (meta is Map<String, dynamic>) {
    return _int(meta['displayOrder'], 999);
  }
  return 999;
}

List<String> _list(Object? raw) =>
    raw is List ? raw.map((e) => e.toString()).toList() : const [];

List<String> _split(String raw) =>
    raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

List<Map<String, dynamic>> _featureRows(String raw) => raw
    .split('\n')
    .where((line) => line.trim().isNotEmpty)
    .map((line) {
      final parts = line.split('|').map((e) => e.trim()).toList();
      return {
        'title': parts.isNotEmpty ? parts[0] : '',
        'description': parts.length > 1 ? parts[1] : '',
        'icon': parts.length > 2 ? parts[2] : '',
      };
    }).toList();

List<Map<String, dynamic>> _classVideoRows(String raw) => raw
    .split('\n')
    .where((line) => line.trim().isNotEmpty)
    .map((line) {
      final parts = line.split('|').map((e) => e.trim()).toList();
      return {
        'title': parts.isNotEmpty ? parts[0] : 'Class video',
        'url': parts.length > 1 ? parts[1] : '',
        'duration': parts.length > 2 ? parts[2] : '3 min',
      };
    })
    .take(4)
    .toList();

String _classVideosText(Object? raw) {
  if (raw is! List) return '';
  return raw.map((item) {
    final map = _map(item);
    return '${_text(map['title'], '')} | ${_text(map['url'] ?? map['videoUrl'], '')} | ${_text(map['duration'], '3 min')}';
  }).join('\n');
}

String _generatedCouponCode(String courseId, int discountUsd) {
  final slug = courseId.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
  final core = slug.isEmpty
      ? 'NEET'
      : (slug.length <= 8 ? slug : slug.substring(0, 8));
  return 'TPK$core$discountUsd';
}

String _extractYoutubeId(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return '';
  final uri = Uri.tryParse(value);
  if (uri != null && uri.host.isNotEmpty) {
    if (uri.host.contains('youtu.be')) {
      return uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
    }
    if (uri.host.contains('youtube.com')) {
      final queryId = uri.queryParameters['v'];
      if (queryId != null && queryId.trim().isNotEmpty) return queryId.trim();
      final embedIndex = uri.pathSegments.indexOf('embed');
      if (embedIndex >= 0 && uri.pathSegments.length > embedIndex + 1) {
        return uri.pathSegments[embedIndex + 1];
      }
      final shortsIndex = uri.pathSegments.indexOf('shorts');
      if (shortsIndex >= 0 && uri.pathSegments.length > shortsIndex + 1) {
        return uri.pathSegments[shortsIndex + 1];
      }
    }
  }
  return value.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '').trim();
}

List<Map<String, dynamic>> _subjectRows(String raw) => raw
    .split('\n')
    .where((line) => line.trim().isNotEmpty)
    .map((line) {
      final parts = line.split('|').map((e) => e.trim()).toList();
      return {
        'name': parts.isNotEmpty ? parts[0] : '',
        'topics': parts.length > 1 ? parts[1] : '',
        'months': parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0,
      };
    }).toList();

List<Map<String, dynamic>> _reviewRows(String raw) => raw
    .split('\n')
    .where((line) => line.trim().isNotEmpty)
    .map((line) {
      final parts = line.split('|').map((e) => e.trim()).toList();
      return {
        'initials': parts.isNotEmpty ? parts[0] : 'TP',
        'name': parts.length > 1 ? parts[1] : '',
        'meta': parts.length > 2 ? parts[2] : '',
        'stars': parts.length > 3 ? int.tryParse(parts[3]) ?? 5 : 5,
        'reviewText': parts.length > 4 ? parts[4] : '',
        'tag': parts.length > 5 ? parts[5] : '',
        'isVisible': parts.length > 6
            ? parts[6].toLowerCase() != 'false'
            : true,
      };
    }).toList();

String _itemsText(Object? raw) {
  if (raw is! List) return '';
  return raw.map((item) {
    final map = _map(item);
    return '${_text(map['title'], '')} | ${_text(map['description'], '')} | ${_text(map['icon'], '')}';
  }).join('\n');
}

String _subjectsText(Object? raw) {
  if (raw is! List) return '';
  return raw.map((item) {
    final map = _map(item);
    return '${_text(map['name'], '')} | ${_text(map['topics'], '')} | ${_text(map['months'], '0')}';
  }).join('\n');
}

String _reviewsText(Object? raw) {
  if (raw is! List) return '';
  return raw.map((item) {
    final map = _map(item);
    return '${_text(map['initials'], '')} | ${_text(map['name'], '')} | ${_text(map['meta'], '')} | ${_text(map['stars'], '5')} | ${_text(map['reviewText'], '')} | ${_text(map['tag'], '')} | ${_text(map['isVisible'], 'true')}';
  }).join('\n');
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
  return parts.take(2).map((e) => e[0].toUpperCase()).join();
}

String _slug(String name) {
  final slug = name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  return slug.isEmpty ? 'course_${DateTime.now().millisecondsSinceEpoch}' : slug;
}
