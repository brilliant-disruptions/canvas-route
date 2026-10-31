import 'dart:typed_data';

import 'package:canvas_route/core/logic/photo_scrub.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('removes GPS and every other EXIF tag', () {
    final src = img.Image(width: 40, height: 20);
    src.exif.gpsIfd['GPSLatitude'] = img.IfdValueRational(32, 1);
    src.exif.imageIfd['Make'] = img.IfdValueAscii('PhoneCo');
    final withGps = img.encodeJpg(src);
    expect(img.decodeJpgExif(withGps)!.gpsIfd.isEmpty, isFalse, reason: 'fixture should carry GPS');

    final out = scrubPhoto(Uint8List.fromList(withGps))!;
    final exif = img.decodeJpgExif(out);
    expect(exif == null || (exif.gpsIfd.isEmpty && exif.imageIfd.isEmpty), isTrue);
    expect(img.decodeJpg(out)!.width, 40);
  });

  test('bakes rotation into the pixels before dropping the orientation tag', () {
    final src = img.Image(width: 40, height: 20);
    src.exif.imageIfd.orientation = 6; // rotate 90° when displayed
    final out = scrubPhoto(Uint8List.fromList(img.encodeJpg(src)))!;
    final back = img.decodeJpg(out)!;
    expect((back.width, back.height), (20, 40));
  });

  test('non-images are rejected', () => expect(scrubPhoto(Uint8List.fromList([1, 2, 3])), isNull));
}
