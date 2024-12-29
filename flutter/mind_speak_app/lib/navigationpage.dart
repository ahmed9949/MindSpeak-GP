 
import 'package:flutter/material.dart';
import 'package:mind_speak_app/homepage.dart';
import 'package:mind_speak_app/profilepage.dart';
import 'package:mind_speak_app/searchpage.dart';

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
    const ProfilePage(),
  ];
  @override
  Widget build(BuildContext context) {

    return MaterialApp(
      
      home: Scaffold(
        body: Center(
          child: mypages[myindex],
        ),
        bottomNavigationBar: BottomNavigationBar(
          showUnselectedLabels: false,
          type: BottomNavigationBarType.shifting,
          onTap: (index) {
            setState(() {
              myindex = index;
            });
          },
          currentIndex: myindex,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
              backgroundColor: Colors.blue,
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.search),
              label: 'Search',
              backgroundColor: Colors.green,
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profile',
              backgroundColor: Colors.red,
            ),
          ],
        ),
      ),
    );
  }
}
