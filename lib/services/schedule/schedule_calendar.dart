import 'package:intl/intl.dart';

/// Monday = 0 … Sunday = 6 (UI order). Date + slot template helpers.
class ScheduleCalendar {
  ScheduleCalendar._();

  static const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  static String formatDayHeader(int weekdayIndex, DateTime baseMonday) {
    final d = baseMonday.add(Duration(days: weekdayIndex));
    final m = DateFormat.MMMd().format(d);
    return '${dayLabels[weekdayIndex]} · $m';
  }

  static DateTime mondayOfThisWeek() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return today.subtract(Duration(days: today.weekday - DateTime.monday));
  }

  static DateTime dateForWeekdayIndex(int weekdayIndex) {
    return mondayOfThisWeek().add(Duration(days: weekdayIndex));
  }

  static String mondayIsoThisWeek() {
    final m = mondayOfThisWeek();
    return '${m.year.toString().padLeft(4, '0')}-${m.month.toString().padLeft(2, '0')}-${m.day.toString().padLeft(2, '0')}';
  }

  static String toIsoDate(DateTime d) {
    final x = DateTime(d.year, d.month, d.day);
    return '${x.year.toString().padLeft(4, '0')}-${x.month.toString().padLeft(2, '0')}-${x.day.toString().padLeft(2, '0')}';
  }

  /// When a coach has no `availability` row for a weekday, use 16:00–22:00 (inclusive hour starts).
  static List<String> defaultOpenHourKeys() {
    return [for (var h = 16; h <= 22; h++) '${h.toString().padLeft(2, '0')}:00'];
  }

  /// `start` / `end` are "HH:mm"; `end` is treated as **last bookable hour** (inclusive), same as defaults.
  static List<String> hourKeysFromAvailabilityRow(String startHm, String endHm) {
    final sh = int.tryParse(startHm.split(':').first) ?? 16;
    final eh = int.tryParse(endHm.split(':').first) ?? 22;
    if (eh < sh) return defaultOpenHourKeys();
    return [for (var h = sh; h <= eh; h++) '${h.toString().padLeft(2, '0')}:00'];
  }
}
