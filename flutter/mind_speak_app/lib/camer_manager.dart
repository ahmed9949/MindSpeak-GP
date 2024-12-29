// import 'dart:io';
// import 'package:camera/camera.dart';
// import 'package:face_emotion_detector/face_emotion_detector.dart';

// class CameraManager {
//   late CameraController controller;

//   Future<void> initializeCamera() async {
//     final cameras = await availableCameras();
//     controller = CameraController(cameras[0], ResolutionPreset.high, enableAudio: false);
//     await controller.initialize();
//     startImageStream();
//   }

//   void startImageStream() {
//     controller.startImageStream((CameraImage image) async {
//       try {
//         final detector = EmotionDetector();
//         // Convert the CameraImage to a format EmotionDetector can understand
//         final file = await convertImageToFile(image);
//         final label = await detector.detectEmotionFromImage(image: file);
//         print(label);
//         file.delete(); // Optionally delete the file after processing if needed
//       } catch (e) {
//         print('Error detecting emotions from stream: $e');
//       }
//     });
//   }

//   Future<File> convertImageToFile(CameraImage image) async {
//     // Conversion logic here. This depends on how the face_emotion_detector expects the image data
//     // This often involves converting CameraImage to a File or directly to bytes that the model can process
//     // This might involve saving the image to a temporary file and passing the file to the model
//     return File('path_to_temp_file');
//   }
// }