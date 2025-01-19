import 'package:flutter/material.dart';
import 'package:mind_speak_app/components/homepageCards.dart';
import 'package:mind_speak_app/components/drawer.dart';
import 'package:mind_speak_app/providers/theme_provider.dart';
import 'package:mind_speak_app/pages/sessionpage.dart';
import 'package:provider/provider.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    const title = 'Horizontal Manga';

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
        actions: [
          IconButton(
            icon: Icon(themeProvider.isDarkMode
                ? Icons.wb_sunny
                : Icons.nightlight_round),
            onPressed: () {
              themeProvider.toggleTheme();
            },
          ),
        ],
        title: const Text(title),
      ),
      drawer: NavigationDrawe(),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: data.map((item) {
                  return smallcard(
                    color: item['color'],
                    text: item['text'],
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 100),

           
            const BiggerCard(),
            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const HomePage()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
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
