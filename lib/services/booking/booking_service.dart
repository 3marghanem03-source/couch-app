import 'package:uuid/uuid.dart';

import '../../models/booking.dart';
import '../../models/booking_status.dart';
import '../schedule/schedule_calendar.dart';
import '../oracle/oracle_api.dart';

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

  Future<List<Booking>> getBookingsForCoach(String coachId) async {
    // TODO: implement in Oracle API (coach pending list, etc.)
    return [];
  }

  Future<List<Booking>> getBookingsForClient(String clientId) async {
    // TODO: implement in Oracle API (client bookings list)
    return [];
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
    throw StateError('Not implemented yet in Oracle backend.');
  }

  Future<void> rejectBooking(String bookingId) async {
    throw StateError('Not implemented yet in Oracle backend.');
  }

  // When Oracle booking list endpoints are implemented, reuse the helpers above.
}
