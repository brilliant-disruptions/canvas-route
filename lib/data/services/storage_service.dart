import 'dart:io';

import 'package:uuid/uuid.dart';

import '../supabase_client.dart';

/// Supabase Storage uploads. Paths are `<uid>/<uuid>.<ext>` so bucket RLS can
/// scope writes to the owner's folder.
class StorageService {
  static const visitPhotos = 'visit-photos';
  static const pinPhotos = 'pin-photos';
  static const avatars = 'avatars';

  Future<String> upload(String bucket, File file) async {
    final uid = requireUserId();
    final ext = file.path.split('.').last.toLowerCase();
    final path = '$uid/${const Uuid().v4()}.${ext.isEmpty ? 'jpg' : ext}';
    await sb.storage.from(bucket).upload(path, file);
    return path;
  }

  String publicUrl(String bucket, String path) => sb.storage.from(bucket).getPublicUrl(path);

  Future<String> signedUrl(String bucket, String path, {int seconds = 3600}) =>
      sb.storage.from(bucket).createSignedUrl(path, seconds);

  Future<void> remove(String bucket, String path) => sb.storage.from(bucket).remove([path]);
}
