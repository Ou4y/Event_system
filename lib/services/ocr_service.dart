// Service for OCR and ID extraction using google_mlkit_text_recognition.

import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  static final OcrService _instance = OcrService._internal();
  factory OcrService() => _instance;
  OcrService._internal();

  Future<String?> extractIdFromImage(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
    await textRecognizer.close();
    final text = recognizedText.text.replaceAll(RegExp(r'\s+'), '');
    // Extract 9 or 14 digit numbers
    final matches = RegExp(r'\b(\d{9}|\d{14})\b').allMatches(text);
    for (final match in matches) {
      final id = match.group(0);
      if (id != null && (id.length == 9 || id.length == 14)) {
        return id;
      }
    }
    return null;
  }
}
