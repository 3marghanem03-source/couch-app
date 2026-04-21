import 'package:flutter/material.dart';

import '../../../models/time_slot.dart';
import '../../../services/schedule/schedule_calendar.dart';
import '../../../widgets/slot_grid.dart';
import '../../../widgets/day_selector_widget.dart';

/// Shared “pick a day + see slots” block used by coach schedule, client home, and booking.
class WeekScheduleSection extends StatelessWidget {
  const WeekScheduleSection({
    super.key,
    required this.selectedDayIndex,
    required this.onDayChanged,
    required this.slots,
    required this.coachMode,
    this.availableOnly = false,
    this.selectedTime,
    this.onCoachTap,
    this.onClientSelect,
    this.clientDayClosedBanner,
  });

  final int selectedDayIndex;
  final ValueChanged<int> onDayChanged;
  final List<TimeSlot> slots;
  final bool coachMode;
  final bool availableOnly;
  final String? selectedTime;
  final void Function(TimeSlot slot)? onCoachTap;
  final void Function(TimeSlot slot)? onClientSelect;

  /// When set (client views), show under the day picker — coach closed this calendar day to bookings.
  final String? clientDayClosedBanner;

  @override
  Widget build(BuildContext context) {
    final weekMonday = ScheduleCalendar.mondayOfThisWeek();
    final header = ScheduleCalendar.formatDayHeader(selectedDayIndex, weekMonday);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(header, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        DaySelectorWidget(
          selectedIndex: selectedDayIndex,
          weekMonday: weekMonday,
          onDaySelected: onDayChanged,
        ),
        if (clientDayClosedBanner != null && !coachMode) ...[
          const SizedBox(height: 12),
          Text(
            clientDayClosedBanner!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
          ),
        ],
        const SizedBox(height: 20),
        SlotGrid(
          slots: slots,
          coachMode: coachMode,
          availableOnly: availableOnly,
          onCoachTap: onCoachTap,
          onClientSelect: onClientSelect,
          selectedTime: selectedTime,
        ),
      ],
    );
  }
}
