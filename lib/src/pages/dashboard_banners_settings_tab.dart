import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../constants/dashboard_banner_targets.dart';
import '../services/firestore_db.dart';
import '../widgets/admin_cors_network_image.dart';

/// Settings tab: home dashboard promo carousel (up to 5 banners).
class DashboardBannersSettingsTab extends StatefulWidget {
  const DashboardBannersSettingsTab({super.key});

  @override
  State<DashboardBannersSettingsTab> createState() =>
      _DashboardBannersSettingsTabState();
}

class _DashboardBannersSettingsTabState extends State<DashboardBannersSettingsTab> {
  static const _slotCount = 5;

  final _doc =
      FirestoreDb.instance.collection('cms_dashboard').doc('main');

  bool _seedAttempted = false;
  bool _enabled = false;
  bool _saving = false;
  /// True after user edits a field; avoids Firestore snapshot overwriting in-progress edits.
  bool _formDirty = false;
  /// True once we applied empty-doc samples (no cms_dashboard/main yet).
  bool _appliedEmptyDocSamples = false;
  String? _hydratedFingerprint;
  bool _initialLoadDone = false;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _firestoreSub;
  final _widthCtrl = TextEditingController(text: '1200');
  final _heightCtrl = TextEditingController(text: '480');
  final _intervalCtrl = TextEditingController(text: '5');

  late final List<_BannerSlot> _slots = List.generate(
    _slotCount,
    (i) => _BannerSlot(index: i + 1),
  );

