// import 'package:flutter/material.dart';
// import 'package:mind_speak_app/providers/theme_provider.dart';
// import 'package:mind_speak_app/pages/start_session.dart';
// import 'package:provider/provider.dart';

// class ChooseAvatarPage extends StatefulWidget {
//   const ChooseAvatarPage({super.key});

//   @override
//   State<ChooseAvatarPage> createState() => _ChooseAvatarPageState();
// }

// class _ChooseAvatarPageState extends State<ChooseAvatarPage> {
//   final List<String> avatars = [
//     'assets/images/superheros/american-cartoon-celebrating-independence-day_1012-159.avif',
//     'assets/images/superheros/cute-astronaut-super-hero-cartoon-vector-icon-illustration-science-technology-icon_138676-1997.avif',
//     'assets/images/superheros/download.png',
//     'assets/images/superheros/girl-hero-costume_1308-25840.avif',
//     'assets/images/superheros/hand-drawing-little-angry-hulk-vector-illustration_969863-196047.avif',
//   ];

//   String selectedAvatar =
//       'assets/images/superheros/hand-drawing-little-angry-hulk-vector-illustration_969863-196047.avif';

//   @override
//   Widget build(BuildContext context) {
//     final themeProvider = Provider.of<ThemeProvider>(context);

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Choose Your Avatar'),
//         actions: [
//           IconButton(
//             icon: Icon(themeProvider.isDarkMode
//                 ? Icons.wb_sunny
//                 : Icons.nightlight_round),
//             onPressed: () {
//               themeProvider.toggleTheme();
//             },
//           ),
//         ],
//       ),
//       body: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Container(
//             width: 300,
//             height: 350,
//             decoration: BoxDecoration(
//               color: const Color(0xFFFFF5E1),
//               borderRadius: BorderRadius.circular(25),
//             ),
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 CircleAvatar(
//                   radius: 100,
//                   backgroundImage: AssetImage(selectedAvatar),
//                 ),
//                 const SizedBox(height: 10),
//                 const Text(
//                   'Your Selected Avatar',
//                   style: TextStyle(
//                     color: Colors.black,
//                     fontSize: 18,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ],
//             ),
//           ),

//           const SizedBox(height: 20),

//           SizedBox(
//             height: 120,
//             child: ListView.builder(
//               scrollDirection: Axis.horizontal,
//               itemCount: avatars.length,
//               itemBuilder: (context, index) {
//                 final avatar = avatars[index];

//                 return GestureDetector(
//                   onTap: () {
//                     setState(() {
//                       selectedAvatar = avatar;
//                     });
//                   },
//                   child: Container(
//                     margin: const EdgeInsets.all(8.0),
//                     width: 100,
//                     height: 100,
//                     decoration: BoxDecoration(
//                       color: Colors.grey[300],
//                       borderRadius: BorderRadius.circular(15),
//                       border: Border.all(
//                         color: selectedAvatar == avatar
//                             ? Colors.blue
//                             : Colors.transparent,
//                         width: 3,
//                       ),
//                     ),
//                     child: ClipRRect(
//                       borderRadius: BorderRadius.circular(15),
//                       child: Image.asset(
//                         avatar,
//                         fit: BoxFit.cover,
//                       ),
//                     ),
//                   ),
//                 );
//               },
//             ),
//           ),
//           const SizedBox(height: 20), // Spacing between card and button

//           ElevatedButton(
//             onPressed: () {
//               Navigator.push(
//                 context,
//                 MaterialPageRoute(
//                   builder: (context) => const StartSession(),
//                 ),
//               );
//             },
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.blue,
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(50),
//               ),
//               padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
//             ),
//             child: const Text(
//               'start the session',
//               style: TextStyle(
//                 color: Colors.white,
//                 fontSize: 16,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
