import 'package:flutter/material.dart';
import 'package:mind_speak_app/controllers/ProfileController.dart';
import 'package:mind_speak_app/pages/homepage.dart';
import 'package:mind_speak_app/pages/profilepage.dart';
import 'package:mind_speak_app/pages/searchpage.dart';
import 'package:provider/provider.dart';
import 'package:mind_speak_app/providers/theme_provider.dart';

class Navigationpage extends StatefulWidget {
  const Navigationpage({super.key});

  @override
  State<Navigationpage> createState() => _NavigationpageState();
}

class _NavigationpageState extends State<Navigationpage> {
  int myindex = 0;
  List<Widget> mypages = [
    const HomePage(),
    const SearchPage(),
    ProfilePage(controller: ProfileController()),
  ];

  @override
  Widget build(BuildContext context) {
    // Get the theme from provider
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      body: IndexedStack(
        index: myindex,
        children: mypages,
      ),
      bottomNavigationBar: Theme(
        // Apply theme to BottomNavigationBar
        data: themeProvider.currentTheme.copyWith(
          canvasColor: themeProvider.isDarkMode ? Colors.black : Colors.white,
        ),
        child: BottomNavigationBar(
          showUnselectedLabels: false,
          type: BottomNavigationBarType.shifting,
          onTap: (index) {
            setState(() {
              myindex = index;
            });
          },
          currentIndex: myindex,
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.home),
              label: 'Home',
              backgroundColor:
                  themeProvider.isDarkMode ? Colors.blueGrey[900] : Colors.blue,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.search),
              label: 'Search',
              backgroundColor: themeProvider.isDarkMode
                  ? Colors.blueGrey[800]
                  : Colors.green,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.person),
              label: 'Profile',
              backgroundColor:
                  themeProvider.isDarkMode ? Colors.blueGrey[700] : Colors.red,
            ),
          ],
        ),
      ),
    );
  }
}
