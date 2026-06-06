import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firestore_db.dart';

class SubscriptionCmsPage extends StatefulWidget {
  const SubscriptionCmsPage({super.key});

  @override
  State<SubscriptionCmsPage> createState() => _SubscriptionCmsPageState();
}

class _SubscriptionCmsPageState extends State<SubscriptionCmsPage> {
  final _headerTitle = TextEditingController();
  final _headerSubtitle = TextEditingController();
  final _videoTitle = TextEditingController();
  final _videoUrl = TextEditingController();
  final _priceLabel = TextEditingController();
  final _priceAmount = TextEditingController();
  final _priceDurationLabel = TextEditingController();
  final _richText = TextEditingController();
  final List<_CardDraft> _cards = [];

  bool _loaded = false;
  bool _saving = false;
  String _status = 'Ready';

  DocumentReference<Map<String, dynamic>> get _doc =>
      FirestoreDb.instance.collection('cms_subscription').doc('premium');

  static const Map<String, dynamic> _defaults = {
    'headerTitle': 'Unlock Premium Benefits',
    'headerSubtitle':
        'Get expert guidance, premium tools, and faster admission decisions.',
    'videoTitle': 'Watch Premium Overview',
    'videoUrl': 'https://www.youtube.com/watch?v=aircAruvnKk',
    'priceLabel': 'ANNUAL PREMIUM PLAN',
    'priceAmount': '99',
    'priceDurationLabel': '/year',
    'richText':
        '## Why Premium?\n- Priority support\n- Better decision confidence\n- Faster counselling readiness',
    'cards': [
      {
        'icon': 'chat',
        'title': 'Unlimited Counselor Access',
        'description': 'Chat with experts anytime without any conversation limits.',
      },
      {
        'icon': 'library',
        'title': 'Full Content Library',
        'description': 'Access premium NEET resources and strategy modules.',
      },
      {
        'icon': 'analytics',
        'title': 'Advanced Score Analysis',
        'description': 'In-depth personalized reports for your NEET preparation.',
      },
    ],
  };

  @override
  void dispose() {
    _headerTitle.dispose();
    _headerSubtitle.dispose();
    _videoTitle.dispose();
    _videoUrl.dispose();
    _priceLabel.dispose();
    _priceAmount.dispose();
    _priceDurationLabel.dispose();
    _richText.dispose();
    for (final card in _cards) {
      card.dispose();
    }
    super.dispose();
  }

  Future<void> _hydrate() async {
    if (_loaded) return;
    final snap = await _doc.get();
    final data = (snap.data() ?? _defaults).map((k, v) => MapEntry(k, v));
    _headerTitle.text = (data['headerTitle'] ?? '').toString();
    _headerSubtitle.text = (data['headerSubtitle'] ?? '').toString();
    _videoTitle.text = (data['videoTitle'] ?? '').toString();
    _videoUrl.text = (data['videoUrl'] ?? '').toString();
    _priceLabel.text = (data['priceLabel'] ?? '').toString();
    _priceAmount.text = (data['priceAmount'] ?? '').toString();
    _priceDurationLabel.text = (data['priceDurationLabel'] ?? '').toString();
    _richText.text = (data['richText'] ?? '').toString();

    final cardsRaw = data['cards'];
    final cards = cardsRaw is List ? cardsRaw.whereType<Map>().toList() : const <Map>[];
    _cards
      ..clear()
      ..addAll(
        cards.map(
          (raw) => _CardDraft(
            icon: (raw['icon'] ?? 'star').toString(),
            title: (raw['title'] ?? '').toString(),
            description: (raw['description'] ?? '').toString(),
          ),
        ),
      );
    if (_cards.isEmpty) {
      _cards.add(_CardDraft(icon: 'star', title: '', description: ''));
    }
    _loaded = true;
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _status = 'Saving...';
    });
    try {
      final payload = <String, dynamic>{
        'headerTitle': _headerTitle.text.trim(),
        'headerSubtitle': _headerSubtitle.text.trim(),
        'videoTitle': _videoTitle.text.trim(),
        'videoUrl': _videoUrl.text.trim(),
        'priceLabel': _priceLabel.text.trim(),
        'priceAmount': _priceAmount.text.trim(),
        'priceDurationLabel': _priceDurationLabel.text.trim(),
        'richText': _richText.text.trim(),
        'cards': _cards
            .map((c) => {
                  'icon': c.icon.text.trim().isEmpty ? 'star' : c.icon.text.trim(),
                  'title': c.title.text.trim(),
                  'description': c.description.text.trim(),
                })
            .where((m) => (m['title'] ?? '').toString().isNotEmpty)
            .toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      await _doc.set(payload, SetOptions(merge: true));
      setState(() => _status = 'Saved');
    } catch (e) {
      setState(() => _status = 'Save failed: $e');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _addCard() {
    setState(() => _cards.add(_CardDraft(icon: 'star', title: '', description: '')));
  }

  void _removeCard(int index) {
    if (_cards.length <= 1) return;
    final card = _cards.removeAt(index);
    card.dispose();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _hydrate(),
      builder: (context, snapshot) {
        if (!_loaded) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Manage Premium Subscription Page',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            _section(
              'Header + Video',
              [
                _field(_headerTitle, 'Header title'),
                _field(_headerSubtitle, 'Header subtitle', maxLines: 2),
                _field(_videoTitle, 'Video title'),
                _field(_videoUrl, 'YouTube URL'),
              ],
            ),
            const SizedBox(height: 12),
            _section(
              'Pricing',
              [
                _field(_priceLabel, 'Price label'),
                _field(_priceAmount, 'Price amount in USD (numbers only)'),
                _field(_priceDurationLabel, 'Price duration label'),
              ],
            ),
            const SizedBox(height: 12),
            _section(
              'Benefit Cards',
              [
                ...List.generate(_cards.length, (i) => _cardEditor(i)),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _addCard,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add card'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _section(
              'Rich text section',
              [
                _field(
                  _richText,
                  'Use basic markdown style, e.g. ## Heading, - bullet',
                  maxLines: 8,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Save'),
                ),
                const SizedBox(width: 12),
                Text(_status),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  Widget _cardEditor(int index) {
    final card = _cards[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0x22000000)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text('Card ${index + 1}', style: const TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              IconButton(
                tooltip: 'Remove',
                onPressed: () => _removeCard(index),
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
          _field(card.icon, 'Icon key (chat/library/analytics/notification/star)'),
          _field(card.title, 'Title'),
          _field(card.description, 'Description', maxLines: 2),
        ],
      ),
    );
  }
}

class _CardDraft {
  _CardDraft({
    required String icon,
    required String title,
    required String description,
  })  : icon = TextEditingController(text: icon),
        title = TextEditingController(text: title),
        description = TextEditingController(text: description);

  final TextEditingController icon;
  final TextEditingController title;
  final TextEditingController description;

  void dispose() {
    icon.dispose();
    title.dispose();
    description.dispose();
  }
}
