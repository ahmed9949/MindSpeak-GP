import 'package:flutter/material.dart';
import 'package:mind_speak_app/components/CustomBottomNavigationBar.dart';
import 'package:mind_speak_app/providers/theme_provider.dart';
import 'package:mind_speak_app/service/AdminRepository.dart';
import 'package:provider/provider.dart';
 
class  MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: DashBoard(),
    );
  }
}

class DashBoard extends StatefulWidget {
  const DashBoard({super.key});

  @override
  State<DashBoard> createState() => _DashBoardState();
}

class _DashBoardState extends State<DashBoard> {
  int usersCount = 0;
  int therapistCount = 0;
  bool showUsersCount = false;
  bool showTherapistCount = false;

  final AdminRepository adminRepository = AdminRepository();
  List<Map<String, dynamic>> therapists = [];

  int currentPage = 1;
  int itemsPerPage = 5;
  int totalPages = 1;

  @override
  void initState() {
    super.initState();
    fetchCounts();
    fetchTherapistRequests();
  }

  Future<void> fetchCounts() async {
    try {
      int users = await adminRepository.getUsersCount();
      int therapistsCount = await adminRepository.getTherapistsCount();
      setState(() {
        usersCount = users;
        therapistCount = therapistsCount;
      });
    } catch (e) {
      print('Error fetching counts: $e');
    }
  }

  Future<void> fetchTherapistRequests() async {
    try {
      List<Map<String, dynamic>> tempTherapists =
          await adminRepository.getPendingTherapistRequests();
      setState(() {
        therapists = tempTherapists;
        totalPages = (therapists.length / itemsPerPage).ceil();
        if (currentPage > totalPages)
          currentPage = totalPages > 0 ? totalPages : 1;
      });
    } catch (e) {
      print('Error fetching therapist requests: $e');
    }
  }

  Future<void> approveTherapist(String therapistId) async {
    try {
      await adminRepository.approveTherapist(therapistId);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Therapist approved successfully!'),
        backgroundColor: Colors.green,
      ));
      setState(() {
        therapists
            .removeWhere((therapist) => therapist['userid'] == therapistId);
        totalPages = (therapists.length / itemsPerPage).ceil();
        if (currentPage > totalPages)
          currentPage = totalPages > 0 ? totalPages : 1;
      });
    } catch (e) {
      print('Error approving therapist: $e');
    }
  }

  Future<void> rejectTherapist(String therapistId) async {
    try {
      await adminRepository.rejectTherapist(therapistId);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Therapist rejected and removed!'),
        backgroundColor: Colors.red,
      ));
      setState(() {
        therapists
            .removeWhere((therapist) => therapist['userid'] == therapistId);
        totalPages = (therapists.length / itemsPerPage).ceil();
        if (currentPage > totalPages)
          currentPage = totalPages > 0 ? totalPages : 1;
      });
    } catch (e) {
      print('Error rejecting therapist: $e');
    }
  }

  void nextPage() {
    if (currentPage < totalPages) {
      setState(() {
        currentPage++;
      });
    }
  }

  void previousPage() {
    if (currentPage > 1) {
      setState(() {
        currentPage--;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

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
        centerTitle: true,
        backgroundColor: Colors.blue,
        title: const Text(
          "Admin Dashboard",
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                showUsersCount = !showUsersCount;
                              });
                            },
                            child: const Icon(Icons.person,
                                size: 40, color: Colors.blue),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            "Users",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          if (showUsersCount)
                            Text(
                              "$usersCount",
                              style: const TextStyle(
                                fontSize: 20,
                                color: Colors.black,
                              ),
                            ),
                        ],
                      ),
                      Column(
                        children: [
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                showTherapistCount = !showTherapistCount;
                              });
                            },
                            child: const Icon(Icons.medical_services,
                                size: 40, color: Colors.green),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            "Therapists",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          if (showTherapistCount)
                            Text(
                              "$therapistCount",
                              style: const TextStyle(
                                fontSize: 20,
                                color: Colors.black,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Center(
                child: Text(
                  'Therapist Requests',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: therapists.isNotEmpty
                    ? DataTable(
                        columns: const [
                          DataColumn(label: Text('Name')),
                          DataColumn(label: Text('Email')),
                          DataColumn(label: Text('National ID')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: therapists
                            .skip((currentPage - 1) * itemsPerPage)
                            .take(itemsPerPage)
                            .map((therapist) => DataRow(cells: [
                                  DataCell(Text(therapist['username'])),
                                  DataCell(Text(therapist['email'])),
                                  DataCell(Text(therapist['nationalid'])),
                                  DataCell(Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.check,
                                            color: Colors.green),
                                        onPressed: () => approveTherapist(
                                            therapist['userid']),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.close,
                                            color: Colors.red),
                                        onPressed: () => rejectTherapist(
                                            therapist['userid']),
                                      ),
                                    ],
                                  ))
                                ]))
                            .toList(),
                      )
                    : const Center(
                        child: Text('No therapist requests available'),
                      ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: previousPage,
                    child: const Text(
                      'Previous',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                  Text(
                    '$currentPage of $totalPages',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: nextPage,
                    child: const Text(
                      'Next',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const CustomBottomNavigationBar(currentIndex: 0),
    );
  }
}
