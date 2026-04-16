import 'package:flutter/material.dart';

import '../../core/app_routes.dart';
import '../../core/app_state.dart';
import '../../models/time_slot.dart';
import '../../widgets/app_button.dart';
import '../../widgets/loading_widget.dart';
import '../schedule/widgets/week_schedule_section.dart';

class ClientBookingScreen extends StatefulWidget {
  const ClientBookingScreen({super.key});

  @override
  State<ClientBookingScreen> createState() => _ClientBookingScreenState();
}

class _ClientBookingScreenState extends State<ClientBookingScreen> {
  int _day = 0;
  TimeSlot? _selectedSlot;
  bool _submitting = false;

  void _selectSlot(TimeSlot slot) {
    setState(() => _selectedSlot = slot);
  }

  Future<void> _book() async {
    final slot = _selectedSlot;
    if (slot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a time first.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await appState.bookSessionAsync(weekdayIndex: _day, timeKey: slot.timeKey, slot: slot);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request sent — pending coach approval.')),
      );
      Navigator.pushNamed(context, AppRoutes.clientBookings);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final slots = appState.slotsForDay(_day);
        return Scaffold(
          appBar: AppBar(title: const Text('Book a session')),
          body: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text(
                          'Choose a day, then an open slot.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 12),
                        WeekScheduleSection(
                          selectedDayIndex: _day,
                          onDayChanged: (i) => setState(() {
                            _day = i;
                            _selectedSlot = null;
                          }),
                          slots: slots,
                          coachMode: false,
                          availableOnly: true,
                          selectedTime: _selectedSlot?.time,
                          onClientSelect: _selectSlot,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: AppButton(
                      label: _submitting ? 'Booking…' : 'Book session',
                      onPressed: (appState.isRefreshing || _submitting) ? null : () => _book(),
                    ),
                  ),
                ],
              ),
              if (appState.isRefreshing || _submitting)
                const LoadingWidget(message: 'Working…'),
            ],
          ),
        );
      },
    );
  }
}
