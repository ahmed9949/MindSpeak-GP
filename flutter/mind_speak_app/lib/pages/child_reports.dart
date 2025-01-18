import 'package:flutter/material.dart';
import 'package:mind_speak_app/pages/report_details.dart';
import 'package:mind_speak_app/providers/theme_provider.dart';
import 'package:provider/provider.dart';

class ChildReportsPage extends StatelessWidget {
  final String childName;
  final List<Map<String, dynamic>> reports;

  const ChildReportsPage({super.key, required this.childName, required this.reports});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

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
        backgroundColor: Colors.teal,
        title: Text(
          "$childName's Reports",
          style: const TextStyle(fontWeight: FontWeight.bold, color: Color.fromARGB(255, 255, 255, 255)),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.teal[50]!, Colors.teal[100]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(16.0),
        child: reports.isEmpty?
        Center(
          child: Text(
            "No reports to display",
            style: TextStyle(fontSize: 22, color: Colors.grey, fontWeight: FontWeight.bold),
            ),
            )
          : ListView.builder(
          itemCount: reports.length,
          itemBuilder: (context, index) {
            final report = reports[index];
            return InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ReportDetailsPage(
                      sessionId: report['sessionId'],
                      analysis: report['analysis'],
                      progress: report['progress'],
                      recommendation: report['recommendation'],
                    ),
                  ),
                );
              },
              child: Card(
                margin: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 6,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: const Icon(Icons.report, color: Colors.teal, size: 30),
                  title: Text(
                    report['sessionId'],
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    report['analysis'],
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, color: Colors.teal),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}