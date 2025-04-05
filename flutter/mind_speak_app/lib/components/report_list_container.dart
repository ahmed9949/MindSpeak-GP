import 'package:flutter/material.dart';
import 'package:mind_speak_app/components/report_item.dart';

class ReportListContainer extends StatelessWidget {
  final List<Map<String, dynamic>> reports;

  const ReportListContainer({super.key, required this.reports});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16.0),
      child: reports.isEmpty
          ? const Center(
              child: Text(
                "No reports to display",
                style: TextStyle(
                    fontSize: 22,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold),
              ),
            )
          : ListView.builder(
              itemCount: reports.length,
              itemBuilder: (context, index) {
                final report = reports[index];
                return ReportItem(report: report);
              },
            ),
    );
  }
}
