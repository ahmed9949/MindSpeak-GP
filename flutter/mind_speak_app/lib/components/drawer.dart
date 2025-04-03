import 'package:flutter/material.dart';
import 'package:mind_speak_app/controllers/ProfileController.dart';
import 'package:mind_speak_app/pages/avatarpages/aggregatestats.dart';
import 'package:mind_speak_app/pages/carsfrom.dart';
import 'package:mind_speak_app/pages/homepage.dart';
import 'package:mind_speak_app/pages/logout.dart';
import 'package:mind_speak_app/pages/predict.dart';
import 'package:mind_speak_app/pages/profilepage.dart';
import 'package:mind_speak_app/pages/searchpage.dart';
import 'package:mind_speak_app/pages/avatarpages/sessionreportCL.dart';
import 'package:provider/provider.dart';
import 'package:mind_speak_app/providers/theme_provider.dart';

class NavigationDrawe extends StatelessWidget {
  const NavigationDrawe({super.key});

  @override
  Widget build(BuildContext context) {
    // Access the current theme provider
    final themeProvider = Provider.of<ThemeProvider>(context);

    // Set colors dynamically based on the theme
    final backgroundColor =
        themeProvider.isDarkMode ? Colors.grey[900] : Colors.blue;
    final textColor = themeProvider.isDarkMode ? Colors.white : Colors.black;
    final iconColor = themeProvider.isDarkMode ? Colors.white : Colors.black;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          DrawerHeader(
            decoration: BoxDecoration(
              color: backgroundColor,
            ),
            child: Text(
              'Navigation Drawer',
              style: TextStyle(
                color: textColor,
                fontSize: 24,
              ),
            ),
          ),
          ListTile(
            leading: Icon(Icons.home, color: iconColor),
            title: Text(
              'Home',
              style: TextStyle(color: textColor),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => const HomePage()));
            },
          ),
          ListTile(
            leading: Icon(Icons.person, color: iconColor),
            title: Text(
              'Profile',
              style: TextStyle(color: textColor),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          ProfilePage(controller: ProfileController())));
            },
          ),
          ListTile(
            leading: Icon(Icons.settings, color: iconColor),
            title: Text(
              'Settings',
              style: TextStyle(color: textColor),
            ),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: Icon(Icons.search, color: iconColor),
            title: Text(
              'Search therapist',
              style: TextStyle(color: textColor),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => const SearchPage()));
            },
          ),
          ListTile(
            leading: Icon(Icons.mobile_screen_share, color: iconColor),
            title: Text(
              'Prediction',
              style: TextStyle(color: textColor),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const PredictScreen()));
            },
          ),
          ListTile(
            leading: Icon(Icons.info_sharp, color: iconColor),
            title: Text(
              'Cars Details',
              style: TextStyle(color: textColor),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => const CarsForm()));
            },
          ),
          ListTile(
            leading: Icon(Icons.logout, color: iconColor),
            title: Text(
              'Logout',
              style: TextStyle(color: textColor),
            ),
            onTap: () {
              logout(context);
            },
          ),
          ListTile(
            leading: Icon(Icons.report, color: iconColor),
            title: Text(
              'over all progress',
              style: TextStyle(color: textColor),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const AggregateStatsPage()));
            },
          ),
          ListTile(
            leading: Icon(Icons.report, color: iconColor),
            title: Text(
              'last session report',
              style: TextStyle(color: textColor),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const SessionReportPage()));
            },
          ),
        ],
      ),
    );
  }
}
