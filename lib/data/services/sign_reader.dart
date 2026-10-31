import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Reads the words off a photo of a sale sign, on the device (Google ML Kit; no
/// upload, no cost). iOS and Android only; elsewhere [available] is false.
class SignReader {
  bool get available =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android);

  Future<String> read(XFile photo) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await recognizer.processImage(InputImage.fromFilePath(photo.path));
      // Signs are blocks of big text; keep their order, one block per line.
      return result.blocks.map((b) => b.text.replaceAll('\n', ' ')).join('\n');
    } finally {
      await recognizer.close();
    }
  }
}