  @override
  void initState() {
    super.initState();
    _firestoreSub = _doc.snapshots().listen(
      _onFirestoreSnapshot,
      onError: (_) {
        if (!mounted) return;
        setState(() => _initialLoadDone = true);
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureFirestoreSeed());
  }

  @override
  void dispose() {
    _firestoreSub?.cancel();
    _widthCtrl.dispose();
    _heightCtrl.dispose();
    _intervalCtrl.dispose();
    for (final slot in _slots) {
      slot.dispose();
    }
    super.dispose();
  }

  void _markDirty() {
    if (!_formDirty) setState(() => _formDirty = true);
  }

  void _hydrateFromFirestore(Map<String, dynamic> data) {
    _enabled = data['enabled'] == true;
    _widthCtrl.text = '${(data['designWidthPx'] as num?)?.toInt() ?? 1200}';
    _heightCtrl.text = '${(data['designHeightPx'] as num?)?.toInt() ?? 480}';
    _intervalCtrl.text =
        '${(data['autoScrollIntervalSeconds'] as num?)?.toInt() ?? 5}';

    final raw = data['banners'];
    final byId = <String, Map<String, dynamic>>{};
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          final map = item.map((k, v) => MapEntry(k.toString(), v));
          final id = map['id']?.toString() ?? '';
          if (id.isNotEmpty) byId[id] = map;
        }
      }
    }
    for (final slot in _slots) {
      slot.imageUrl.clear();
      slot.linkUrl.clear();
      slot.landingTitle.clear();
      slot.landingBody.clear();
      slot.landingCtaLabel.clear();
      slot.landingCtaUrl.clear();
      slot.linkKind = BannerLinkKind.none;
      slot.appRoute = '';
      slot.landingCtaLinkKind = BannerLinkKind.none;
      slot.landingCtaAppRoute = '';
      slot.published = false;
    }
    for (final slot in _slots) {
      final map = byId[slot.id];
      if (map != null) _applyBannerMapToSlot(slot, map);
    }
    _formDirty = false;
  }

  void _onFirestoreSnapshot(DocumentSnapshot<Map<String, dynamic>> snap) {
    if (!mounted) return;
    if (_formDirty) {
      if (!_initialLoadDone) {
        setState(() => _initialLoadDone = true);
      }
      return;
    }

    if (snap.exists) {
      _appliedEmptyDocSamples = false;
      final data = snap.data() ?? const <String, dynamic>{};
      final fingerprint = jsonEncode({
        'enabled': data['enabled'],
        'designWidthPx': data['designWidthPx'],
        'designHeightPx': data['designHeightPx'],
        'autoScrollIntervalSeconds': data['autoScrollIntervalSeconds'],
        'banners': data['banners'],
      });
      if (fingerprint == _hydratedFingerprint) {
        if (!_initialLoadDone) {
          setState(() => _initialLoadDone = true);
        }
        return;
      }
      _hydratedFingerprint = fingerprint;
      setState(() {
        _hydrateFromFirestore(data);
        _initialLoadDone = true;
      });
      return;
    }

    if (!_appliedEmptyDocSamples) {
      _appliedEmptyDocSamples = true;
      _hydratedFingerprint = null;
      setState(() {
        _applySampleToForm();
        _formDirty = false;
        _initialLoadDone = true;
      });
      return;
    }

    if (!_initialLoadDone) {
      setState(() => _initialLoadDone = true);
    }
  }

  void _applyBannerMapToSlot(_BannerSlot slot, Map<String, dynamic> map) {
    slot.imageUrl.text = map['imageUrl']?.toString() ?? '';
    slot.published = map['isPublished'] != false;
    slot.landingTitle.text = map['landingTitle']?.toString() ?? '';
    slot.landingBody.text = map['landingBody']?.toString() ?? '';
    slot.landingCtaLabel.text = map['landingCtaLabel']?.toString() ?? '';
    final linkType = map['linkType']?.toString() ?? '';
    final appRoute = map['appRoute']?.toString().trim() ?? '';
    final linkUrl = map['linkUrl']?.toString().trim() ?? '';
    slot.linkKind = _parseBannerLinkKind(linkType, linkUrl: linkUrl, appRoute: appRoute);
    if (slot.linkKind == BannerLinkKind.external) {
      slot.linkUrl.text = linkUrl;
      slot.appRoute = '';
    } else if (slot.linkKind == BannerLinkKind.app) {
      slot.appRoute = appRoute;
      slot.linkUrl.clear();
    } else {
      slot.linkUrl.clear();
      slot.appRoute = '';
    }
    final ctaType = map['landingCtaLinkType']?.toString() ?? '';
    final ctaUrl = map['landingCtaUrl']?.toString().trim() ?? '';
    final ctaRoute = map['landingCtaAppRoute']?.toString().trim() ?? '';
    slot.landingCtaLinkKind =
        _parseBannerLinkKind(ctaType, linkUrl: ctaUrl, appRoute: ctaRoute);
    slot.landingCtaUrl.text = ctaUrl;
    slot.landingCtaAppRoute = ctaRoute;
  }

  BannerLinkKind _parseBannerLinkKind(
    String linkType, {
    required String linkUrl,
    required String appRoute,
  }) {
    if (linkType == 'landing') return BannerLinkKind.landing;
    if (linkType == 'app' && appRoute.isNotEmpty) return BannerLinkKind.app;
    if (linkType == 'external' ||
        (linkUrl.isNotEmpty && linkType != 'app' && linkType != 'landing')) {
      return BannerLinkKind.external;
    }
    return BannerLinkKind.none;
  }

  void _applySampleToForm() {
    _enabled = true;
    _widthCtrl.text = '1200';
    _heightCtrl.text = '480';
    _intervalCtrl.text = '5';
    final samples = _sampleBannerMaps();
    for (var i = 0; i < _slots.length; i++) {
      _applyBannerMapToSlot(_slots[i], samples[i]);
    }
  }

  static List<Map<String, dynamic>> _sampleBannerMaps() => [
        {
          'id': 'banner_1',
          'imageUrl':
              'https://placehold.co/1200x480/5B4FE8/FFFFFF/png?text=Plan+Your+NEET+Journey',
          'linkType': 'external',
          'linkUrl': 'https://www.testprepkart.com',
          'order': 1,
          'isPublished': true,
        },
        {
          'id': 'banner_2',
          'imageUrl':
              'https://placehold.co/1200x480/2563EB/FFFFFF/png?text=Book+Expected+Score+Demo',
          'linkType': 'app',
          'appRoute': 'expected_score',
          'order': 2,
          'isPublished': true,
        },
        {
          'id': 'banner_3',
          'imageUrl':
              'https://placehold.co/1200x480/0891B2/FFFFFF/png?text=Explore+Content+Library',
          'linkType': 'app',
          'appRoute': 'content_library',
          'order': 3,
          'isPublished': true,
        },
        {
          'id': 'banner_4',
          'imageUrl':
              'https://placehold.co/1200x480/EA580C/FFFFFF/png?text=NRI+Admission+Guidance',
          'linkType': 'external',
          'linkUrl': 'https://www.testprepkart.com',
          'order': 4,
          'isPublished': true,
        },
        {
          'id': 'banner_5',
          'imageUrl':
              'https://placehold.co/1200x480/7C3AED/FFFFFF/png?text=Unlock+Premium+Prep',
          'linkType': 'none',
          'order': 5,
          'isPublished': true,
        },
      ];

  Future<void> _ensureFirestoreSeed() async {
    if (_seedAttempted) return;
    _seedAttempted = true;
    try {
      final snap = await _doc.get();
      if (snap.exists) return;
      await _publishSamplePlaceholders(silent: true);
    } catch (_) {}
  }

  Future<void> _publishSamplePlaceholders({bool silent = false}) async {
    setState(() => _saving = true);
    try {
      _applySampleToForm();
      await _doc.set({
        ..._sampleFirestorePayload(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _formDirty = false;
      if (!mounted) return;
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sample banners published')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not publish samples: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Map<String, dynamic> _sampleFirestorePayload() => {
        'enabled': true,
        'designWidthPx': 1200,
        'designHeightPx': 480,
        'autoScrollIntervalSeconds': 5,
        'banners': _sampleBannerMaps(),
      };

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final width = int.tryParse(_widthCtrl.text.trim()) ?? 1200;
      final height = int.tryParse(_heightCtrl.text.trim()) ?? 480;
      final interval = int.tryParse(_intervalCtrl.text.trim()) ?? 5;
      final banners = <Map<String, dynamic>>[];
      for (final slot in _slots) {
        final map = <String, dynamic>{
          'id': slot.id,
          'imageUrl': slot.imageUrl.text.trim(),
          'linkType': switch (slot.linkKind) {
            BannerLinkKind.none => 'none',
            BannerLinkKind.external => 'external',
            BannerLinkKind.app => 'app',
            BannerLinkKind.landing => 'landing',
          },
          'order': slot.index,
          'isPublished': slot.published,
        };
        if (slot.linkKind == BannerLinkKind.external) {
          map['linkUrl'] = slot.linkUrl.text.trim();
        }
        if (slot.linkKind == BannerLinkKind.app && slot.appRoute.isNotEmpty) {
          map['appRoute'] = slot.appRoute;
        }
        if (slot.linkKind == BannerLinkKind.landing) {
          final title = slot.landingTitle.text.trim();
          final body = slot.landingBody.text.trim();
          if (title.isNotEmpty) map['landingTitle'] = title;
          if (body.isNotEmpty) map['landingBody'] = body;
          final ctaLabel = slot.landingCtaLabel.text.trim();
          if (ctaLabel.isNotEmpty) map['landingCtaLabel'] = ctaLabel;
          if (slot.landingCtaLinkKind != BannerLinkKind.none) {
            map['landingCtaLinkType'] = switch (slot.landingCtaLinkKind) {
              BannerLinkKind.none => 'none',
              BannerLinkKind.external => 'external',
              BannerLinkKind.app => 'app',
              BannerLinkKind.landing => 'landing',
            };
          }
          if (slot.landingCtaLinkKind == BannerLinkKind.external) {
            map['landingCtaUrl'] = slot.landingCtaUrl.text.trim();
          }
          if (slot.landingCtaLinkKind == BannerLinkKind.app &&
              slot.landingCtaAppRoute.isNotEmpty) {
            map['landingCtaAppRoute'] = slot.landingCtaAppRoute;
          }
        }
        banners.add(map);
      }
      await _doc.set({
        'enabled': _enabled,
        'designWidthPx': width.clamp(320, 4000),
        'designHeightPx': height.clamp(120, 2000),
        'autoScrollIntervalSeconds': interval.clamp(3, 30),
        'banners': banners,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      setState(() {
        _formDirty = false;
        _hydratedFingerprint = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dashboard banners published')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialLoadDone) {
      return const Center(child: CircularProgressIndicator());
    }

    final aspect = _aspectLabel();
    return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Home dashboard banners',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Up to 5 promo images for the mobile home screen carousel. '
              'Upload images to your CDN or Firebase Storage, then paste HTTPS URLs. '
              'Each banner can open a website or an in-app screen. Stored at cms_dashboard/main.',
              style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.4),
            ),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Show carousel on app',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Switch(
                          value: _enabled,
                          onChanged: (v) {
                            setState(() => _enabled = v);
                            _markDirty();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _widthCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Design width (px)',
                              border: OutlineInputBorder(),
                              helperText: 'Upload assets at this width',
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (_) {
                              setState(() {});
                              _markDirty();
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _heightCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Design height (px)',
                              border: OutlineInputBorder(),
                              helperText: 'Upload assets at this height',
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (_) {
                              setState(() {});
                              _markDirty();
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Recommended aspect ratio: $aspect. The app scales banners to full width while keeping this ratio.',
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _intervalCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Auto-scroll interval (seconds)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _markDirty(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            ..._slots.map(_bannerCard),
            const SizedBox(height: 16),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _saving ? null : () => _publishSamplePlaceholders(),
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: const Text('Load sample placeholders'),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.publish_outlined),
                  label: Text(_saving ? 'Publishing…' : 'Publish banners'),
                ),
              ],
            ),
          ],
        );
  }

  String _aspectLabel() {
    final w = int.tryParse(_widthCtrl.text.trim()) ?? 1200;
    final h = int.tryParse(_heightCtrl.text.trim()) ?? 480;
    if (h <= 0) return '—';
    final g = _gcd(w, h);
    return '${w ~/ g}:${h ~/ g}';
  }

  int _gcd(int a, int b) {
    while (b != 0) {
      final t = b;
      b = a % b;
      a = t;
    }
    return a.abs();
  }

  Widget _bannerCard(_BannerSlot slot) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Banner ${slot.index}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Switch(
                  value: slot.published,
                  onChanged: (v) {
                    setState(() => slot.published = v);
                    _markDirty();
                  },
                ),
                Text(slot.published ? 'Published' : 'Hidden'),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: slot.imageUrl,
              decoration: InputDecoration(
                labelText: 'Image URL (HTTPS)',
                border: const OutlineInputBorder(),
                suffixIcon: slot.imageUrl.text.trim().isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.preview_outlined),
                        tooltip: 'Preview',
                        onPressed: () => _previewImage(slot.imageUrl.text.trim()),
                      ),
              ),
              maxLines: 2,
              onChanged: (_) {
                setState(() {});
                _markDirty();
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<BannerLinkKind>(
              value: slot.linkKind,
              decoration: const InputDecoration(
                labelText: 'On tap',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: BannerLinkKind.none,
                  child: Text('No action'),
                ),
                DropdownMenuItem(
                  value: BannerLinkKind.external,
                  child: Text('Open website (HTTPS)'),
                ),
                DropdownMenuItem(
                  value: BannerLinkKind.app,
                  child: Text('Open app screen'),
                ),
                DropdownMenuItem(
                  value: BannerLinkKind.landing,
                  child: Text('Open detail page (in app)'),
                ),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  slot.linkKind = v;
                  if (v != BannerLinkKind.external) slot.linkUrl.clear();
                  if (v != BannerLinkKind.app) slot.appRoute = '';
                });
                _markDirty();
              },
            ),
            if (slot.linkKind == BannerLinkKind.external) ...[
              const SizedBox(height: 10),
              TextField(
                controller: slot.linkUrl,
                decoration: const InputDecoration(
                  labelText: 'Website URL',
                  border: OutlineInputBorder(),
                  hintText: 'https://…',
                ),
                onChanged: (_) => _markDirty(),
              ),
            ],
            if (slot.linkKind == BannerLinkKind.app) ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: slot.appRoute.isEmpty ? null : slot.appRoute,
                decoration: const InputDecoration(
                  labelText: 'App screen',
                  border: OutlineInputBorder(),
                ),
                items: _appRouteDropdownItems(),
                onChanged: (v) {
                  setState(() => slot.appRoute = v ?? '');
                  _markDirty();
                },
              ),
            ],
            if (slot.linkKind == BannerLinkKind.landing) ...[
              const SizedBox(height: 10),
              TextField(
                controller: slot.landingTitle,
                decoration: const InputDecoration(
                  labelText: 'Landing page title',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => _markDirty(),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: slot.landingBody,
                decoration: const InputDecoration(
                  labelText: 'Landing page body',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                  hintText: 'Full message shown when the user taps the banner…',
                ),
                minLines: 4,
                maxLines: 8,
                onChanged: (_) => _markDirty(),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: slot.landingCtaLabel,
                decoration: const InputDecoration(
                  labelText: 'Optional button label',
                  border: OutlineInputBorder(),
                  hintText: 'e.g. Learn more',
                ),
                onChanged: (_) => _markDirty(),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<BannerLinkKind>(
                value: slot.landingCtaLinkKind == BannerLinkKind.landing
                    ? BannerLinkKind.none
                    : slot.landingCtaLinkKind,
                decoration: const InputDecoration(
                  labelText: 'Button action (optional)',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: BannerLinkKind.none,
                    child: Text('No button'),
                  ),
                  DropdownMenuItem(
                    value: BannerLinkKind.external,
                    child: Text('Open website'),
                  ),
                  DropdownMenuItem(
                    value: BannerLinkKind.app,
                    child: Text('Open app screen'),
                  ),
                ],
                onChanged: (v) {
                  setState(() {
                    slot.landingCtaLinkKind = v ?? BannerLinkKind.none;
                    if (v != BannerLinkKind.external) slot.landingCtaUrl.clear();
                    if (v != BannerLinkKind.app) slot.landingCtaAppRoute = '';
                  });
                  _markDirty();
                },
              ),
              if (slot.landingCtaLinkKind == BannerLinkKind.external) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: slot.landingCtaUrl,
                  decoration: const InputDecoration(
                    labelText: 'Button website URL',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => _markDirty(),
                ),
              ],
              if (slot.landingCtaLinkKind == BannerLinkKind.app) ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: slot.landingCtaAppRoute.isEmpty
                      ? null
                      : slot.landingCtaAppRoute,
                  decoration: const InputDecoration(
                    labelText: 'Button app screen',
                    border: OutlineInputBorder(),
                  ),
                  items: _appRouteDropdownItems(),
                  onChanged: (v) {
                    setState(() => slot.landingCtaAppRoute = v ?? '');
                    _markDirty();
                  },
                ),
              ],
            ],
            if (slot.linkKind != BannerLinkKind.none) ...[
              const SizedBox(height: 6),
              Text(
                _tapSummary(slot),
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
            if (slot.imageUrl.text.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AdminCorsNetworkImage(
                  url: slot.imageUrl.text.trim(),
                  height: 72,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorLabel: 'Preview unavailable (URL may still work in app)',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<DropdownMenuItem<String>> _appRouteDropdownItems() {
    return DashboardBannerTargetOptions.all
        .map(
          (t) => DropdownMenuItem<String>(
            value: t.id,
            child: Text('${t.group} · ${t.label}'),
          ),
        )
        .toList();
  }

  String _tapSummary(_BannerSlot slot) {
    switch (slot.linkKind) {
      case BannerLinkKind.none:
        return '';
      case BannerLinkKind.external:
        final url = slot.linkUrl.text.trim();
        return url.isEmpty
            ? 'Add a website URL to enable tap.'
            : 'Opens in browser: $url';
      case BannerLinkKind.app:
        final label = DashboardBannerTargetOptions.labelFor(slot.appRoute);
        return label == null
            ? 'Choose an app screen.'
            : 'Opens in app: $label';
      case BannerLinkKind.landing:
        final title = slot.landingTitle.text.trim();
        final body = slot.landingBody.text.trim();
        if (body.isEmpty) return 'Add landing body text for the detail page.';
        return title.isEmpty
            ? 'Opens in-app detail page with body text.'
            : 'Opens in-app: $title';
    }
  }

  void _previewImage(String url) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Banner preview'),
        content: SizedBox(
          width: 560,
          child: AdminCorsNetworkImage(
            url: url,
            height: 320,
            width: double.infinity,
            fit: BoxFit.contain,
            errorLabel:
                'Preview blocked by CDN CORS. The app can still load this URL.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _BannerSlot {
  _BannerSlot({required this.index}) : id = 'banner_$index';

  final int index;
  final String id;
  final imageUrl = TextEditingController();
  final linkUrl = TextEditingController();
  final landingTitle = TextEditingController();
  final landingBody = TextEditingController();
  final landingCtaLabel = TextEditingController();
  final landingCtaUrl = TextEditingController();
  BannerLinkKind linkKind = BannerLinkKind.none;
  String appRoute = '';
  BannerLinkKind landingCtaLinkKind = BannerLinkKind.none;
  String landingCtaAppRoute = '';
  bool published = false;

  void dispose() {
    imageUrl.dispose();
    linkUrl.dispose();
    landingTitle.dispose();
    landingBody.dispose();
    landingCtaLabel.dispose();
    landingCtaUrl.dispose();
  }
}
