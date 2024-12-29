import 'package:flutter/material.dart';
import 'package:mind_speak_app/components/CustomBottomNavigationBar.dart';
import 'package:mind_speak_app/providers/theme_provider.dart';
import 'package:provider/provider.dart';



void main() {
  runApp(const MyApp());
}

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
  int usersCount = 10;
  int doctorsCount = 25;

  bool showUsersCount = false;
  bool showDoctorsCount = false;

  List<Map<String, String>> users = [
    {
      'name': 'Ahmed',
      'email': 'ahmed@gmail.com',
      'phone': '01028200287',
      'nationalId': '1234567890'
    },
    {
      'name': 'Mohamed',
      'email': 'mohamed@gmail.com',
      'phone': '01028200287',
      'nationalId': '1234567891'
    },
    {
      'name': 'Osos',
      'email': 'osos@gmail.com',
      'phone': '01028200287',
      'nationalId': '1234567892'
    },
    {
      'name': 'Fares',
      'email': 'fares@gmail.com',
      'phone': '01028200287',
      'nationalId': '1234567893'
    },
    {
      'name': 'Ali',
      'email': 'ali@gmail.com',
      'phone': '01028200287',
      'nationalId': '1234567894'
    },
    {
      'name': 'Sara',
      'email': 'sara@gmail.com',
      'phone': '01028200287',
      'nationalId': '1234567895'
    },
    {
      'name': 'Nour',
      'email': 'nour@gmail.com',
      'phone': '01028200287',
      'nationalId': '1234567896'
    },
    {
      'name': 'Laila',
      'email': 'laila@gmail.com',
      'phone': '01028200287',
      'nationalId': '1234567897'
    },
    {
      'name': 'Youssef',
      'email': 'youssef@gmail.com',
      'phone': '01028200287',
      'nationalId': '1234567898'
    },
    {
      'name': 'Khaled',
      'email': 'khaled@gmail.com',
      'phone': '01028200287',
      'nationalId': '1234567899'
    }
  ];

  int currentPage = 0;
  int itemsPerPage = 5;

  @override
  Widget build(BuildContext context) {
            final themeProvider = Provider.of<ThemeProvider>(context);

    int totalPages = (users.length / itemsPerPage).ceil();

    return Scaffold(
      appBar: AppBar(
         actions: [
          IconButton(
            icon: Icon(themeProvider.isDarkMode ? Icons.wb_sunny : Icons.nightlight_round),
            onPressed: () {
              themeProvider.toggleTheme(); // Toggle the theme
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
      body: OrientationBuilder(
        builder: (context, orientation) {
          return SingleChildScrollView(
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
                                    showDoctorsCount = !showDoctorsCount;
                                  });
                                },
                                child: const Icon(Icons.medical_services,
                                    size: 40, color: Colors.green),
                              ),
                              const SizedBox(height: 5),
                              const Text(
                                "Doctors",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              if (showDoctorsCount)
                                Text(
                                  "$doctorsCount",
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
                      'Doctors Requests',
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
          );
        },
      ),
      bottomNavigationBar: const CustomBottomNavigationBar(currentIndex: 0),
    );
  }
}
