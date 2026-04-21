import 'package:uuid/uuid.dart';

import '../../models/booking.dart';
import '../../models/booking_status.dart';
import '../schedule/schedule_calendar.dart';
import '../oracle/oracle_api.dart';

dynamic _pick(Map<dynamic, dynamic> m, List<String> keys) {
  for (final k in keys) {
    if (m.containsKey(k) && m[k] != null) return m[k];
  }
  return null;
}

/// All booking reads/writes go through Oracle REST API.
class BookingService {
  BookingService();

  final List<Booking> _bookings = [];
  final OracleApi _oracle = OracleApi();
  static const _uuid = Uuid();

  List<Booking> get bookings => List.unmodifiable(_bookings);

  void replaceAll(List<Booking> next) {
    _bookings
      ..clear()
      ..addAll(next);
  }

  void clear() => _bookings.clear();

  Booking? byId(String? id) {
    if (id == null) return null;
    for (final b in _bookings) {
      if (b.id == id) return b;
    }
    return null;
  }

  List<Booking> pending() => _bookings.where((b) => b.status == BookingStatus.pending).toList();

  List<Booking> forClientSorted(String clientId) {
    final list = _bookings.where((b) => b.clientId == clientId).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  static String _rangeFrom() {
    final d = DateTime.now().subtract(const Duration(days: 400));
    return ScheduleCalendar.toIsoDate(DateTime(d.year, d.month, d.day));
  }

  static String _rangeTo() {
    final d = DateTime.now().add(const Duration(days: 400));
    return ScheduleCalendar.toIsoDate(DateTime(d.year, d.month, d.day));
  }

  Booking _mapRow(Map<String, dynamic> raw) {
    final m = Map<dynamic, dynamic>.from(raw);
    final id = '${_pick(m, ['id', 'ID'])}';
    final clientId = '${_pick(m, ['client_id', 'CLIENT_ID'])}';
    final coachId = '${_pick(m, ['coach_id', 'COACH_ID'])}';
    final dateIso = '${_pick(m, ['booking_date', 'BOOKING_DATE', 'date', 'DATE'])}';
    final time = '${_pick(m, ['time_hhmm', 'TIME_HHMM', 'time', 'TIME'])}';
    final clientName = '${_pick(m, ['client_name', 'CLIENT_NAME'])}'.trim();
    final st = '${_pick(m, ['status', 'STATUS'])}'.toLowerCase();
    final status = BookingStatus.values.firstWhere(
      (e) => e.name == st,
      orElse: () => BookingStatus.pending,
    );

    final parts = dateIso.split('-');
    final y = int.parse(parts[0]);
    final mo = int.parse(parts[1]);
    final da = int.parse(parts[2]);
    final date = DateTime(y, mo, da);
    final weekdayIndex = (date.weekday - DateTime.monday + 7) % 7;
    final monday = date.subtract(Duration(days: weekdayIndex));
    final weekStart = ScheduleCalendar.toIsoDate(monday);

    return Booking(
      id: id,
      clientName: clientName,
      clientId: clientId,
      coachId: coachId,
      date: date,
      time: time,
      status: status,
      weekdayIndex: weekdayIndex,
      weekStart: weekStart,
      slotId: null,
    );
  }

  Future<List<Booking>> getBookingsForCoach(String coachId) async {
    final rows = await _oracle.listBookingsCoach(
      coachId: coachId,
      fromIso: _rangeFrom(),
      toIso: _rangeTo(),
    );
    return rows.map((e) => _mapRow(e)).toList();
  }

  Future<List<Booking>> getBookingsForClient(String clientId) async {
    final rows = await _oracle.listBookingsClient(
      fromIso: _rangeFrom(),
      toIso: _rangeTo(),
    );
    return rows.map((e) => _mapRow(e)).toList();
  }

  Future<void> createBooking({
    required String clientId,
    required String coachId,
    required DateTime date,
    required String timeKey,
  }) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    if (day.isBefore(today)) {
      throw StateError('You can’t book a past day.');
    }

    await _oracle.createBooking(
      id: _uuid.v4(),
      clientId: clientId,
      coachId: coachId,
      dateIso: ScheduleCalendar.toIsoDate(date),
      timeHhmm: timeKey,
    );
  }

  Future<void> approveBooking(String bookingId) async {
    await _oracle.patchBookingStatus(bookingId: bookingId, status: 'approved');
  }

  Future<void> rejectBooking(String bookingId) async {
    await _oracle.patchBookingStatus(bookingId: bookingId, status: 'rejected');
  }
}
