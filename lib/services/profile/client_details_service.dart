import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/client_details.dart';

class ClientDetailsService {
  ClientDetailsService();

  SupabaseClient get _c => Supabase.instance.client;

  Future<ClientDetails?> getForClient(String clientId) async {
    final row = await _c
        .from('client_details')
        .select()
        .eq('client_id', clientId)
        .maybeSingle();
    if (row == null) return null;
    final m = Map<String, dynamic>.from(row);
    return ClientDetails(
      clientId: m['client_id'] as String,
      coachId: m['coach_id'] as String,
      publicBio: (m['public_bio'] as String?) ?? '',
      goals: (m['goals'] as String?) ?? '',
      injuries: (m['injuries'] as String?) ?? '',
      privateNotes: (m['private_notes'] as String?) ?? '',
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
    await _c.from('client_details').upsert({
      'client_id': clientId,
      'coach_id': coachId,
      'public_bio': publicBio,
      'goals': goals,
      'injuries': injuries,
      'private_notes': privateNotes,
    });
  }

  Future<void> updatePublicAsClient({
    required String clientId,
    required String publicBio,
    required String goals,
    required String injuries,
  }) async {
    await _c.from('client_details').update({
      'public_bio': publicBio,
      'goals': goals,
      'injuries': injuries,
    }).eq('client_id', clientId);
  }
}

