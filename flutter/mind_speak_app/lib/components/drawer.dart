import 'package:flutter/material.dart';
import 'package:mind_speak_app/controllers/ProfileController.dart';
import 'package:mind_speak_app/pages/homepage.dart';
import 'package:mind_speak_app/pages/profilepage.dart';
import 'package:mind_speak_app/pages/searchpage.dart';
import 'package:mind_speak_app/pages/carsfrom.dart';
import 'package:mind_speak_app/pages/predict.dart';
import 'package:mind_speak_app/pages/avatarpages/aggregatestats.dart';
import 'package:mind_speak_app/pages/avatarpages/sessionreportCL.dart';
import 'package:mind_speak_app/pages/logout.dart';
import 'package:mind_speak_app/providers/color_provider.dart';
import 'package:provider/provider.dart';
import 'package:mind_speak_app/providers/theme_provider.dart';
import 'package:mind_speak_app/providers/session_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NavigationDrawe extends StatefulWidget {
  const NavigationDrawe({super.key});

  @override
  State<NavigationDrawe> createState() => _NavigationDraweState();
}

class _NavigationDraweState extends State<NavigationDrawe> {
  String? childName;
  String? childPhoto;

  @override
  void initState() {
    super.initState();
    fetchChildInfo();
  }

  Future<void> fetchChildInfo() async {
    final sessionProvider =
        Provider.of<SessionProvider>(context, listen: false);

    final userId = sessionProvider.userId;
    if (userId == null) return;

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('child')
          .where('userId', isEqualTo: userId)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final data = querySnapshot.docs.first.data();
        setState(() {
          childName = data['name'];
          childPhoto = data['childPhoto'];
        });
      }
    } catch (e) {
      print('❌ Error fetching child info: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
     final colorProvider = Provider.of<ColorProvider>(context);
    final isDark = themeProvider.isDarkMode;

    final backgroundColor = isDark ? Colors.grey[900] : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final iconColor = isDark ? Colors.white : Colors.blueGrey;

    return Drawer(
      child: Container(
        color: backgroundColor,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              // ✅ Remove const
              decoration: BoxDecoration(
                gradient: LinearGradient(
               colors: themeProvider.isDarkMode
          ? [Colors.grey[900]!, Colors.black]
          : [
              colorProvider.primaryColor,
              colorProvider.primaryColor.withAlpha(229) // 0.9 * 255 = 229
            ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              accountName: Text(
                "Welcome, $childName",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              accountEmail: null,
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                backgroundImage:
                    childPhoto != null ? NetworkImage(childPhoto!) : null,
                child: childPhoto == null
                    ? const Icon(Icons.person, color: Colors.blueGrey, size: 36)
                    : null,
              ),
            ),
            _buildSectionTitle("Main", textColor),
            _buildDrawerItem(
              icon: Icons.home,
              label: "Home",
              iconColor: iconColor,
              textColor: textColor,
              onTap: () => _navigate(context, const HomePage()),
            ),
            _buildDrawerItem(
              icon: Icons.person,
              label: "Profile",
              iconColor: iconColor,
              textColor: textColor,
              onTap: () => _navigate(
                  context, ProfilePage(controller: ProfileController())),
            ),
            _buildDrawerItem(
              icon: Icons.settings,
              label: "Settings",
              iconColor: iconColor,
              textColor: textColor,
              onTap: () => Navigator.pop(context),
            ),
            Divider(color: isDark ? Colors.grey : Colors.blueGrey[100]),
            _buildSectionTitle("Therapy Tools", textColor),
            _buildDrawerItem(
              icon: Icons.search,
              label: "Search Therapist",
              iconColor: iconColor,
              textColor: textColor,
              onTap: () => _navigate(context, const SearchPage()),
            ),
            _buildDrawerItem(
              icon: Icons.mobile_screen_share,
              label: "Prediction",
              iconColor: iconColor,
              textColor: textColor,
              onTap: () => _navigate(context, const PredictScreen()),
            ),
            _buildDrawerItem(
              icon: Icons.info_sharp,
              label: "Cars Details",
              iconColor: iconColor,
              textColor: textColor,
              onTap: () => _navigate(context, const CarsForm()),
            ),
            Divider(color: isDark ? Colors.grey : Colors.blueGrey[100]),
            _buildSectionTitle("Progress", textColor),
            _buildDrawerItem(
              icon: Icons.report,
              label: "Overall Progress",
              iconColor: iconColor,
              textColor: textColor,
              onTap: () => _navigate(context, const AggregateStatsPage()),
            ),
            _buildDrawerItem(
              icon: Icons.insert_chart_outlined,
              label: "Last Session Report",
              iconColor: iconColor,
              textColor: textColor,
              onTap: () => _navigate(context, const SessionReportPage()),
            ),
            Divider(color: isDark ? Colors.grey : Colors.blueGrey[100]),
            _buildDrawerItem(
              icon: Icons.logout,
              label: "Logout",
              iconColor: Colors.red,
              textColor: Colors.red,
              onTap: () => logout(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String label,
    required Color iconColor,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(
        label,
        style: TextStyle(
            color: textColor, fontSize: 16, fontWeight: FontWeight.w500),
      ),
      onTap: onTap,
    );
  }

  Widget _buildSectionTitle(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
      child: Text(
        title,
        style: TextStyle(
        color: color.withAlpha(179), // 0.7 * 255 = 178.5 ≈ 179
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _navigate(BuildContext context, Widget page) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }
}
