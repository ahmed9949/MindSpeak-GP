import 'package:flutter/material.dart';
import 'package:mind_speak_app/pages/report_details.dart';

class ReportItem extends StatelessWidget {
  final Map<String, dynamic> report;

  const ReportItem({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
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
  }
}
