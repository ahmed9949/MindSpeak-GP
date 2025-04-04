// // lib/widgets/blind_camera.dart

// import 'package:flutter/material.dart';
// import 'package:camera/camera.dart';

// class BlindCamera extends StatelessWidget {
//   final CameraController controller;

//   const BlindCamera({
//     Key? key,
//     required this.controller,
//   }) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       width: 1,
//       height: 1,
//       child: controller.value.isInitialized
//           ? AspectRatio(
//               aspectRatio: 1,
//               child: CameraPreview(controller),
//             )
//           : Container(),
//     );
//   }
// }
