class CoachClientRow {
  CoachClientRow({
    required this.id,
    required this.coachId,
    required this.clientId,
    required this.rowDateIso,
    required this.title,
    required this.value,
    required this.notes,
  });

  final String id;
  final String coachId;
  final String clientId;
  final String rowDateIso; // YYYY-MM-DD
  final String title;
  final String value;
  final String notes;

  static CoachClientRow fromMap(Map<String, dynamic> m) {
    return CoachClientRow(
      id: m['id'] as String,
      coachId: m['coach_id'] as String,
      clientId: m['client_id'] as String,
      rowDateIso: m['row_date'] as String? ?? '',
      title: (m['title'] as String?) ?? '',
      value: (m['value'] as String?) ?? '',
      notes: (m['notes'] as String?) ?? '',
    );
  }
}

