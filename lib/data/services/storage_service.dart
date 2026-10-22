import 'package:cross_file/cross_file.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../supabase_client.dart';

/// Supabase Storage uploads. Paths are `<uid>/<uuid>.<ext>` so bucket RLS can
/// scope writes to the owner's folder.
class StorageService {
  static const visitPhotos = 'visit-photos';
  static const pinPhotos = 'pin-photos';
  static const avatars = 'avatars';

  Future<String> upload(String bucket, XFile file) async {
    final uid = requireUserId();
    final name = file.name.isNotEmpty ? file.name : file.path;
    final dot = name.lastIndexOf('.');
    final ext = dot == -1 ? 'jpg' : name.substring(dot + 1).toLowerCase();
    final path = '$uid/${const Uuid().v4()}.$ext';
    await sb.storage.from(bucket).uploadBinary(
          path,
          await file.readAsBytes(),
          fileOptions: FileOptions(contentType: file.mimeType ?? 'image/$ext'),
        );
    return path;
  }

  String publicUrl(String bucket, String path) => sb.storage.from(bucket).getPublicUrl(path);

  Future<String> signedUrl(String bucket, String path, {int seconds = 3600}) =>
      sb.storage.from(bucket).createSignedUrl(path, seconds);

  Future<void> remove(String bucket, String path) => sb.storage.from(bucket).remove([path]);
}
