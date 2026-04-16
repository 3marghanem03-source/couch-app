import 'package:flutter/material.dart';

import '../services/schedule/schedule_calendar.dart';

class DayStrip extends StatelessWidget {
  const DayStrip({
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
    return Row(
      children: List.generate(7, (i) {
        final selected = i == selectedIndex;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Material(
              color: selected
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => onDaySelected(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    children: [
                      Text(
                        ScheduleCalendar.dayLabels[i],
                        style: TextStyle(
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${weekMonday.add(Duration(days: i)).day}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
