import 'package:flutter/material.dart';

import '../core/ui/app_colors.dart';
import '../core/ui/app_text_styles.dart';
import '../models/slot_status.dart';
import '../models/time_slot.dart';

class TimeSlotWidget extends StatelessWidget {
  const TimeSlotWidget({
    super.key,
    required this.slot,
    required this.mode,
    this.selected = false,
    this.onTap,
  });

  final TimeSlot slot;
  final TimeSlotMode mode;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    late Color bg;
    late Color fg;
    late String subtitle;
    late Color border;

    switch (mode) {
      case TimeSlotMode.coach:
        switch (slot.status) {
          case SlotStatus.available:
            bg = AppColors.slotOpen;
            fg = AppColors.text;
            border = AppColors.border;
            subtitle = 'Available';
          case SlotStatus.blocked:
            bg = AppColors.slotBlocked;
            fg = AppColors.muted;
            border = AppColors.border;
            subtitle = 'Blocked';
          case SlotStatus.booked:
            bg = AppColors.slotBooked;
            fg = Colors.white;
            border = AppColors.slotBooked;
            subtitle = 'Booked';
        }
      case TimeSlotMode.clientPick:
        bg = selected ? AppColors.primary : AppColors.slotOpen;
        fg = selected ? Colors.white : AppColors.text;
        border = selected ? AppColors.primary : AppColors.border;
        subtitle = 'Available';
      case TimeSlotMode.clientView:
        bg = AppColors.slotOpen;
        fg = AppColors.text;
        border = AppColors.border;
        subtitle = 'Available';
    }

    return SizedBox(
      width: 104,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
            boxShadow: mode == TimeSlotMode.coach && slot.status == SlotStatus.booked
                ? const [
                    BoxShadow(
                      color: AppColors.shadow,
                      blurRadius: 10,
                      offset: Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                subtitle,
                style: AppTextStyles.muted.copyWith(color: fg.withValues(alpha: 0.85)),
              ),
              const SizedBox(height: 6),
              Text(
                slot.timeKey,
                style: TextStyle(fontWeight: FontWeight.w800, color: fg, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum TimeSlotMode {
  /// Shows Open/Blocked/Booked.
  coach,

  /// Shows only open slots, clickable/selectable.
  clientPick,

  /// Shows only open slots, not selectable.
  clientView,
}

