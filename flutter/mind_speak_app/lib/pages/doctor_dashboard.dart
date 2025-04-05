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

    final pages = [
      Column(
        children: [
          // Add the dashboard count cards component
          DashboardCountCards(
            sessionId: widget.sessionId,
            children: children,
          ),
          // Then display the existing children list
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
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.logout),
          onPressed: () => logout(context),
        ),
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
        backgroundColor: Colors.blue,
        title: const Text(
          "Therapist Dashboard",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadChildrenData,
        backgroundColor: Colors.blue,
        child: const Icon(
          Icons.refresh,
          color: Colors.black,
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
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
