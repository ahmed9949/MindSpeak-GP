import 'package:flutter/material.dart';
import 'package:mind_speak_app/components/report_detail_item.dart';
import 'package:mind_speak_app/providers/theme_provider.dart';
import 'package:provider/provider.dart';

class ReportDetailsPage extends StatelessWidget {
  
  final String sessionId;
  final String analysis;
  final String progress;
  final String recommendation;

  const ReportDetailsPage({
    super.key, 
    required this.sessionId, 
    required this.analysis, 
    required this.progress, 
    required this.recommendation
  });

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
        title: const Text("Report Details", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        elevation: 0,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.teal[50]!, Colors.teal[100]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Align(
          alignment: Alignment.topCenter,
          child: Card(
            margin: const EdgeInsets.only(top: 30, left: 15, right: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 8,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: 500,
                child: SingleChildScrollView( 
                  child: Column(
                    children: [
                      ReportDetailItem(title: "Session Id", content: sessionId),
                      ReportDetailItem(title: "Analysis", content: analysis),
                      ReportDetailItem(title: "Progress", content: progress),
                      ReportDetailItem(title: "Recommendation", content: recommendation),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
