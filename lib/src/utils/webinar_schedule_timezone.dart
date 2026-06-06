import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Webinar schedule: pick in IST (admin), store UTC, display US labels on app.
class WebinarScheduleTimezone {
  WebinarScheduleTimezone._();

  static bool _ready = false;

  static void ensureInitialized() {
    if (_ready) return;
    tzdata.initializeTimeZones();
    _ready = true;
  }

  static final tz.Location _ist = tz.getLocation('Asia/Kolkata');
  static final tz.Location _usEast = tz.getLocation('America/New_York');
  static final tz.Location _usPacific = tz.getLocation('America/Los_Angeles');

  static DateTime utcFromIstParts({
    required int year,
    required int month,
    required int day,
    required int hour,
    required int minute,
  }) {
    ensureInitialized();
    return tz.TZDateTime(_ist, year, month, day, hour, minute).toUtc();
  }

  static DateTime utcFromIstWall(DateTime istWall) {
    return utcFromIstParts(
      year: istWall.year,
      month: istWall.month,
      day: istWall.day,
      hour: istWall.hour,
      minute: istWall.minute,
    );
  }

  /// UTC [start, end) for one IST calendar day (date picker y/m/d = IST date).
  static ({DateTime startUtc, DateTime endUtc}) istDayUtcRange({
    required int year,
    required int month,
    required int day,
  }) {
    final startUtc = utcFromIstParts(
      year: year,
      month: month,
      day: day,
      hour: 0,
      minute: 0,
    );
    return (startUtc: startUtc, endUtc: startUtc.add(const Duration(days: 1)));
  }

  static ({DateTime startUtc, DateTime endUtc}) istDayUtcRangeFromWall(
    DateTime istCalendarDate,
  ) {
    return istDayUtcRange(
      year: istCalendarDate.year,
      month: istCalendarDate.month,
      day: istCalendarDate.day,
    );
  }

  static tz.TZDateTime istFromUtc(DateTime utc) {
    ensureInitialized();
    return tz.TZDateTime.from(utc.toUtc(), _ist);
  }

  static DateTime istWallFromUtc(DateTime utc) {
    final t = istFromUtc(utc);
    return DateTime(t.year, t.month, t.day, t.hour, t.minute);
  }

  static String formatIstLong(DateTime utc) {
    final wall = istWallFromUtc(utc);
    return '${DateFormat('EEE, MMM d, yyyy').format(wall)} · '
        '${DateFormat('h:mm a').format(wall)} IST';
  }

  static String formatIstShort(DateTime utc) {
    final wall = istWallFromUtc(utc);
    return '${DateFormat('EEE, MMM d · h:mm a').format(wall)} IST';
  }

  /// e.g. Sunday · 8:00 PM EST / 5:00 PM PST (DST-aware abbreviations).
  static String usTimezoneDisplay(DateTime utc) {
    ensureInitialized();
    final et = tz.TZDateTime.from(utc.toUtc(), _usEast);
    final pt = tz.TZDateTime.from(utc.toUtc(), _usPacific);
    final day = DateFormat('EEEE').format(DateTime(et.year, et.month, et.day));
    return '$day · ${_clock(et)} / ${_clock(pt)}';
  }

  static String usJoinDialogDate(DateTime utc) {
    ensureInitialized();
    final et = tz.TZDateTime.from(utc.toUtc(), _usEast);
    return DateFormat('EEEE, MMMM d, yyyy').format(
      DateTime(et.year, et.month, et.day),
    );
  }

  static String usJoinDialogTime(DateTime utc) {
    ensureInitialized();
    final et = tz.TZDateTime.from(utc.toUtc(), _usEast);
    final wall = DateTime(et.year, et.month, et.day, et.hour, et.minute);
    return '${DateFormat('h:mm a').format(wall)} ${et.timeZoneName}';
  }

  static String _clock(tz.TZDateTime t) {
    final wall = DateTime(t.year, t.month, t.day, t.hour, t.minute);
    return '${DateFormat('h:mm a').format(wall)} ${t.timeZoneName}';
  }

  static DateTime? utcFromFirestore(Object? raw) {
    if (raw is Timestamp) return raw.toDate().toUtc();
    if (raw is DateTime) return raw.toUtc();
    return DateTime.tryParse(raw?.toString() ?? '')?.toUtc();
  }

  static DateTime nextSunday8pmIstUtc() {
    var d = istWallFromUtc(DateTime.now().toUtc());
    while (d.weekday != DateTime.sunday) {
      d = d.add(const Duration(days: 1));
    }
    if (d.isBefore(DateTime.now())) {
      d = d.add(const Duration(days: 7));
    }
    return utcFromIstParts(
      year: d.year,
      month: d.month,
      day: d.day,
      hour: 20,
      minute: 0,
    );
  }
}
