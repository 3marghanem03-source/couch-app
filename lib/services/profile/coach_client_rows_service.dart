import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/coach_client_row.dart';

class CoachClientRowsService {
  CoachClientRowsService();

  SupabaseClient get _c => Supabase.instance.client;

  Future<List<CoachClientRow>> listForClient({
    required String coachId,
    required String clientId,
  }) async {
    final rows = await _c
        .from('coach_client_rows')
        .select()
        .eq('coach_id', coachId)
        .eq('client_id', clientId)
        .order('row_date', ascending: false)
        .order('created_at', ascending: false);

    return (rows as List? ?? const [])
        .map((e) => CoachClientRow.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
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
    await _c.from('coach_client_rows').insert({
      'coach_id': coachId,
      'client_id': clientId,
      'row_date': rowDateIso,
      'muscle': muscle,
      'exercise': exercise,
      'sets': sets,
      'reps': reps,
      'weight': weight,
      'weight_unit': weightUnit,
      'notes': notes,
    });
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
    await _c
        .from('coach_client_rows')
        .update({
          'row_date': rowDateIso,
          'muscle': muscle,
          'exercise': exercise,
          'sets': sets,
          'reps': reps,
          'weight': weight,
          'weight_unit': weightUnit,
          'notes': notes,
        })
        .eq('id', id)
        .eq('coach_id', coachId)
        .eq('client_id', clientId);
  }

  Future<void> delete({
    required String id,
    required String coachId,
    required String clientId,
  }) async {
    await _c
        .from('coach_client_rows')
        .delete()
        .eq('id', id)
        .eq('coach_id', coachId)
        .eq('client_id', clientId);
  }
}

