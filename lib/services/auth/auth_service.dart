import '../../models/user.dart' as models;
import '../../models/user_role.dart';
import '../../core/config/app_config.dart';
import '../oracle/oracle_api.dart';
import '../oracle/oracle_auth_service.dart';

/// Oracle-backed auth via `backend-oracle`.
class AuthService {
  AuthService();

  final OracleAuthService _oracle = OracleAuthService();
  final OracleApi _api = OracleApi();

  /// Sign up, ensure a session (handles email-confirm-off flow), then write `public.users`.
  Future<void> signUpWithProfile({
    required String email,
    required String password,
    required String name,
    required UserRole role,
    String? coachCode,
  }) async {
    if (!AppConfig.useOracleApi) {
      throw StateError('Oracle API is not configured. Set ORACLE_API_BASE_URL in assets/app.env.example.');
    }
    await _oracle.signUpWithProfile(
      email: email,
      password: password,
      name: name,
      role: role,
      coachCode: coachCode,
    );
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    if (!AppConfig.useOracleApi) {
      throw StateError('Oracle API is not configured. Set ORACLE_API_BASE_URL in assets/app.env.example.');
    }
    await _oracle.signIn(email: email, password: password);
  }

  Future<void> signOut() => _oracle.signOut();

  /// Loads `public.users` for the signed-in auth user, or null if missing / not signed in.
  Future<models.User?> getCurrentUser() async {
    if (!AppConfig.useOracleApi) return null;
    return _oracle.getCurrentUser();
  }

  Future<String?> resolveCoachIdFromCode(String? code) async {
    // Oracle signup handles coach codes server-side.
    return null;
  }

  Future<String?> fetchFirstCoachId() async {
    final u = await getCurrentUser();
    if (u?.coachId != null && u!.coachId!.isNotEmpty) return u.coachId;
    return null;
  }

  Future<List<models.User>> listClients() async {
    final rows = await _api.listCoachClients();
    return rows.map((r) {
      final roleStr = (r['role'] ?? r['ROLE'] ?? 'client').toString();
      return models.User(
        id: (r['id'] ?? r['ID']).toString(),
        name: (r['name'] ?? r['NAME'] ?? 'Client').toString(),
        role: roleStr == 'coach' ? UserRole.coach : UserRole.client,
        coachId: (r['coach_id'] ?? r['COACH_ID'])?.toString(),
        inviteCode: (r['invite_code'] ?? r['INVITE_CODE'])?.toString(),
        avatarUrl: (r['avatar_url'] ?? r['AVATAR_URL'])?.toString(),
        sessionsRemaining: 0,
      );
    }).toList();
  }
}
