import 'package:flutter/material.dart';
import 'package:mind_speak_app/components/drawer.dart';
import 'package:mind_speak_app/pages/child_reports.dart';
import 'package:mind_speak_app/providers/theme_provider.dart';
import 'package:mind_speak_app/service/database.dart';
import 'package:provider/provider.dart';

class DoctorDashboard extends StatefulWidget {
  const DoctorDashboard({super.key});

  @override
  _DoctorDashboardState createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard> {
  final String doctorName = "Dr. Ahmed";
  final String specialization = "Pediatric Autism Specialist";
  final DatabaseMethods _databaseMethods = DatabaseMethods();

  List<Map<String, dynamic>> children = [];
  List<Map<String, dynamic>> reports = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchChildren();
  }

  Future<void> fetchChildren() async {
    try {
      List<Map<String, dynamic>> fetchedChildren =
          await _databaseMethods.getAllChildren();
      setState(() {
        children = fetchedChildren;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching children: $e')),
      );
    }
  }

  //De func 3ashan ageb el reports bat3t el child b el id bta3O
  Future<void> fetchReport(String childId) async {
    try {
      List<Map<String, dynamic>> fetchedReports =
          await _databaseMethods.fetchReportsForChild(childId);
      setState(() {
        reports = fetchedReports;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching reports: $e')),
      );
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
        backgroundColor: Colors.teal,
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
      drawer: NavigationDrawe(),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : children.isEmpty
              ? const Center(child: Text("No children found"))
              : Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.teal[50]!, Colors.teal[100]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  padding: const EdgeInsets.all(16.0),
                  child: ListView.builder(
                    itemCount: children.length,
                    itemBuilder: (context, index) {
                      final child = children[index];
                      return InkWell(
                        onTap: () async {
                          try {
                            final childId = child['childId']; 
                            await fetchReport(childId);

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChildReportsPage(
                                  childName: child[
                                      'name'], 
                                  reports: reports,
                                ),
                              ),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text('Error fetching reports: $e')),
                            );
                          }
                        },
                        child: Card(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          elevation: 6,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 20, horizontal: 16),
                            leading: CircleAvatar(
                              backgroundColor: Colors.teal[200],
                              child: Text(
                                child['name'][0],
                                style: const TextStyle(
                                    fontSize: 18, color: Colors.white),
                              ),
                            ),
                            title: Text(
                              child['name'],
                              style: const TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                            trailing: const Icon(
                              Icons.arrow_forward_ios,
                              color: Colors.teal,
                              size: 20,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
