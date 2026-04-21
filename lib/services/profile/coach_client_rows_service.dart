import '../../models/coach_client_row.dart';
import '../oracle/oracle_api.dart';

Map<String, dynamic> _normRow(Map<dynamic, dynamic> raw) {
  final m = <String, dynamic>{};
  for (final e in raw.entries) {
    m[e.key.toString().toLowerCase()] = e.value;
  }
  return m;
}

class CoachClientRowsService {
  CoachClientRowsService();

  final OracleApi _api = OracleApi();

  Future<List<CoachClientRow>> listForClient({
    required String coachId,
    required String clientId,
  }) async {
    final rows = await _api.listCoachClientRows(clientId: clientId);
    return rows.map((r) => CoachClientRow.fromMap(_normRow(r))).toList();
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
    await _api.createCoachClientRow(
      clientId: clientId,
      rowDateIso: rowDateIso,
      muscle: muscle,
      exercise: exercise,
      sets: sets,
      reps: reps,
      weight: weight,
      weightUnit: weightUnit,
      notes: notes,
    );
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
    await _api.updateCoachClientRow(
      rowId: id,
      rowDateIso: rowDateIso,
      muscle: muscle,
      exercise: exercise,
      sets: sets,
      reps: reps,
      weight: weight,
      weightUnit: weightUnit,
      notes: notes,
    );
  }

  Future<void> delete({
    required String id,
    required String coachId,
    required String clientId,
  }) async {
    await _api.deleteCoachClientRow(rowId: id);
  }
}
