import 'package:flutter/material.dart';
import 'package:mind_speak_app/components/children_list.dart';
import 'package:mind_speak_app/components/dashboard_count_card.dart';

import 'package:mind_speak_app/models/Child.dart';
import 'package:mind_speak_app/models/Therapist.dart';
import 'package:mind_speak_app/models/User.dart';
import 'package:mind_speak_app/pages/logout.dart';
import 'package:mind_speak_app/providers/theme_provider.dart';
import 'package:mind_speak_app/service/doctor_dashboard_service.dart';
import 'package:provider/provider.dart';
import 'doctor_details_page.dart';

class DoctorDashboard extends StatefulWidget {
  final String sessionId;
  final TherapistModel therapistInfo;
  final UserModel userInfo;

  const DoctorDashboard({
    super.key,
    required this.sessionId,
    required this.therapistInfo,
    required this.userInfo,
  });

  @override
  _DoctorDashboardState createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard> {
  late String doctorName;
  late String specialization;
  final DoctorDashboardService _doctorServices = DoctorDashboardService();

  List<ChildModel> children = [];
  bool isLoading = true;

  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();

    doctorName = widget.userInfo.username;
    specialization = widget.therapistInfo.bio;

    _loadChildrenData();
  }

  void _loadChildrenData() async {
    try {
      List<ChildModel> fetchedChildren =
          await _doctorServices.fetchChildren(widget.therapistInfo.therapistId);
      setState(() {
        children = fetchedChildren;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading children: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    final pages = [
      Column(
        children: [
          DashboardCountCards(
            sessionId: widget.sessionId,
            children: children,
          ),
          Expanded(
            child: ChildrenList(
              children: children,
              isLoading: isLoading,
              doctorServices: _doctorServices,
            ),
          ),
        ],
      ),
      DoctorDetailsPage(
        sessionId: widget.sessionId,
        userInfo: widget.userInfo,
        therapistInfo: widget.therapistInfo,
      ),
    ];

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [Colors.grey[850]!, Colors.black]
                  : [Colors.blue.shade400, Colors.deepPurple.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(24),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Logout Button
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.white),
                    onPressed: () => logout(context),
                  ),
                  const Text(
                    "Therapist Dashboard",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  // Theme Toggle
                  IconButton(
                    icon: Icon(
                      isDark ? Icons.wb_sunny : Icons.nightlight_round,
                      color: Colors.white,
                    ),
                    onPressed: () => themeProvider.toggleTheme(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Container(
        color: isDark ? Colors.black : Colors.grey[100],
        child: IndexedStack(
          index: _currentIndex,
          children: pages,
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadChildrenData,
        tooltip: 'Refresh Children Data',
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.refresh, color: Colors.white),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: isDark ? Colors.grey : Colors.black54,
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.group),
            label: 'Patients',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'My Details',
          ),
        ],
      ),
    );
  }
}
