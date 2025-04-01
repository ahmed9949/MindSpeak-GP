// lib/services/camera_service.dart

import 'package:camera/camera.dart';
import 'dart:convert';
import 'package:image/image.dart' as img;

class CameraService {
  CameraController? controller; // Changed from _controller to controller to make it accessible
  bool _isInitialized = false;

  Future<void> initialize() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      throw 'No cameras available';
    }

    // Use the front camera
    final frontCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    controller = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    await controller!.initialize();
    _isInitialized = true;
  }

  Future<String> captureFrame() async {
    if (!_isInitialized || controller == null) {
      throw 'Camera not initialized';
    }

    try {
      final image = await controller!.takePicture();
      final bytes = await image.readAsBytes();
      
      // Resize and compress the image
      final decodedImage = img.decodeImage(bytes);
      if (decodedImage == null) throw 'Failed to decode image';
      
      final resizedImage = img.copyResize(
        decodedImage,
        width: 224,
        height: 224,
      );
      
      final jpegBytes = img.encodeJpg(resizedImage, quality: 85);
      return base64Encode(jpegBytes);
    } catch (e) {
      print('Error capturing frame: $e');
      rethrow;
    }
  }

  void dispose() {
    controller?.dispose();
    _isInitialized = false;
  }

  bool get isInitialized => _isInitialized;
}