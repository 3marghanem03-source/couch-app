import 'package:flutter/material.dart';

import '../core/ui/app_colors.dart';
import '../core/ui/app_text_styles.dart';
import '../services/schedule/schedule_calendar.dart';

class DaySelectorWidget extends StatelessWidget {
  const DaySelectorWidget({
    super.key,
    required this.selectedIndex,
    required this.onDaySelected,
    required this.weekMonday,
  });

  final int selectedIndex;
  final ValueChanged<int> onDaySelected;
  final DateTime weekMonday;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Row(
      children: List.generate(7, (i) {
        final selected = i == selectedIndex;
        final fullDate = weekMonday.add(Duration(days: i));
        final dayDate = DateTime(fullDate.year, fullDate.month, fullDate.day);
        final isPastDay = dayDate.isBefore(today);
        final date = fullDate.day;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: isPastDay ? null : () => onDaySelected(i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                  boxShadow: selected
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
                  children: [
                    Text(
                      ScheduleCalendar.dayLabels[i],
                      style: AppTextStyles.muted.copyWith(
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? Colors.white
                            : (isPastDay ? AppColors.disabled : AppColors.muted),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$date',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: selected
                            ? Colors.white
                            : (isPastDay ? AppColors.disabled : AppColors.text),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

