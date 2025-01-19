import 'package:flutter/material.dart';
import 'package:mind_speak_app/pages/child_reports.dart';
import 'package:mind_speak_app/service/doctor_dashboard_service.dart';

class ChildItem extends StatelessWidget {
  final Map<String, dynamic> child;
  final DoctorDashboardService doctorServices;

  const ChildItem({super.key, required this.child, required this.doctorServices});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        try {
          final childId = child['childId'];
          final reports = await doctorServices.fetchReport(childId);

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChildReportsPage(
                childName: child['name'],
                reports: reports,
              ),
            ),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error fetching reports: $e')),
          );
        }
      },
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 6,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          leading: CircleAvatar(
            backgroundColor: Colors.teal[200],
            child: Text(
              child['name'][0],
              style: const TextStyle(fontSize: 18, color: Colors.white),
            ),
          ),
          title: Text(
            child['name'],
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          trailing: const Icon(
            Icons.arrow_forward_ios,
            color: Colors.teal,
            size: 20,
          ),
        ),
      ),
    );
  }
}
