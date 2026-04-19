import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../schedule/schedule_calendar.dart';

class CoachTrainingAiService {
  CoachTrainingAiService();

  SupabaseClient get _c => Supabase.instance.client;

  Future<Map<String, dynamic>> generateWeekPlan({
    required String clientId,
    String? weekStartIso,
  }) async {
    final res = await _c.functions.invoke(
      'generate-training-week',
      body: {
        'client_id': clientId,
        if (weekStartIso != null) 'week_start': weekStartIso,
      },
    );

    if (res.status != 200) {
      final msg = res.data is String ? res.data as String : jsonEncode(res.data);
      throw StateError('AI function failed (${res.status}): $msg');
    }

    final data = res.data;
    if (data is! Map) {
      throw StateError('Unexpected AI response shape');
    }
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>?> latestPlanForClient({
    required String coachId,
    required String clientId,
  }) async {
    final row = await _c
        .from('client_ai_week_plans')
        .select('week_start,plan,model,updated_at')
        .eq('coach_id', coachId)
        .eq('client_id', clientId)
        .order('week_start', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null) return null;
    return Map<String, dynamic>.from(row as Map);
  }

  static String thisWeekMondayIso() => ScheduleCalendar.mondayIsoThisWeek();
}
