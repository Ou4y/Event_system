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
    final text = recognizedText.text;
    // Try to match university ID (YYYY-#####)
    final universityIdMatch = RegExp(r'\b\d{4}-\d{5}\b').firstMatch(text);
    if (universityIdMatch != null) {
      return universityIdMatch.group(0);
    }
    // Try to match 14-digit national ID
    final nationalIdMatch = RegExp(r'\b\d{14}\b').firstMatch(text.replaceAll(RegExp(r'\D'), ''));
    if (nationalIdMatch != null) {
      return nationalIdMatch.group(0);
    }
    // Fallback: return the raw text for debugging
    return null;
  }
}
