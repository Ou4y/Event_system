part of 'scanner_bloc.dart';

abstract class ScannerState extends Equatable {
  const ScannerState();
  @override
  List<Object?> get props => [];
}

class ScannerInitial extends ScannerState {}
class ScannerLoading extends ScannerState {}
class ScannerSuccess extends ScannerState {
  final String id;
  final String name;
  const ScannerSuccess({required this.id, required this.name});
  @override
  List<Object?> get props => [id, name];
}
class ScannerNotFound extends ScannerState {
  final String id;
  const ScannerNotFound({required this.id});
  @override
  List<Object?> get props => [id];
}
class ScannerError extends ScannerState {
  final String message;
  const ScannerError({required this.message});
  @override
  List<Object?> get props => [message];
}
