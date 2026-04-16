import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/slot_status.dart';
import '../../models/time_slot.dart';
import 'schedule_calendar.dart';

/// Builds the weekly slot grid from Supabase: `availability`, `blocked_times`, and `bookings`.
class ScheduleService {
  ScheduleService();

  Map<int, List<TimeSlot>> _byWeekday = {};

  Map<int, List<TimeSlot>> get scheduleByWeekday => _byWeekday;

  SupabaseClient get _c => Supabase.instance.client;

  void resetEmpty() {
    _byWeekday = {for (var i = 0; i < 7; i++) i: <TimeSlot>[]};
  }

  /// Loads one week for [coachId]. [coachView] shows blocked + booked; client view only shows open slots.
  Future<void> getAvailableSlots({
    required String coachId,
    required bool coachView,
  }) async {
    final monday = ScheduleCalendar.mondayOfThisWeek();
    final sunday = monday.add(const Duration(days: 6));
    final from = ScheduleCalendar.toIsoDate(monday);
    final to = ScheduleCalendar.toIsoDate(sunday);

    final availRes = await _c.from('availability').select().eq('coach_id', coachId);
    final avail = (availRes as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];

    final blockedRes = await _c.from('blocked_times').select().eq('coach_id', coachId).gte('date', from).lte('date', to);
    final blocked = (blockedRes as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];

    final bookRes = await _c.from('bookings').select().eq('coach_id', coachId).gte('date', from).lte('date', to);
    final books = (bookRes as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];

    final blockedSet = <String>{};
    for (final b in blocked) {
      blockedSet.add('${b['date']}|${b['time']}');
    }

    final bookingByKey = <String, Map<String, dynamic>>{};
    for (final b in books) {
      final st = b['status'] as String? ?? '';
      if (st == 'rejected') continue;
      final k = '${b['date']}|${b['time']}';
      bookingByKey[k] = b;
    }

    final out = <int, List<TimeSlot>>{};
    for (var day = 0; day < 7; day++) {
      final date = ScheduleCalendar.dateForWeekdayIndex(day);
      final iso = ScheduleCalendar.toIsoDate(date);

      List<String> keys;
      final dayAvail = avail.where((a) => (a['day_of_week'] as int?) == day).toList();
      if (dayAvail.isEmpty) {
        keys = List.from(ScheduleCalendar.defaultOpenHourKeys());
      } else {
        final row = dayAvail.first;
        keys = ScheduleCalendar.hourKeysFromAvailabilityRow(
          row['start_time'] as String? ?? '16:00',
          row['end_time'] as String? ?? '22:00',
        );
      }

      final slots = <TimeSlot>[];
      for (final key in keys) {
        final bKey = '$iso|$key';
        SlotStatus st;
        String? bid;

        if (blockedSet.contains(bKey)) {
          st = SlotStatus.blocked;
        } else if (bookingByKey.containsKey(bKey)) {
          st = SlotStatus.booked;
          bid = bookingByKey[bKey]!['id'] as String?;
        } else {
          st = SlotStatus.available;
        }

        if (!coachView && st != SlotStatus.available) {
          continue;
        }
        slots.add(TimeSlot(timeKey: key, status: st, bookingId: bid));
      }
      out[day] = slots;
    }
    _byWeekday = out;
  }

  List<TimeSlot> slotsForDay(int weekdayIndex) =>
      List.unmodifiable(_byWeekday[weekdayIndex] ?? const []);

  TimeSlot? findSlot(int weekdayIndex, String timeKey) {
    final list = _byWeekday[weekdayIndex];
    if (list == null) return null;
    for (final s in list) {
      if (s.timeKey == timeKey) return s;
    }
    return null;
  }

  Future<void> blockTime({
    required String coachId,
    required DateTime date,
    required String timeKey,
  }) async {
    await _c.from('blocked_times').insert({
      'coach_id': coachId,
      'date': ScheduleCalendar.toIsoDate(date),
      'time': timeKey,
    });
  }

  Future<void> unblockTime({
    required String coachId,
    required DateTime date,
    required String timeKey,
  }) async {
    await _c
        .from('blocked_times')
        .delete()
        .eq('coach_id', coachId)
        .eq('date', ScheduleCalendar.toIsoDate(date))
        .eq('time', timeKey);
  }
}
