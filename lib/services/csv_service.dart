// Service for loading and searching student records from CSV.
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class StudentRecord {
  final String universityId;
  final String nationalId;
  final String name;

  StudentRecord({required this.universityId, required this.nationalId, required this.name});
}

class CsvService {
  static final CsvService _instance = CsvService._internal();
  factory CsvService() => _instance;
  CsvService._internal();

  List<StudentRecord> _students = [];
  bool _loaded = false;

  Future<void> loadCsv() async {
    if (_loaded) return;
    final csvString = await rootBundle.loadString('assets/csv/students.csv');
    final lines = LineSplitter.split(csvString).toList();
    if (lines.isNotEmpty) lines.removeAt(0); // Remove header
    _students = lines.map((line) {
      final parts = line.split(',');
      if (parts.length < 3) return null;
      return StudentRecord(
        universityId: parts[0],
        nationalId: parts[1],
        name: parts[2],
      );
    }).whereType<StudentRecord>().toList();
    _loaded = true;
  }

  Future<StudentRecord?> findById(String id) async {
    await loadCsv();
    try {
      return _students.firstWhere(
        (student) => student.universityId == id || student.nationalId == id,
      );
    } catch (e) {
      return null;
    }
  }
}
