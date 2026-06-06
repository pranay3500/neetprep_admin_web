import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'webinar_schedule_timezone.dart';

/// Recurring demo slot (IST wall time only — applies every bookable day on the app).
class AnalysisSlotTemplate {
  const AnalysisSlotTemplate({
    required this.id,
    required this.istHour,
    required this.istMinute,
    required this.durationMinutes,
    this.isAvailable = true,
    this.capacity = 1,
  });

  final String id;
  final int istHour;
  final int istMinute;
  final int durationMinutes;
  final bool isAvailable;
  final int capacity;

  int get sortKey => istHour * 60 + istMinute;

  factory AnalysisSlotTemplate.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? {};
    return AnalysisSlotTemplate.fromMap(d, id: doc.id);
  }

  factory AnalysisSlotTemplate.fromMap(
    Map<String, dynamic> d, {
    required String id,
  }) {
    return AnalysisSlotTemplate(
      id: id,
      istHour: (d['istHour'] as num?)?.toInt() ?? 10,
      istMinute: (d['istMinute'] as num?)?.toInt() ?? 0,
      durationMinutes: (d['durationMinutes'] as num?)?.toInt() ??
          (d['durationMins'] as num?)?.toInt() ??
          60,
      isAvailable: d['isAvailable'] != false,
      capacity: (d['capacity'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'istHour': istHour,
        'istMinute': istMinute,
        'durationMinutes': durationMinutes,
        'isAvailable': isAvailable,
        'capacity': capacity.clamp(1, 99),
        'timezone': 'Asia/Kolkata',
        'isTemplate': true,
      };

  String get istTimeLabel {
    final wall = DateTime(2000, 1, 1, istHour, istMinute);
    return '${DateFormat('h:mm a').format(wall)} IST';
  }

  String get durationLabel => '$durationMinutes min';

  /// Preview on admin list for “tomorrow IST”.
  String get previewTomorrowLabel {
    final day = WebinarScheduleTimezone.istWallFromUtc(
      DateTime.now().toUtc(),
    ).add(const Duration(days: 1));
    final startUtc = WebinarScheduleTimezone.utcFromIstParts(
      year: day.year,
      month: day.month,
      day: day.day,
      hour: istHour,
      minute: istMinute,
    );
    return WebinarScheduleTimezone.formatIstShort(startUtc);
  }
}
