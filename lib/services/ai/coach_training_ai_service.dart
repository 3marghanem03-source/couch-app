import '../schedule/schedule_calendar.dart';

class CoachTrainingAiService {
  CoachTrainingAiService();

  Future<Map<String, dynamic>> generateWeekPlan({
    required String clientId,
    String? weekStartIso,
  }) async {
    throw StateError('AI week plan is not available in Oracle-only mode yet.');
  }

  Future<Map<String, dynamic>?> latestPlanForClient({
    required String coachId,
    required String clientId,
  }) async {
    return null;
  }

  static String thisWeekMondayIso() => ScheduleCalendar.mondayIsoThisWeek();
}
