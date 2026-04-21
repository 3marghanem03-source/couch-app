import '../../models/coach_client_row.dart';

class CoachClientRowsService {
  CoachClientRowsService();

  Future<List<CoachClientRow>> listForClient({
    required String coachId,
    required String clientId,
  }) async {
    return [];
  }

  Future<void> create({
    required String coachId,
    required String clientId,
    required String rowDateIso,
    required String muscle,
    required String exercise,
    required int? sets,
    required int? reps,
    required double? weight,
    required String weightUnit,
    required String notes,
  }) async {
    throw StateError('Coach-only table rows are not available in Oracle-only mode yet.');
  }

  Future<void> update({
    required String id,
    required String coachId,
    required String clientId,
    required String rowDateIso,
    required String muscle,
    required String exercise,
    required int? sets,
    required int? reps,
    required double? weight,
    required String weightUnit,
    required String notes,
  }) async {
    throw StateError('Coach-only table rows are not available in Oracle-only mode yet.');
  }

  Future<void> delete({
    required String id,
    required String coachId,
    required String clientId,
  }) async {
    throw StateError('Coach-only table rows are not available in Oracle-only mode yet.');
  }
}

