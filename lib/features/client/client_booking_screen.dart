import 'package:flutter/material.dart';

import '../../core/app_routes.dart';
import '../../core/app_state.dart';
import '../../core/i18n/app_localizations.dart';
import '../../models/time_slot.dart';
import '../../widgets/app_button.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/language_toggle_action.dart';
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

  @override
  void initState() {
    super.initState();
    final todayIndex = DateTime.now().weekday - DateTime.monday; // Mon=0…Sun=6
    _day = todayIndex.clamp(0, 6);
  }

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
        SnackBar(content: Text(AppLocalizations.of(context).t('client.book.sent'))),
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
        final s = AppLocalizations.of(context);
        final slots = appState.slotsForDay(_day);
        return Scaffold(
          appBar: AppBar(
            title: Text(s.t('client.book.title')),
            actions: const [LanguageToggleAction()],
          ),
          body: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text(
                          s.t('client.book.pick'),
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
                          clientDayClosedBanner: appState.isClientBookingClosedForWeekday(_day)
                              ? s.t('client.book.dayClosedByCoach')
                              : null,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: AppButton(
                      label: _submitting ? s.t('client.book.buttoning') : s.t('client.book.button'),
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
