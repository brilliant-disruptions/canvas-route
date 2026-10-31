// Strips photo metadata before upload. Pure Dart (package:image), so it runs in a
// background isolate and is unit-testable.
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Re-encodes [bytes] as a JPEG with no EXIF, so no GPS position, device or
/// timestamp leaves the phone. The EXIF orientation is applied to the pixels first
/// so the photo still displays upright. Returns null if the bytes aren't an image.
Uint8List? scrubPhoto(Uint8List bytes, {int quality = 75}) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  final upright = img.bakeOrientation(decoded);
  upright.exif = img.ExifData();
  return img.encodeJpg(upright, quality: quality);
}
