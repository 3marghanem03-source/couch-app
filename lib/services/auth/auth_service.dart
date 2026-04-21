import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/user.dart' as models;
import '../../models/user_role.dart';
import '../../core/config/app_config.dart';
import '../oracle/oracle_auth_service.dart';

/// Supabase Auth + `public.users` profile row.
class AuthService {
  AuthService();

  SupabaseClient get _c => Supabase.instance.client;
  final OracleAuthService _oracle = OracleAuthService();

  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) {
    return _c.auth.signUp(email: email, password: password);
  }

  /// Sign up, ensure a session (handles email-confirm-off flow), then write `public.users`.
  Future<void> signUpWithProfile({
    required String email,
    required String password,
    required String name,
    required UserRole role,
    String? coachCode,
  }) async {
    if (AppConfig.useOracleApi) {
      await _oracle.signUpWithProfile(
        email: email,
        password: password,
        name: name,
        role: role,
        coachCode: coachCode,
      );
      return;
    }
    try {
      await signUp(email: email, password: password);
    } on AuthApiException catch (e) {
      // Common dev loop: user taps sign up repeatedly which keeps sending confirmation emails.
      // If the user already exists, prefer sign-in to avoid resending.
      if (e.code == 'user_already_exists') {
        await signIn(email: email, password: password);
      } else if (int.tryParse('${e.statusCode}') == 429 && e.code == 'over_email_send_rate_limit') {
        throw Exception(
          'Email rate limit exceeded for this project. Wait a bit, or use Sign in if the account already exists. '
          'For fastest emulator testing, disable “Confirm email” in Supabase Auth → Providers → Email.',
        );
      } else {
        rethrow;
      }
    }

    var uid = _c.auth.currentUser?.id;
    if (uid == null) {
      // If email confirmation is disabled, sign-up may not establish a session; signing in will.
      await signIn(email: email, password: password);
      uid = _c.auth.currentUser?.id;
    }
    if (uid == null) {
      throw Exception(
        'Could not establish a session after sign-up. If email confirmation is on in Supabase, confirm your email then use Sign in.',
      );
    }
    final resolvedCoachId = (role == UserRole.client)
        ? await resolveCoachIdFromCode(coachCode?.trim())
        : null;

    await saveUserProfile(
      id: uid,
      name: name,
      role: role,
      coachId: resolvedCoachId,
    );
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    if (AppConfig.useOracleApi) {
      await _oracle.signIn(email: email, password: password);
      return;
    }
    await _c.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() => AppConfig.useOracleApi ? _oracle.signOut() : _c.auth.signOut();

  /// Loads `public.users` for the signed-in auth user, or null if missing / not signed in.
  Future<models.User?> getCurrentUser() async {
    if (AppConfig.useOracleApi) {
      return _oracle.getCurrentUser();
    }
    final session = _c.auth.currentSession;
    if (session == null) return null;
    final row = await _c.from('users').select().eq('id', session.user.id).maybeSingle();
    if (row == null) return null;
    final m = Map<String, dynamic>.from(row);
    final roleStr = (m['role'] as String?) ?? 'client';
    return models.User(
      id: m['id'] as String,
      name: (m['name'] as String?)?.trim().isNotEmpty == true ? m['name'] as String : 'User',
      role: roleStr == 'coach' ? UserRole.coach : UserRole.client,
      coachId: m['coach_id'] as String?,
      inviteCode: m['invite_code'] as String?,
      avatarUrl: m['avatar_url'] as String?,
      sessionsRemaining: 0,
    );
  }

  /// Creates or updates the profile row (call right after `signUp`).
  Future<void> saveUserProfile({
    required String id,
    required String name,
    required UserRole role,
    String? coachId,
  }) async {
    await _c.from('users').upsert({
      'id': id,
      'name': name.trim(),
      'role': role == UserRole.coach ? 'coach' : 'client',
      if (coachId != null) 'coach_id': coachId,
    });
  }

  Future<String?> resolveCoachIdFromCode(String? code) async {
    if (AppConfig.useOracleApi) return null;
    final trimmed = code?.trim().toUpperCase();
    if (trimmed == null || trimmed.isEmpty) return null;
    final row = await _c.from('users').select('id').eq('role', 'coach').eq('invite_code', trimmed).maybeSingle();
    return row?['id'] as String?;
  }

  Future<String?> fetchFirstCoachId() async {
    if (AppConfig.useOracleApi) return null;
    final row = await _c.from('users').select('id').eq('role', 'coach').limit(1).maybeSingle();
    if (row == null) return null;
    return row['id'] as String?;
  }

  Future<List<models.User>> listClients() async {
    if (AppConfig.useOracleApi) return [];
    final uid = _c.auth.currentUser?.id;
    if (uid == null) return [];
    final rows = await _c
        .from('users')
        .select()
        .eq('role', 'client')
        .eq('coach_id', uid)
        .order('name');
    return (rows as List? ?? const []).map((r) {
      final m = Map<String, dynamic>.from(r as Map);
      return models.User(
        id: m['id'] as String,
        name: (m['name'] as String?)?.trim().isNotEmpty == true ? m['name'] as String : 'Client',
        role: UserRole.client,
        coachId: m['coach_id'] as String?,
        avatarUrl: m['avatar_url'] as String?,
        sessionsRemaining: 0,
      );
    }).toList();
  }
}
