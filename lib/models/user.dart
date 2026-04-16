import 'user_role.dart';

/// Signed-in person: **id**, **name**, **role**.
///
/// [sessionsRemaining] is mock-only (coach dashboard); omit in API models later if you prefer.
class User {
  const User({
    required this.id,
    required this.name,
    required this.role,
    this.coachId,
    this.inviteCode,
    this.avatarUrl,
    this.sessionsRemaining = 0,
  });

  final String id;
  final String name;
  final UserRole role;
  /// For clients: their linked coach. Null until linked.
  final String? coachId;
  /// For coaches: shareable code clients can use to link.
  final String? inviteCode;
  /// Public URL to avatar in Supabase Storage.
  final String? avatarUrl;
  final int sessionsRemaining;
}
