import 'package:flutter/material.dart';

import '../../core/app_routes.dart';
import '../../core/app_state.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/ui/app_spacing.dart';
import '../../core/ui/app_text_styles.dart';
import '../../widgets/app_button.dart';
import '../../widgets/card_container.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/notification_bell.dart';
import '../../widgets/section_header.dart';
import '../../widgets/language_toggle_action.dart';
import '../schedule/widgets/week_schedule_section.dart';

class ClientHomeScreen extends StatefulWidget {
  const ClientHomeScreen({super.key});

  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen> {
  int _day = 0;

  @override
  void initState() {
    super.initState();
    final todayIndex = DateTime.now().weekday - DateTime.monday; // Mon=0…Sun=6
    _day = todayIndex.clamp(0, 6);
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
            title: Text(s.t('client.home')),
            actions: [
              const LanguageToggleAction(),
              NotificationBell(
                unreadCount: appState.unreadNotifications,
                onPressed: () => Navigator.pushNamed(context, AppRoutes.notifications),
              ),
              IconButton(
                onPressed: () => Navigator.pushNamed(context, AppRoutes.profile),
                icon: const Icon(Icons.person_outline),
              ),
              TextButton(
                onPressed: () async {
                  await appState.logout();
                  if (context.mounted) AppRoutes.replaceWithLogin(context);
                },
                child: Text(s.t('common.logout')),
              ),
            ],
          ),
          body: Stack(
            children: [
              ListView(
                padding: const EdgeInsets.all(AppSpacing.page),
                children: [
                  CardContainer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const CircleAvatar(child: Icon(Icons.person)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Name', style: AppTextStyles.section),
                                  Text('Personal Trainer', style: AppTextStyles.muted),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sectionGap),
                        const SectionHeader('Coach schedule'),
                        const SizedBox(height: 6),
                        WeekScheduleSection(
                          selectedDayIndex: _day,
                          onDayChanged: (i) => setState(() => _day = i),
                          slots: slots,
                          coachMode: false,
                          availableOnly: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sectionGap),
                  AppButton(
                    label: s.t('client.book'),
                    onPressed: () => Navigator.pushNamed(context, AppRoutes.clientBook),
                  ),
                  const SizedBox(height: AppSpacing.itemGap),
                  AppButton(
                    label: s.t('client.myBookings'),
                    outlined: true,
                    onPressed: () => Navigator.pushNamed(context, AppRoutes.clientBookings),
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
