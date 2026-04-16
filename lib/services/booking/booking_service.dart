import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/booking.dart';
import '../../models/booking_status.dart';
import '../schedule/schedule_calendar.dart';

/// All booking reads/writes go through Supabase `bookings` + `users` (for names).
class BookingService {
  BookingService();

  final List<Booking> _bookings = [];
  static final _timeFmt = DateFormat.jm('en_US');

  SupabaseClient get _c => Supabase.instance.client;

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

  static String _displayTime(String timeKey) {
    final parts = timeKey.split(':');
    if (parts.length != 2) return timeKey;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return _timeFmt.format(DateTime(2000, 1, 1, h, m));
  }

  Future<List<Booking>> getBookingsForCoach(String coachId) async {
    final rows = await _c.from('bookings').select().eq('coach_id', coachId).order('created_at', ascending: false);
    return _mapRowsWithClientNames(List.from(rows as List? ?? const []));
  }

  Future<List<Booking>> getBookingsForClient(String clientId) async {
    final rows = await _c.from('bookings').select().eq('client_id', clientId).order('created_at', ascending: false);
    return _mapRowsWithClientNames(List.from(rows as List? ?? const []));
  }

  Future<void> createBooking({
    required String clientId,
    required String coachId,
    required DateTime date,
    required String timeKey,
  }) async {
    await _c.from('bookings').insert({
      'client_id': clientId,
      'coach_id': coachId,
      'date': ScheduleCalendar.toIsoDate(date),
      'time': timeKey,
      'status': 'pending',
    });
  }

  Future<void> approveBooking(String bookingId) async {
    await _c.from('bookings').update({'status': 'approved'}).eq('id', bookingId);
  }

  Future<void> rejectBooking(String bookingId) async {
    await _c.from('bookings').update({'status': 'rejected'}).eq('id', bookingId);
  }

  Future<List<Booking>> _mapRowsWithClientNames(List rows) async {
    if (rows.isEmpty) return [];
    final ids = <String>{};
    for (final r in rows) {
      final m = Map<String, dynamic>.from(r as Map);
      final cid = m['client_id'] as String?;
      if (cid != null) ids.add(cid);
    }
    final names = <String, String>{};
    if (ids.isNotEmpty) {
      final users = await _c.from('users').select('id,name').inFilter('id', ids.toList());
      for (final u in users as List? ?? const []) {
        final m = Map<String, dynamic>.from(u as Map);
        final id = m['id'] as String;
        final n = (m['name'] as String?)?.trim();
        names[id] = (n != null && n.isNotEmpty) ? n : 'Client';
      }
    }
    final weekStart = ScheduleCalendar.mondayIsoThisWeek();
    return rows.map((r) => _fromRow(Map<String, dynamic>.from(r as Map), names, weekStart)).toList();
  }

  Booking _fromRow(
    Map<String, dynamic> m,
    Map<String, String> clientNames,
    String weekMondayIso,
  ) {
    final date = _parseIsoDateLocal(m['date'] as String);
    final monday = _parseIsoDateLocal(weekMondayIso);
    final base = DateTime(monday.year, monday.month, monday.day);
    final dayMid = DateTime(date.year, date.month, date.day);
    var weekdayIndex = dayMid.difference(base).inDays;
    if (weekdayIndex < 0 || weekdayIndex > 6) weekdayIndex = 0;

    final clientId = m['client_id'] as String? ?? '';
    final timeKey = m['time'] as String? ?? '00:00';

    return Booking(
      id: m['id'] as String,
      clientName: clientNames[clientId] ?? 'Client',
      clientId: clientId,
      coachId: m['coach_id'] as String? ?? '',
      date: date,
      time: _displayTime(timeKey),
      status: _parseStatus(m['status'] as String? ?? 'pending'),
      weekdayIndex: weekdayIndex,
      weekStart: weekMondayIso,
      slotId: timeKey,
    );
  }

  /// Parse `YYYY-MM-DD` from Postgres `date` into a local DateTime (midnight).
  /// Dart's `DateTime.parse` treats date-only strings as UTC, which can shift the day when shown in local timezones.
  static DateTime _parseIsoDateLocal(String iso) {
    final parts = iso.split('-');
    if (parts.length != 3) return DateTime.parse(iso).toLocal();
    final y = int.tryParse(parts[0]) ?? 2000;
    final m = int.tryParse(parts[1]) ?? 1;
    final d = int.tryParse(parts[2]) ?? 1;
    return DateTime(y, m, d);
  }

  BookingStatus _parseStatus(String s) {
    switch (s) {
      case 'approved':
        return BookingStatus.approved;
      case 'rejected':
        return BookingStatus.rejected;
      default:
        return BookingStatus.pending;
    }
  }
}
