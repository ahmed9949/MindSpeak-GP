// import 'package:flutter/material.dart';
// import 'package:mind_speak_app/pages/choose_avatar_page.dart';
// import 'package:mind_speak_app/providers/theme_provider.dart';
// import 'package:mind_speak_app/pages/start_session.dart';
// import 'package:provider/provider.dart';

// class SessionPage extends StatelessWidget {
//   const SessionPage({super.key});

//   @override
//   Widget build(BuildContext context) {
//     final themeProvider = Provider.of<ThemeProvider>(context);

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Session Page'),
//         actions: [
//           IconButton(
//             icon: Icon(themeProvider.isDarkMode
//                 ? Icons.wb_sunny
//                 : Icons.nightlight_round),
//             onPressed: () {
//               themeProvider.toggleTheme(); // Toggle the theme
//             },
//           ),
//         ],
//       ),
//       body: Center(
//         child: Column(
//           mainAxisAlignment:
//               MainAxisAlignment.center, // Center content vertically
//           crossAxisAlignment: CrossAxisAlignment.center, // Center horizontally
//           children: [
//             // Bigger Card with Avatar Image
//             Container(
//               width: 250,
//               height: 300,
//               decoration: BoxDecoration(
//                 color: const Color(0xFFFFF5E1),
//                 borderRadius: BorderRadius.circular(25),
//               ),
//               child: const Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   // Avatar Image
//                   CircleAvatar(
//                     radius: 60, // Size of avatar
//                     backgroundImage: AssetImage(
//                         'assets/images/superheros/american-cartoon-celebrating-independence-day_1012-159.avif'), // Replace with your image
//                   ),
//                   SizedBox(height: 10), // Spacing
//                   Text(
//                     'This is your avatar',
//                     style: TextStyle(
//                       color: Color.fromARGB(255, 243, 163, 4),
//                       fontSize: 18,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                 ],
//               ),
//             ),

//             const SizedBox(height: 20), // Spacing between card and button

//             // Button to Navigate to Choose Avatar Page
//             ElevatedButton(
//               onPressed: () {
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(
//                     builder: (context) => const ChooseAvatarPage(),
//                   ),
//                 );
//               },
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.red,
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(50),
//                 ),
//                 padding:
//                     const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
//               ),
//               child: const Text(
//                 'Choose Avatar',
//                 style: TextStyle(
//                   color: Colors.white,
//                   fontSize: 16,
//                 ),
//               ),
//             ),
//             const SizedBox(height: 20), // Spacing between card and button

//             // Button to Navigate to Choose Avatar Page
//             ElevatedButton(
//               onPressed: () {
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(
//                     builder: (context) => const StartSession(),
//                   ),
//                 );
//               },
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.blue,
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(50),
//                 ),
//                 padding:
//                     const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
//               ),
//               child: const Text(
//                 'start the session',
//                 style: TextStyle(
//                   color: Colors.white,
//                   fontSize: 16,
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
