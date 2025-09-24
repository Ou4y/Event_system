import 'dart:io';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../services/csv_service.dart';
import '../services/ocr_service.dart';

part 'scanner_event.dart';
part 'scanner_state.dart';

class ScannerBloc extends Bloc<ScannerEvent, ScannerState> {
  final CsvService csvService;
  final OcrService ocrService;

  ScannerBloc({required this.csvService, required this.ocrService}) : super(ScannerInitial()) {
    on<ScanImageEvent>(_onScanImage);
    on<ScanIdEvent>(_onScanId);
  }

  Future<void> _onScanImage(ScanImageEvent event, Emitter<ScannerState> emit) async {
    emit(ScannerLoading());
    try {
      final id = await ocrService.extractIdFromImage(event.imageFile);
      if (id == null) {
        emit(const ScannerError(message: 'No valid ID found.'));
        return;
      }
      final student = await csvService.findById(id);
      if (student != null) {
        emit(ScannerSuccess(id: id, name: student.name));
      } else {
        emit(ScannerNotFound(id: id));
      }
    } catch (e) {
      emit(ScannerError(message: 'Error: \\${e.toString()}'));
    }
  }

  Future<void> _onScanId(ScanIdEvent event, Emitter<ScannerState> emit) async {
    emit(ScannerLoading());
    try {
      final student = await csvService.findById(event.id);
      if (student != null) {
        emit(ScannerSuccess(id: event.id, name: student.name));
      } else {
        emit(ScannerNotFound(id: event.id));
      }
    } catch (e) {
      emit(ScannerError(message: 'Error: \\${e.toString()}'));
    }
  }
}
