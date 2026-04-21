import '../../models/client_details.dart';

class ClientDetailsService {
  ClientDetailsService();

  Future<ClientDetails?> getForClient(String clientId) async {
    return null;
  }

  Future<void> upsertAsCoach({
    required String clientId,
    required String coachId,
    required String publicBio,
    required String goals,
    required String injuries,
    required String privateNotes,
  }) async {
    throw StateError('Client details are not available in Oracle-only mode yet.');
  }

  Future<void> updatePublicAsClient({
    required String clientId,
    required String publicBio,
    required String goals,
    required String injuries,
  }) async {
    throw StateError('Client details are not available in Oracle-only mode yet.');
  }
}

