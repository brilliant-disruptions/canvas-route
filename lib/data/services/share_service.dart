import 'dart:convert';
import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

class ShareService {
  Future<void> shareCsv(String csv, String fileName, {String? subject}) async {
    // In-memory file so this works on web as well as mobile.
    final file = XFile.fromData(utf8.encode(csv), mimeType: 'text/csv', name: fileName);
    await SharePlus.instance.share(ShareParams(
      files: [file],
      fileNameOverrides: [fileName],
      subject: subject,
    ));
  }

  Future<void> shareImage(Uint8List png, String fileName, {String? text, String? subject}) async {
    final file = XFile.fromData(png, mimeType: 'image/png', name: fileName);
    await SharePlus.instance.share(ShareParams(
      files: [file],
      fileNameOverrides: [fileName],
      text: text,
      subject: subject,
    ));
  }

  Future<void> shareText(String text, {String? subject}) =>
      SharePlus.instance.share(ShareParams(text: text, subject: subject));
}
