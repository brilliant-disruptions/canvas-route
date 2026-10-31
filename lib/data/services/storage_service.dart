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

  /// Phone photos are 3–5 MB. At 1280 px and quality 70 a sign or haul photo is
  /// ~150 KB and still sharp on a phone, so the free tier's 1 GB holds ~6,000.
  static const photoMaxWidth = 1280.0;
  static const photoQuality = 70;

  Future<String> upload(String bucket, XFile file) async {
    final uid = requireUserId();
    final name = file.name.isNotEmpty ? file.name : file.path;
    final dot = name.lastIndexOf('.');
    final ext = dot == -1 ? 'jpg' : name.substring(dot + 1).toLowerCase();
    final path = '$uid/${const Uuid().v4()}.$ext';
    await sb.storage.from(bucket).uploadBinary(
          path,
          await file.readAsBytes(),
          // Names are unique and never rewritten, so the CDN may keep them for a year;
          // cached bandwidth bills at a third of the uncached rate.
          fileOptions: FileOptions(contentType: file.mimeType ?? 'image/$ext', cacheControl: '31536000'),
        );
    return path;
  }

  String publicUrl(String bucket, String path) => sb.storage.from(bucket).getPublicUrl(path);

  Future<String> signedUrl(String bucket, String path, {int seconds = 3600}) =>
      sb.storage.from(bucket).createSignedUrl(path, seconds);

  Future<void> remove(String bucket, String path) => sb.storage.from(bucket).remove([path]);
}
