// Service for OCR and ID extraction using google_mlkit_text_recognition.

import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  static final OcrService _instance = OcrService._internal();
  factory OcrService() => _instance;
  OcrService._internal();

  // Helper to convert Arabic numerals to English numerals
  String _arabicToEnglishDigits(String input) {
    const arabic = ['٠','١','٢','٣','٤','٥','٦','٧','٨','٩'];
    const english = ['0','1','2','3','4','5','6','7','8','9'];
    for (int i = 0; i < arabic.length; i++) {
      input = input.replaceAll(arabic[i], english[i]);
    }
    return input;
  }

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
    // Try to match 14-digit national ID (Arabic or English digits)
    final arabicOrEnglishDigits = RegExp(r'[\d٠-٩]{14}');
    final match = arabicOrEnglishDigits.firstMatch(text);
    if (match != null) {
      String id = match.group(0)!;
      id = _arabicToEnglishDigits(id);
      return id;
    }
    // Fallback: return null
    return null;
  }
}
