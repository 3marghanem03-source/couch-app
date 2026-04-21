import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

class ProfileService {
  ProfileService();

  final ImagePicker _picker = ImagePicker();

  Future<void> updateName(String name) async {
    throw StateError('Profile editing is not available in Oracle-only mode yet.');
  }

  Future<void> setCoachByCode(String coachCode) async {
    throw StateError('Coach linking is not available in Oracle-only mode yet.');
  }

  /// Picks an image and uploads to Storage bucket `avatars` under `uid/`.
  /// Returns the public URL.
  Future<String?> pickAndUploadAvatar() async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 85,
    );
    if (file == null) return null;

    // Keep picker behavior so the UI doesn't break, but uploading needs an Oracle Storage/API.
    final Uint8List _ = await file.readAsBytes();
    throw StateError('Avatar upload is not available in Oracle-only mode yet.');
  }
}

