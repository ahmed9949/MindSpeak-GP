import 'package:flutter/material.dart';
import 'package:mind_speak_app/components/children_list.dart';
import 'package:mind_speak_app/pages/logout.dart';
import 'package:mind_speak_app/providers/theme_provider.dart';
import 'package:mind_speak_app/service/doctor_dashboard_service.dart';
import 'package:provider/provider.dart';
import 'doctor_details_page.dart';

class DoctorDashboard extends StatefulWidget {
  final String sessionId;
  final Map<String, dynamic> therapistInfo;
  final Map<String, dynamic> userInfo;

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

  List<Map<String, dynamic>> children = [];
  bool isLoading = true;

  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();

    doctorName = widget.userInfo['username'] ?? 'Doctor';
    specialization = widget.therapistInfo['bio'] ?? 'Specialization';

    _loadChildrenData();
  }

  void _loadChildrenData() async {
    List<Map<String, dynamic>> fetchedChildren =
        await _doctorServices.fetchChildren(widget.sessionId);
    setState(() {
      children = fetchedChildren;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    final pages = [
      ChildrenList(
        children: children,
        isLoading: isLoading,
        doctorServices: _doctorServices,
      ),
      DoctorDetailsPage(sessionId: widget.sessionId, userInfo: widget.userInfo, therapistInfo: widget.therapistInfo), // Use the external page
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Welcome, $doctorName",
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              "$specialization | ${children.length} patients",
              style: const TextStyle(fontSize: 14, color: Colors.white70),
            ),
          ],
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
        child: const Icon(Icons.refresh, color: Colors.black,),
        backgroundColor: Colors.blue,
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
