import 'package:flutter/material.dart';

class ReportDetailsPage extends StatelessWidget {
  final String reportSummary;
  final String reportDate;

  final Map<String, String> reportDetails = {
    "diagnosis": "Autism Spectrum Disorder",
    "therapy": "Speech Therapy",
    "notes": "Improvements in communication and interaction."
  };

  ReportDetailsPage({required this.reportSummary, required this.reportDate});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.teal,
        title: Text("Report Details", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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
            margin: EdgeInsets.only(top: 30,left: 15,right: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 8,
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Summary: $reportSummary",
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  SizedBox(height: 10),
                  Text("Date: $reportDate",
                      style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                  SizedBox(height: 20),
                  Text("Diagnosis: ${reportDetails['diagnosis']}",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  SizedBox(height: 10),
                  Text("Therapy: ${reportDetails['therapy']}",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  SizedBox(height: 10),
                  Text("Notes: ${reportDetails['notes']}",
                      style: TextStyle(fontSize: 18)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
