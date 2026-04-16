import 'package:intl/intl.dart';

import 'slot_status.dart';

/// One cell on the week grid. [timeKey] is **HH:mm** (24h) for DB + equality; [time] is the label for UI.
class TimeSlot {
  TimeSlot({
    required this.timeKey,
    required this.status,
    this.bookingId,
  }) : time = _formatLabel(timeKey);

  static final _fmt = DateFormat.jm('en_US');

  static String _formatLabel(String key) {
    final parts = key.split(':');
    if (parts.length != 2) return key;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final dt = DateTime(2000, 1, 1, h, m);
    return _fmt.format(dt);
  }

  /// 24h "16:00" — matches `bookings.time` and `blocked_times.time`.
  final String timeKey;

  /// Display label (e.g. 4:00 PM).
  final String time;

  SlotStatus status;
  String? bookingId;
}
