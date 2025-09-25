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

  // Flash state
  bool _isFlashOn = false;
  bool _hasFlash = false;

  // FIX 3: Create service instance once for efficiency
  final OcrService _ocrService = OcrService();

  // Overlay frame size
  static const double overlayWidth = 300;
  static const double overlayHeight = 180;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        _controller = CameraController(
          _cameras![0],
          // FIX 3: Use a more performant resolution
          ResolutionPreset.high,
          enableAudio: false,
        );
        await _controller!.initialize();
        // Remove unsupported flash checks
        // FIX 2: Add mounted check for stability
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
        }
      }
    } catch (e) {
      debugPrint("Error initializing camera: $e");
    }
  }

  // Use the service instance variable
  Future<String?> processCapturedImage(File image) async {
    return await _ocrService.extractIdFromImage(image);
  }

  // FIX 1: Robust Image Cropping Logic
  Future<File> cropToOverlayFrame(XFile imageFile) async {
    final imageBytes = await imageFile.readAsBytes();
    final originalImage = img.decodeImage(imageBytes);
    if (originalImage == null) {
      throw Exception('Failed to decode image');
    }

    // Get the aspect ratio of the camera preview (as defined in the UI)
    const previewHeight = overlayHeight + 60;
    const previewWidth = overlayWidth;
    const previewAspectRatio = previewWidth / previewHeight;

    // Get the aspect ratio of the actual image captured by the sensor
    final imageAspectRatio = originalImage.width / originalImage.height;

    double scale;
    int cropX, cropY, cropWidth, cropHeight;

    // Calculate the correct crop coordinates by comparing aspect ratios
    if (previewAspectRatio > imageAspectRatio) {
      scale = originalImage.width / previewWidth;
      final scaledPreviewHeight = originalImage.height / scale;
      cropWidth = (overlayWidth * scale).toInt();
      cropHeight = (overlayHeight * scale).toInt();
      cropX = ((originalImage.width - cropWidth) / 2).toInt();
      cropY = (((scaledPreviewHeight - overlayHeight) / 2) * scale).toInt();
    } else {
      scale = originalImage.height / previewHeight;
      final scaledPreviewWidth = originalImage.width / scale;
      cropWidth = (overlayWidth * scale).toInt();
      cropHeight = (overlayHeight * scale).toInt();
      cropX = (((scaledPreviewWidth - overlayWidth) / 2) * scale).toInt();
      cropY = ((originalImage.height - cropHeight) / 2).toInt();
    }
    
    final croppedImage = img.copyCrop(
      originalImage,
      x: cropX,
      y: cropY,
      width: cropWidth,
      height: cropHeight,
    );

    final tempDir = await getTemporaryDirectory();
    final croppedFile = File('${tempDir.path}/cropped_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await croppedFile.writeAsBytes(img.encodeJpg(croppedImage));
    return croppedFile;
  }

  
 // In your _ScannerScreenState class

Future<void> _captureAndScan() async {
  if (!_isCameraInitialized || _controller == null || _isProcessing) return;

  setState(() { _isProcessing = true; });

  try {
    // 1. Lock focus before capturing
    await _controller!.setFocusMode(FocusMode.locked);
    await _controller!.setFocusMode(FocusMode.auto);

    // 2. Capture the image
    final image = await _controller!.takePicture();
    
    // 3. Process the image
    final croppedFile = await cropToOverlayFrame(image);
    final extractedId = await processCapturedImage(croppedFile);

    debugPrint("OCR Extracted Raw: $extractedId");
    String normalizedId = (extractedId ?? '').replaceAll(RegExp(r'[\s\n\r]'), '').trim();
    debugPrint("OCR Extracted Normalized: $normalizedId");
    
    if (!mounted) return;

    _idController.text = normalizedId;
    // Show a message if OCR fails
    if (normalizedId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not read ID. Please try again.')),
      );
    } else if (_validateId(normalizedId) == null) {
      context.read<ScannerBloc>().add(ScanImageEvent(croppedFile));
    }
  } catch (e) {
    debugPrint("Error during capture and scan: $e");
    if(mounted){
       ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  } finally {
    // 4. Unlock focus and resume preview
    if (_controller != null && _controller!.value.isInitialized) {
      await _controller!.setFocusMode(FocusMode.locked);
      await _controller!.setFocusMode(FocusMode.auto);
    }
    if (mounted) {
      setState(() { _isProcessing = false; });
    }
  }
}

  Future<void> _toggleFlash() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    try {
      if (_isFlashOn) {
        await _controller!.setFlashMode(FlashMode.off);
      } else {
        await _controller!.setFlashMode(FlashMode.torch);
      }
      setState(() {
        _isFlashOn = !_isFlashOn;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No flash available on this device.')),
        );
      }
      debugPrint('Failed to toggle flash: $e');
    }
  }

  String? _validateId(String? value) {
    if (value == null || value.isEmpty) return 'ID required';
    final universityIdReg = RegExp(r'^\d{4}-\d{5}$'); // e.g. 2022-08868
    final nationalIdReg = RegExp(r'^\d{14}$'); // e.g. 29811234567890
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
          if (!_isCameraInitialized) {
            return const Center(child: CircularProgressIndicator());
          }
          return Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Use ClipRRect to constrain the CameraPreview's view
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16.0),
                        child: SizedBox(
                          width: overlayWidth,
                          height: overlayHeight + 60,
                          child: CameraPreview(_controller!),
                        ),
                      ),
                      // Overlay frame
                      Container(
                        width: overlayWidth,
                        height: overlayHeight,
                        decoration: BoxDecoration(
                          border: Border.all(color: _isProcessing ? Colors.orange : Colors.white, width: 3),
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      // Flash toggle button (top right corner of preview)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: IconButton(
                          icon: Icon(_isFlashOn ? Icons.flash_on : Icons.flash_off, color: Colors.yellowAccent, size: 32),
                          onPressed: _toggleFlash,
                          tooltip: _isFlashOn ? 'Turn Flash Off' : 'Turn Flash On',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.camera_alt),
                    label: _isProcessing
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Capture & Scan ID'),
                    onPressed: _isCameraInitialized && !_isProcessing ? _captureAndScan : null,
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
                      if (_formKey.currentState?.validate() ?? false) {
                        context.read<ScannerBloc>().add(ScanIdEvent(id));
                      } else {
                         ScaffoldMessenger.of(context).showSnackBar(
                           const SnackBar(content: Text('Please enter a valid ID')),
                         );
                      }
                    },
                  ),
                  const SizedBox(height: 32),
                  ResultWidget(state: state),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}