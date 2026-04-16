import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../models/time_slot.dart';
import '../../widgets/loading_widget.dart';
import '../schedule/widgets/week_schedule_section.dart';
import 'coach_schedule_dialogs.dart';

class CoachScheduleScreen extends StatefulWidget {
  const CoachScheduleScreen({super.key});

  @override
  State<CoachScheduleScreen> createState() => _CoachScheduleScreenState();
}

class _CoachScheduleScreenState extends State<CoachScheduleScreen> {
  int _day = 0;

  @override
  void initState() {
    super.initState();
    final todayIndex = DateTime.now().weekday - DateTime.monday; // Mon=0…Sun=6
    _day = todayIndex.clamp(0, 6);
  }

  void _onSlotTap(TimeSlot slot) {
    showCoachSlotActions(context, weekdayIndex: _day, slot: slot);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final slots = appState.slotsForDay(_day);
        return Scaffold(
          appBar: AppBar(title: const Text('My schedule')),
          body: Stack(
            children: [
              ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  WeekScheduleSection(
                    selectedDayIndex: _day,
                    onDayChanged: (i) => setState(() => _day = i),
                    slots: slots,
                    coachMode: true,
                    onCoachTap: _onSlotTap,
                  ),
                ],
              ),
              if (appState.isRefreshing)
                const LoadingWidget(message: 'Refreshing…'),
            ],
          ),
        );
      },
    );
  }
}
