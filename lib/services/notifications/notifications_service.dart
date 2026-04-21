import '../../models/app_notification.dart';
import '../oracle/oracle_api.dart';

class NotificationsService {
  NotificationsService();

  final OracleApi _api = OracleApi();

  Future<int> unreadCount() => _api.notificationsUnreadCount();

  Future<List<AppNotification>> list() async {
    final rows = await _api.notificationsList();
    return rows.map(_mapRow).toList();
  }

  AppNotification _mapRow(Map<dynamic, dynamic> raw) {
    final m = Map<String, dynamic>.from(raw);
    String pick(String a, String b) => (m[a] ?? m[b])?.toString() ?? '';

    final id = pick('id', 'ID');
    final title = pick('title', 'TITLE');
    final body = pick('body', 'BODY');
    final created = m['created_at'] ?? m['CREATED_AT'];
    final readAt = m['read_at'] ?? m['READ_AT'];

    DateTime createdAt;
    if (created is DateTime) {
      createdAt = created;
    } else if (created != null) {
      createdAt = DateTime.tryParse(created.toString()) ?? DateTime.now();
    } else {
      createdAt = DateTime.now();
    }

    DateTime? ra;
    if (readAt is DateTime) {
      ra = readAt;
    } else if (readAt != null) {
      ra = DateTime.tryParse(readAt.toString());
    }

    return AppNotification(
      id: id,
      title: title,
      body: body,
      createdAt: createdAt,
      readAt: ra,
    );
  }

  Future<void> markRead(String id) => _api.markNotificationRead(id);

  Future<void> markAllRead() => _api.markAllNotificationsRead();
}
