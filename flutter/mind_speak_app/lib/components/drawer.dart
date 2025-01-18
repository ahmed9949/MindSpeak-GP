import 'package:flutter/material.dart';
import 'package:mind_speak_app/pages/homepage.dart';
import 'package:mind_speak_app/pages/logout.dart';
import 'package:mind_speak_app/pages/predict.dart';
import 'package:mind_speak_app/pages/profilepage.dart';

class NavigationDrawe extends StatelessWidget {
  const NavigationDrawe({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          const DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.blue,
            ),
            child: Text(
              'Navigation Drawer',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Home'),
           onTap: () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => const HomePage()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Profile'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => const ProfilePage()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),    
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context);
            },
          ),
           ListTile(
            leading: const Icon(Icons.mobile_screen_share),
            title: const Text('Prediction'),
           onTap: () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => const Predict()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () {
              logout(context);
            },
          ),
        ],
      ),
    );
  }
}
