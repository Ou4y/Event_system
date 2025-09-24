import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import '../services/ocr_service.dart';
import '../bloc/scanner_bloc.dart';
import '../widgets/result_widget.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  final TextEditingController _idController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isProcessing = false;

  // Overlay frame size
  static const double overlayWidth = 300;
  static const double overlayHeight = 180;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    _cameras = await availableCameras();
    if (_cameras != null && _cameras!.isNotEmpty) {
      _controller = CameraController(_cameras![0], ResolutionPreset.max, enableAudio: false);
      await _controller!.initialize();
      setState(() {
        _isCameraInitialized = true;
      });
    }
  }

  // Modular function to process image and extract ID
  Future<String?> processCapturedImage(File image) async {
    final ocrService = OcrService();
    return await ocrService.extractIdFromImage(image);
  }

  /// Crops the captured image to the overlay frame (centered horizontal strip)
  Future<File> cropToOverlayFrame(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final original = img.decodeImage(bytes);
    if (original == null) throw Exception('Failed to decode image');

    // Overlay frame dimensions (in dp): 300x180
    // We'll map these to the image's pixel dimensions
    const overlayWidthDp = 300.0;
    const overlayHeightDp = 180.0;
    // CameraPreview is 300x200, so overlay is centered
    final imgW = original.width;
    final imgH = original.height;
    // Calculate scale factor (assume preview box is 300x200)
    final scaleW = imgW / 300.0;
    final scaleH = imgH / 200.0;
    final scale = (scaleW + scaleH) / 2;
    final cropW = (overlayWidthDp * scale).toInt();
    final cropH = (overlayHeightDp * scale).toInt();
    final cropX = ((imgW - cropW) / 2).round();
    final cropY = ((imgH - cropH) / 2).round();
    debugPrint('Cropping image: imgW=$imgW imgH=$imgH cropX=$cropX cropY=$cropY cropW=$cropW cropH=$cropH');
    final cropped = img.copyCrop(
      original,
      x: cropX,
      y: cropY,
      width: cropW,
      height: cropH,
    );
    final tempDir = await getTemporaryDirectory();
    final croppedFile = File('${tempDir.path}/cropped_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await croppedFile.writeAsBytes(img.encodeJpg(cropped));
    return croppedFile;
  }

  Future<void> _captureAndScan(BuildContext context) async {
    if (!_isCameraInitialized || _controller == null) return;
    setState(() { _isProcessing = true; });
    final image = await _controller!.takePicture();
    final file = File(image.path);
    final croppedFile = await cropToOverlayFrame(file);
    final extractedId = await processCapturedImage(croppedFile);
    debugPrint("OCR Extracted Raw: $extractedId");
    String normalizedId = (extractedId ?? '').replaceAll(RegExp(r'[\n\r]'), '').trim();
    debugPrint("OCR Extracted Normalized: $normalizedId");
    setState(() { _isProcessing = false; });
    _idController.text = extractedId ?? '';
    // Optionally, validate and trigger search if valid
    if (normalizedId.isNotEmpty && _validateId(normalizedId) == null) {
      context.read<ScannerBloc>().add(ScanImageEvent(croppedFile));
    }
  }

  String? _validateId(String? value) {
  if (value == null || value.isEmpty) return 'ID required';

  final universityIdReg = RegExp(r'^\d{4}-\d{5}$');  // e.g. 2022-08868
  final nationalIdReg = RegExp(r'^\d{14}$');         // e.g. 29811234567890

  if (universityIdReg.hasMatch(value) || nationalIdReg.hasMatch(value)) {
    return null;
  }
  return 'Enter a valid University ID (YYYY-#####) or 14-digit National ID';
}

  @override
  void dispose() {
    _controller?.dispose();
    _idController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ID Scanner')),
      body: BlocBuilder<ScannerBloc, ScannerState>(
        builder: (context, state) {
          return Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isCameraInitialized && _controller != null)
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: overlayWidth,
                        height: overlayHeight + 60, // extra space for overlay
                        child: CameraPreview(_controller!),
                      ),
                      // Overlay frame
                      Positioned(
                        child: Container(
                          width: overlayWidth,
                          height: overlayHeight,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white, width: 3),
                            borderRadius: BorderRadius.circular(16),
                            color: Colors.transparent,
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.camera_alt),
                  label: _isProcessing ? const Text('Processing...') : const Text('Capture & Scan ID'),
                  onPressed: _isCameraInitialized && !_isProcessing ? () => _captureAndScan(context) : null,
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: TextFormField(
                    controller: _idController,
                    decoration: const InputDecoration(
                      labelText: 'Enter or confirm ID',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.text,
                    validator: _validateId,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d-]')),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Check ID'),
                  onPressed: () {
                    final id = _idController.text.trim();
                    final error = _validateId(id);
                    if (error == null) {
                      // Dispatch event with entered ID (no image needed)
                      context.read<ScannerBloc>().add(ScanIdEvent(id));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(error)),
                      );
                    }
                  },
                ),
                const SizedBox(height: 32),
                ResultWidget(state: state),
              ],
            ),
          );
        },
      ),
    );
  }
}
