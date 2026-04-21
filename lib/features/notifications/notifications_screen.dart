import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/ui/app_spacing.dart';
import '../../models/app_notification.dart';
import '../../services/notifications/notifications_service.dart';
import '../../widgets/language_toggle_action.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationsService _svc = NotificationsService();
  List<AppNotification> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _svc.list();
      if (mounted) {
        setState(() => _items = list);
        await appState.refreshNotificationBadge();
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('notifications.title')),
        actions: [
          if (_items.any((n) => !n.isRead))
            TextButton(
              onPressed: _loading
                  ? null
                  : () async {
                      await _svc.markAllRead();
                      await appState.refreshNotificationBadge();
                      await _load();
                    },
              child: const Text('Mark all read'),
            ),
          const LanguageToggleAction(),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading && _items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: const [
          SizedBox(height: 48),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          const SizedBox(height: 16),
          FilledButton(onPressed: _load, child: const Text('Retry')),
        ],
      );
    }
    if (_items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: const [
          SizedBox(height: 48),
          Text('No notifications yet.', textAlign: TextAlign.center),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.page),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final n = _items[i];
        return Card(
          child: ListTile(
            title: Text(n.title, style: TextStyle(fontWeight: n.isRead ? FontWeight.w400 : FontWeight.w700)),
            subtitle: Text(n.body, maxLines: 4, overflow: TextOverflow.ellipsis),
            trailing: n.isRead ? null : const Icon(Icons.circle, size: 10, color: Colors.blue),
            onTap: n.isRead
                ? null
                : () async {
                    await _svc.markRead(n.id);
                    await appState.refreshNotificationBadge();
                    await _load();
                  },
          ),
        );
      },
    );
  }
}
