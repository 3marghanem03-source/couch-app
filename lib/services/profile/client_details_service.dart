import '../../models/client_details.dart';
import '../oracle/oracle_api.dart';

Map<String, dynamic> _lowerKeys(Map<dynamic, dynamic> m) {
  return {for (final e in m.entries) e.key.toString().toLowerCase(): e.value};
}

class ClientDetailsService {
  ClientDetailsService();

  final OracleApi _api = OracleApi();

  Future<ClientDetails?> getForClient(String clientId) async {
    final raw = await _api.getClientDetails(clientId);
    if (raw == null) return null;
    final m = _lowerKeys(raw);
    final cid = m['client_id']?.toString();
    if (cid == null || cid.isEmpty) return null;
    return ClientDetails(
      clientId: cid,
      coachId: m['coach_id']?.toString() ?? '',
      publicBio: '${m['public_bio'] ?? ''}',
      goals: '${m['goals'] ?? ''}',
      injuries: '${m['injuries'] ?? ''}',
      privateNotes: '${m['private_notes'] ?? ''}',
    );
  }

  Future<void> upsertAsCoach({
    required String clientId,
    required String coachId,
    required String publicBio,
    required String goals,
    required String injuries,
    required String privateNotes,
  }) async {
    await _api.putClientDetailsAsCoach(
      clientId: clientId,
      publicBio: publicBio,
      goals: goals,
      injuries: injuries,
      privateNotes: privateNotes,
    );
  }

  Future<void> updatePublicAsClient({
    required String clientId,
    required String publicBio,
    required String goals,
    required String injuries,
  }) async {
    await _api.patchClientDetailsPublic(
      clientId: clientId,
      publicBio: publicBio,
      goals: goals,
      injuries: injuries,
    );
  }
}
