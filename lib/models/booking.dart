import 'booking_status.dart';

class Booking {
  Booking({
    required this.id,
    required this.clientName,
    required this.clientId,
    required this.coachId,
    required this.date,
    required this.time,
    required this.status,
    required this.weekdayIndex,
    this.weekStart,
    this.slotId,
  });

  final String id;
  final String clientName;
  final String clientId;
  final String coachId;
  final DateTime date;
  /// Display label (from `timeKey` / DB `time` formatted consistently in service).
  final String time;
  BookingStatus status;
  final int weekdayIndex;
  final String? weekStart;
  final String? slotId;
}
