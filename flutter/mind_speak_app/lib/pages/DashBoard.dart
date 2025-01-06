import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mind_speak_app/components/CustomBottomNavigationBar.dart';
import 'package:mind_speak_app/providers/theme_provider.dart';
import 'package:mind_speak_app/service/database.dart';

import 'package:provider/provider.dart';

class MyApp extends StatelessWidget {
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

  final DatabaseMethods databaseMethods = DatabaseMethods();
  List<Map<String, String>> users = [];

  int currentPage = 0;
  int itemsPerPage = 5;

  @override
  void initState() {
    super.initState();
    fetchCounts();
  }

  Future<void> fetchCounts() async {
    try {
      int users = await databaseMethods.getUsersCount();
      int therapists = await databaseMethods.getTherapistsCount();
      setState(() {
        usersCount = users;
        therapistCount = therapists;
      });
    } catch (e) {
      print('Error fetching counts: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    int totalPages = (users.length / itemsPerPage).ceil();

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
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Name')),
                    DataColumn(label: Text('Email')),
                    DataColumn(label: Text('Mobile')),
                    DataColumn(label: Text('National ID')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: users
                      .skip(currentPage * itemsPerPage)
                      .take(itemsPerPage)
                      .map((user) => DataRow(cells: [
                            DataCell(Text(user['name']!)),
                            DataCell(Text(user['email']!)),
                            DataCell(Text(user['phone']!)),
                            DataCell(Text(user['nationalId']!)),
                            DataCell(Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.check,
                                      color: Colors.green),
                                  onPressed: () {
                                    setState(() {
                                      users.remove(user);
                                    });
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close,
                                      color: Colors.red),
                                  onPressed: () {
                                    setState(() {
                                      users.remove(user);
                                    });
                                  },
                                ),
                              ],
                            ))
                          ]))
                      .toList(),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: currentPage > 0
                        ? () {
                            setState(() {
                              currentPage--;
                            });
                          }
                        : null,
                  ),
                  Text('${currentPage + 1} / $totalPages'),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: currentPage < totalPages - 1
                        ? () {
                            setState(() {
                              currentPage++;
                            });
                          }
                        : null,
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
