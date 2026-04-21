import '../oracle/oracle_api.dart';
import '../schedule/schedule_calendar.dart';

class CoachTrainingAiService {
  CoachTrainingAiService();

  final OracleApi _api = OracleApi();

  Future<Map<String, dynamic>> generateWeekPlan({
    required String clientId,
    String? weekStartIso,
  }) async {
    final res = await _api.generateAiWeekPlan(
      clientId: clientId,
      weekStartIso: weekStartIso,
    );
    final plan = res['plan'];
    if (plan is Map<String, dynamic>) return plan;
    if (plan is Map) return Map<String, dynamic>.from(plan);
    return {};
  }

  Future<Map<String, dynamic>?> latestPlanForClient({
    required String coachId,
    required String clientId,
  }) async {
    return _api.latestAiWeekPlan(clientId: clientId);
  }

  static String thisWeekMondayIso() => ScheduleCalendar.mondayIsoThisWeek();
}
