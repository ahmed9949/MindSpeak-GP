import 'package:flutter/material.dart';
import 'package:mind_speak_app/components/homepageCards.dart';
import 'package:mind_speak_app/logout.dart';
import 'package:mind_speak_app/sessionpage.dart';
 
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    const title = 'Horizontal Manga';

    // List of data for dynamic rendering
    final List<Map<String, dynamic>> data = [
      {'color': Colors.green, 'text': 'Action'},
      {'color': Colors.red, 'text': 'Romance'},
      {'color': Colors.blue, 'text': 'Adventure'},
      {'color': Colors.purple, 'text': 'Fantasy'},
      {'color': Colors.orange, 'text': 'Mystery'},
      {'color': const Color.fromARGB(255, 197, 207, 197), 'text': 'Sci-Fi'},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(title),
      ),
      // Added Drawer
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue, // Drawer Header Background
              ),
              child: Text(
                'Menu',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home), // Home Icon
              title: const Text('Home'),
              onTap: () {
                Navigator.pop(context); // Close drawer
              },
            ),
            ListTile(
              leading: const Icon(Icons.person), // Profile Icon
              title: const Text('Profile'),
              onTap: () {
                // TODO: Navigate to Profile Page
                Navigator.pop(context); // Close drawer
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings), // Settings Icon
              title: const Text('Settings'),
              onTap: () {
                // TODO: Navigate to Settings Page
                Navigator.pop(context); // Close drawer
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () {
                logout(context); // Call the logout function
              },
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0), // Padding around the Column
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center, // Align to the start
          children: [
            // Horizontal Scrollable Row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: data.map((item) {
                  return smallcard(
                    color: item['color'], // Dynamic color
                    text: item['text'], // Dynamic text
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 20), // Space between row and bigger card

            // Bigger Card
            Container(
              width: double.infinity, // Take full width
              height: 200, // Bigger height
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(25),
              ),
              child: const Center(
                child: Text(
                  'Big Card',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24, // Bigger font size
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20), // Add some space before the button

            // Button to start the session
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SessionPage()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, // Button background color
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              ),
              child: const Text(
                'Start the session',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
