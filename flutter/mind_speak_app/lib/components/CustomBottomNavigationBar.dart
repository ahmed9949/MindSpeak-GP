import 'package:flutter/material.dart';
import 'package:mind_speak_app/pages/ViewDoctorPage.dart';
import 'package:mind_speak_app/pages/adminDashboard.dart';

import 'package:mind_speak_app/pages/login.dart';

class CustomBottomNavigationBar extends StatelessWidget {
  final int currentIndex;

  const CustomBottomNavigationBar({
    super.key,
    required this.currentIndex,
  });

  void _onItemTapped(BuildContext context, int index) {
    if (index == 0 && currentIndex != 0) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AdminDashboardView()),
      );
    } else if (index == 1 && currentIndex != 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ViewDoctors()),
      );
    } else if (index == 2) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LogIn()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      backgroundColor: Colors.blue,
      currentIndex: currentIndex,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Colors.white,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home, color: Colors.white),
          label: "Home",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person, color: Colors.white),
          label: "View Therapist",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.logout, color: Colors.white),
          label: "Logout",
        ),
      ],
      onTap: (index) => _onItemTapped(context, index),
    );
  }
}
