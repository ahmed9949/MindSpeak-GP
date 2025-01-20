import 'package:flutter/material.dart';
import 'package:mind_speak_app/components/report_list_container.dart';
import 'package:mind_speak_app/providers/theme_provider.dart';
import 'package:provider/provider.dart';

class ChildReportsPage extends StatelessWidget {
  final String childName;
  final List<Map<String, dynamic>> reports;

  const ChildReportsPage(
      {super.key, required this.childName, required this.reports});

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
              themeProvider.toggleTheme(); // Toggle the theme
            },
          ),
        ],
        backgroundColor: Colors.blue,
        title: Text(
          "$childName's Reports",
          style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color.fromARGB(255, 255, 255, 255)),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: ReportListContainer(reports: reports),
    );
  }
}
