import 'package:flutter/material.dart';
import '../bloc/scanner_bloc.dart';

// Reusable widget for displaying scan results.

class ResultWidget extends StatelessWidget {
  final ScannerState state;
  const ResultWidget({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    if (state is ScannerLoading) {
      return const CircularProgressIndicator();
    } else if (state is ScannerSuccess) {
      final s = state as ScannerSuccess;
      return Column(
        children: [
          Text('ID: \\${s.id}', style: const TextStyle(fontSize: 18)),
          Text('Name: \\${s.name}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      );
    } else if (state is ScannerNotFound) {
      final s = state as ScannerNotFound;
      return Column(
        children: [
          Text('ID: \\${s.id}', style: const TextStyle(fontSize: 18)),
          const Text('Not found', style: TextStyle(fontSize: 20, color: Colors.red)),
        ],
      );
    } else if (state is ScannerError) {
      final s = state as ScannerError;
      return Text(s.message, style: const TextStyle(color: Colors.red));
    } else {
      return const SizedBox.shrink();
    }
  }
}
