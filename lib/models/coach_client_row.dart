class CoachClientRow {
  CoachClientRow({
    required this.id,
    required this.coachId,
    required this.clientId,
    required this.rowDateIso,
    required this.muscle,
    required this.exercise,
    required this.sets,
    required this.reps,
    required this.weight,
    required this.weightUnit,
    required this.notes,
  });

  final String id;
  final String coachId;
  final String clientId;
  final String rowDateIso; // YYYY-MM-DD
  final String muscle;
  final String exercise;
  final int? sets;
  final int? reps;
  final double? weight;
  final String weightUnit;
  final String notes;

  static CoachClientRow fromMap(Map<String, dynamic> m) {
    return CoachClientRow(
      id: m['id'] as String,
      coachId: m['coach_id'] as String,
      clientId: m['client_id'] as String,
      rowDateIso: m['row_date'] as String? ?? '',
      muscle: (m['muscle'] as String?) ?? '',
      exercise: (m['exercise'] as String?) ?? '',
      sets: (m['sets'] as int?),
      reps: (m['reps'] as int?),
      weight: (m['weight'] as num?)?.toDouble(),
      weightUnit: (m['weight_unit'] as String?) ?? '',
      notes: (m['notes'] as String?) ?? '',
    );
  }
}

