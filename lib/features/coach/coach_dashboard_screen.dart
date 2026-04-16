import 'package:flutter/material.dart';

import '../../core/app_routes.dart';
import '../../core/app_state.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/ui/app_spacing.dart';
import '../../core/ui/app_text_styles.dart';
import '../../widgets/app_button.dart';
import '../../widgets/booking_card.dart';
import '../../widgets/card_container.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/language_toggle_action.dart';
import '../../widgets/notification_bell.dart';
import '../../widgets/section_header.dart';
import 'client_profile_screen.dart';

class CoachDashboardScreen extends StatelessWidget {
  const CoachDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final s = AppLocalizations.of(context);
        final pending = appState.pendingRequests();
        final clients = appState.clients;
        final myCode = appState.currentUser?.inviteCode;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Coach dashboard'),
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
              Text('Good evening, Coach', style: AppTextStyles.titlePage),
              const SizedBox(height: 4),
              Text('Here is your summary.', style: AppTextStyles.muted),
              const SizedBox(height: AppSpacing.sectionGap),
              if (myCode != null && myCode.isNotEmpty) ...[
                CardContainer(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(Icons.qr_code_2, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Your coach code', style: AppTextStyles.section),
                            const SizedBox(height: 2),
                            Text(myCode, style: AppTextStyles.titlePage),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sectionGap),
              ],
              const SectionHeader('Booking Requests'),
              if (pending.isEmpty)
                const EmptyStateWidget(
                  message: 'No pending requests.',
                  icon: Icons.inbox_outlined,
                  padding: EdgeInsets.only(top: 8, bottom: 8),
                )
              else ...[
                const SizedBox(height: 4),
                ...pending.map((b) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: CardContainer(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          BookingCard(
                            booking: b,
                            leading: const CircleAvatar(child: Icon(Icons.person)),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: appState.isRefreshing
                                      ? null
                                      : () async {
                                          try {
                                            await appState.rejectBookingAsync(b.id);
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Booking rejected.')),
                                              );
                                            }
                                          } catch (e) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text('$e')),
                                              );
                                            }
                                          }
                                        },
                                  child: const Text('Reject'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton(
                                  onPressed: appState.isRefreshing
                                      ? null
                                      : () async {
                                          try {
                                            await appState.approveBookingAsync(b.id);
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Booking approved.')),
                                              );
                                            }
                                          } catch (e) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text('$e')),
                                              );
                                            }
                                          }
                                        },
                                  child: const Text('Approve'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
              const SizedBox(height: AppSpacing.sectionGap),
              const SectionHeader('Clients List'),
              if (clients.isEmpty)
                const EmptyStateWidget(
                  message: 'No clients yet.',
                  icon: Icons.people_outline,
                  padding: EdgeInsets.only(top: 8, bottom: 8),
                )
              else
                ...clients.map((c) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: CardContainer(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(c.name),
                        subtitle: const Text('Client'),
                        onTap: () {
                          final coachId = appState.currentUser?.id;
                          if (coachId == null) return;
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ClientProfileScreen(client: c, coachId: coachId),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                }),
              const SizedBox(height: AppSpacing.sectionGap),
              AppButton(
                label: 'View Schedule',
                onPressed: appState.isRefreshing ? null : () => Navigator.pushNamed(context, AppRoutes.coachSchedule),
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
