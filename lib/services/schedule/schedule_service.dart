import '../../models/slot_status.dart';
import '../../models/time_slot.dart';
import '../oracle/oracle_api.dart';
import 'schedule_calendar.dart';

/// Builds the weekly slot grid from Oracle REST API.
class ScheduleService {
  ScheduleService();

  Map<int, List<TimeSlot>> _byWeekday = {};
  final Set<String> _clientBookingClosedDates = {};

  Map<int, List<TimeSlot>> get scheduleByWeekday => _byWeekday;

  /// ISO `YYYY-MM-DD` dates in the current loaded week where the coach disabled client booking.
  Set<String> get clientBookingClosedDates => Set.unmodifiable(_clientBookingClosedDates);
  final OracleApi _oracle = OracleApi();

  void resetEmpty() {
    _byWeekday = {for (var i = 0; i < 7; i++) i: <TimeSlot>[]};
    _clientBookingClosedDates.clear();
  }

  bool isClientBookingClosedForWeekday(int weekdayIndex) {
    final date = ScheduleCalendar.dateForWeekdayIndex(weekdayIndex);
    return _clientBookingClosedDates.contains(ScheduleCalendar.toIsoDate(date));
  }

  Future<void> addClientBookingDayClosure({
    required String coachId,
    required String dateIso,
  }) async {
    await _oracle.addDayClosure(dateIso: dateIso);
    _clientBookingClosedDates.add(dateIso);
  }

  Future<void> removeClientBookingDayClosure({
    required String coachId,
    required String dateIso,
  }) async {
    await _oracle.removeDayClosure(dateIso: dateIso);
    _clientBookingClosedDates.remove(dateIso);
  }

  /// Loads one week for [coachId]. [coachView] shows blocked + booked; client view only shows open slots.
  Future<void> getAvailableSlots({
    required String coachId,
    required bool coachView,
  }) async {
    final monday = ScheduleCalendar.mondayOfThisWeek();
    final from = ScheduleCalendar.toIsoDate(monday);

    final m = coachView
        ? await _oracle.weeklySchedule(coachId: coachId, weekStartIso: from)
        : await _oracle.weeklySchedulePublic(coachId: coachId, weekStartIso: from);

    final avail = (m['availability'] as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final blocked = (m['blockedTimes'] as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final books = (m['bookings'] as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    _clientBookingClosedDates.clear();
    final closedRaw = m['closedDates'] as List? ?? const [];
    for (final e in closedRaw) {
      if (e is String) {
        _clientBookingClosedDates.add(e);
      } else if (e is Map) {
        final mm = Map<String, dynamic>.from(e);
        final d = mm['d'] ?? mm['D'] ?? mm['date'];
        if (d != null) _clientBookingClosedDates.add(d.toString());
      }
    }

    final blockedSet = <String>{};
    for (final b in blocked) {
      blockedSet.add('${b['DATE'] ?? b['date']}|${b['TIME'] ?? b['time']}');
    }

    final bookingByKey = <String, Map<String, dynamic>>{};
    for (final b in books) {
      final st = (b['STATUS'] ?? b['status'] ?? '').toString();
      if (st == 'rejected') continue;
      final k = '${b['DATE'] ?? b['date']}|${b['TIME'] ?? b['time']}';
      bookingByKey[k] = b;
    }

    final out = <int, List<TimeSlot>>{};
    for (var day = 0; day < 7; day++) {
      final date = ScheduleCalendar.dateForWeekdayIndex(day);
      final iso = ScheduleCalendar.toIsoDate(date);

      List<String> keys;
      final dayAvail = avail.where((a) => (a['DAY_OF_WEEK'] ?? a['day_of_week']) == day).toList();
      if (dayAvail.isEmpty) {
        keys = List.from(ScheduleCalendar.defaultOpenHourKeys());
      } else {
        final row = dayAvail.first;
        keys = ScheduleCalendar.hourKeysFromAvailabilityRow(
          (row['START_TIME'] ?? row['start_time'] ?? '07:00').toString(),
          (row['END_TIME'] ?? row['end_time'] ?? '22:00').toString(),
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
          bid = (bookingByKey[bKey]!['ID'] ?? bookingByKey[bKey]!['id'])?.toString();
        } else {
          st = SlotStatus.available;
        }

        if (!coachView && st != SlotStatus.available) continue;
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
    await _oracle.addBlockedTime(
      dateIso: ScheduleCalendar.toIsoDate(date),
      timeHhmm: timeKey,
    );
  }

  Future<void> unblockTime({
    required String coachId,
    required DateTime date,
    required String timeKey,
  }) async {
    await _oracle.removeBlockedTime(
      dateIso: ScheduleCalendar.toIsoDate(date),
      timeHhmm: timeKey,
    );
  }
}
