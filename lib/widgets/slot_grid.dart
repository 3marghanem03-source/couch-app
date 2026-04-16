import 'package:flutter/material.dart';

import '../models/slot_status.dart';
import '../models/time_slot.dart';
import 'empty_state_widget.dart';
import 'time_slot_widget.dart';

typedef SlotTapCallback = void Function(TimeSlot slot);

class SlotGrid extends StatelessWidget {
  const SlotGrid({
    super.key,
    required this.slots,
    this.coachMode = false,
    this.availableOnly = false,
    this.onCoachTap,
    this.onClientSelect,
    this.selectedTime,
  });

  final List<TimeSlot> slots;
  final bool coachMode;
  /// When true (client views), only render available slots.
  final bool availableOnly;
  final SlotTapCallback? onCoachTap;
  final SlotTapCallback? onClientSelect;
  final String? selectedTime;

  @override
  Widget build(BuildContext context) {
    final visible = availableOnly
        ? slots.where((s) => s.status == SlotStatus.available).toList()
        : slots;

    if (visible.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.calendar_today,
        message: availableOnly ? 'No open slots this day.' : 'No slots.',
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: visible.map((s) {
        final selected = selectedTime == s.time;
        final onTap = coachMode
            ? (onCoachTap == null ? null : () => onCoachTap!(s))
            : (availableOnly ? (onClientSelect == null ? null : () => onClientSelect!(s)) : null);

        final mode = coachMode
            ? TimeSlotMode.coach
            : (availableOnly ? TimeSlotMode.clientPick : TimeSlotMode.clientView);

        return TimeSlotWidget(
          slot: s,
          mode: mode,
          selected: selected,
          onTap: onTap,
        );
      }).toList(),
    );
  }
}
