import 'package:flutter/material.dart';
import 'package:mind_speak_app/pages/report_details.dart';

class ChildReportsPage extends StatelessWidget {
  final String childName;
  final List<Map<String, dynamic>> reports;

  ChildReportsPage({required this.childName, required this.reports});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.teal,
        title: Text(
          "$childName's Reports",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
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
        padding: EdgeInsets.all(16.0),
        child: ListView.builder(
          itemCount: reports.length,
          itemBuilder: (context, index) {
            final report = reports[index];
            return InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ReportDetailsPage(
                      reportSummary: report['summary'],
                      reportDate: report['date'],
                    ),
                  ),
                );
              },
              child: Card(
                margin: EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 6,
                child: ListTile(
                  contentPadding: EdgeInsets.all(16),
                  leading: Icon(Icons.report, color: Colors.teal, size: 30),
                  title: Text(
                    report['summary'],
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    report['date'],
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  trailing: Icon(Icons.arrow_forward_ios, color: Colors.teal),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}