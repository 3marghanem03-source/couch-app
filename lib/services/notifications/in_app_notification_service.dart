import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/app_notification.dart';

class InAppNotificationService {
  InAppNotificationService();

  SupabaseClient get _c => Supabase.instance.client;

  Future<List<AppNotification>> listMine({int limit = 50}) async {
    final rows = await _c
        .from('notifications')
        .select('id,title,body,created_at,read_at')
        .order('created_at', ascending: false)
        .limit(limit);

    return (rows as List? ?? const []).map((r) {
      final m = Map<String, dynamic>.from(r as Map);
      return AppNotification(
        id: m['id'] as String,
        title: (m['title'] as String?) ?? '',
        body: (m['body'] as String?) ?? '',
        createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
        readAt: m['read_at'] == null ? null : DateTime.parse(m['read_at'] as String).toLocal(),
      );
    }).toList();
  }

  Future<int> countUnread() async {
    final res = await _c
        .from('notifications')
        .select('id')
        .isFilter('read_at', null);
    return (res as List? ?? const []).length;
  }

  Future<void> markRead(String id) async {
    await _c.from('notifications').update({'read_at': DateTime.now().toIso8601String()}).eq('id', id);
  }
}

