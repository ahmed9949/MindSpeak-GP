 import 'package:flutter/material.dart';
import 'package:mind_speak_app/start_session.dart';

class ChooseAvatarPage extends StatefulWidget {
  const ChooseAvatarPage({super.key});

  @override
  State<ChooseAvatarPage> createState() => _ChooseAvatarPageState();
}

class _ChooseAvatarPageState extends State<ChooseAvatarPage> {
  // List of avatar image paths
  final List<String> avatars = [
    'assets/superheros/american-cartoon-celebrating-independence-day_1012-159.avif',
    'assets/superheros/cute-astronaut-super-hero-cartoon-vector-icon-illustration-science-technology-icon_138676-1997.avif',
    'assets/superheros/download.png',
    'assets/superheros/girl-hero-costume_1308-25840.avif',
    'assets/superheros/hand-drawing-little-angry-hulk-vector-illustration_969863-196047.avif',
  ];

  // Selected Avatar
  String selectedAvatar =
      'assets/superheros/hand-drawing-little-angry-hulk-vector-illustration_969863-196047.avif'; // Default avatar

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Your Avatar'),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Display Selected Avatar in a Bigger Card
          Container(
            width: 300, // Wider card
            height: 350, // Taller card
            decoration: BoxDecoration(
              color: const Color(
                  0xFFFFF5E1), // Child-friendly pastel yellow background
              borderRadius: BorderRadius.circular(25),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Larger Avatar Image
                CircleAvatar(
                  radius: 100, // Increased radius for larger size
                  backgroundImage:
                      AssetImage(selectedAvatar), // Display selected avatar
                ),
                const SizedBox(height: 10),
                const Text(
                  'Your Selected Avatar',
                  style: TextStyle(
                    color: Colors.black, // Text color for readability
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Horizontal Scrollable Slider for Avatars
          SizedBox(
            height: 120, // Height for the slider
            child: ListView.builder(
              scrollDirection: Axis.horizontal, // Horizontal scroll
              itemCount: avatars.length,
              itemBuilder: (context, index) {
                final avatar = avatars[index];

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedAvatar = avatar; // Update selected avatar
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.all(8.0),
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: selectedAvatar == avatar
                            ? Colors.blue // Highlight selected card
                            : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Image.asset(
                        avatar,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20), // Spacing between card and button

          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const StartSession(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(50),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
            ),
            child: const Text(
              'start the session',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),

     );
  }
}
