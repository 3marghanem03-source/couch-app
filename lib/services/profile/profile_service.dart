import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileService {
  ProfileService();

  SupabaseClient get _c => Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();

  Future<void> updateName(String name) async {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) throw StateError('Please sign in to continue.');
    await _c.from('users').update({'name': name.trim()}).eq('id', uid);
  }

  Future<void> setCoachByCode(String coachCode) async {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) throw StateError('Please sign in to continue.');
    final code = coachCode.trim().toUpperCase();
    if (code.isEmpty) throw StateError('Please enter your coach code.');
    final coach = await _c.from('users').select('id').eq('role', 'coach').eq('invite_code', code).maybeSingle();
    final coachId = coach?['id'] as String?;
    if (coachId == null) throw StateError('That coach code doesn’t look right. Please check it and try again.');
    await _c.from('users').update({'coach_id': coachId}).eq('id', uid);
  }

  /// Picks an image and uploads to Storage bucket `avatars` under `uid/`.
  /// Returns the public URL.
  Future<String?> pickAndUploadAvatar() async {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) throw StateError('Please sign in to continue.');

    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 85,
    );
    if (file == null) return null;

    final Uint8List bytes = await file.readAsBytes();
    final ext = (file.name.split('.').lastOrNull ?? 'jpg').toLowerCase();
    final path = '$uid/avatar.$ext';

    await _c.storage.from('avatars').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: ext == 'png' ? 'image/png' : 'image/jpeg',
          ),
        );

    final url = _c.storage.from('avatars').getPublicUrl(path);
    await _c.from('users').update({'avatar_url': url}).eq('id', uid);
    return url;
  }
}

extension _LastOrNull on List<String> {
  String? get lastOrNull => isEmpty ? null : last;
}

