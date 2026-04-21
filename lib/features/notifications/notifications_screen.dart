import 'package:flutter/material.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/ui/app_spacing.dart';
import '../../widgets/language_toggle_action.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('notifications.title')),
        actions: const [LanguageToggleAction()],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(AppSpacing.page),
            children: const [
              SizedBox(height: 24),
              Text(
                'Notifications are not available in Oracle-only mode yet.',
                textAlign: TextAlign.center,
              ),
            ],
          )
        ],
      ),
    );
  }
}

