import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:mind_speak_app/camer_manager.dart';
 
class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  late CameraManager _cameraManager;

  @override
  void initState() {
    super.initState();
    _cameraManager = CameraManager();
    _cameraManager.initializeCamera();
  }

  @override
  void dispose() {
    _cameraManager.controller.dispose(); // Properly dispose of the controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Home"),
        centerTitle: true,
      ),
      body: FutureBuilder<void>(
        future: _cameraManager.controller.initialize(), // This ensures the camera is initialized
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            // If the Future is complete, display the preview
            return CameraPreview(_cameraManager.controller);
          } else {
            // Otherwise, display a loading indicator
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}