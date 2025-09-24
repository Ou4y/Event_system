part of 'scanner_bloc.dart';

abstract class ScannerEvent extends Equatable {
  const ScannerEvent();
  @override
  List<Object?> get props => [];
}

class ScanImageEvent extends ScannerEvent {
  final File imageFile;
  const ScanImageEvent(this.imageFile);
  @override
  List<Object?> get props => [imageFile];
}

class ScanIdEvent extends ScannerEvent {
  final String id;
  const ScanIdEvent(this.id);
  @override
  List<Object?> get props => [id];
}
