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

  static int? _int(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static double? _double(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static CoachClientRow fromMap(Map<String, dynamic> m) {
    return CoachClientRow(
      id: '${m['id']}',
      coachId: '${m['coach_id']}',
      clientId: '${m['client_id']}',
      rowDateIso: '${m['row_date'] ?? ''}',
      muscle: '${m['muscle'] ?? ''}',
      exercise: '${m['exercise'] ?? ''}',
      sets: _int(m['sets']),
      reps: _int(m['reps']),
      weight: _double(m['weight']),
      weightUnit: '${m['weight_unit'] ?? ''}',
      notes: '${m['notes'] ?? ''}',
    );
  }
}
