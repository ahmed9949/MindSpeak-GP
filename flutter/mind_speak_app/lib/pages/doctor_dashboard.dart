import 'package:flutter/material.dart';
import 'package:mind_speak_app/pages/child_reports.dart';

class DoctorDashboard extends StatelessWidget {
  final String doctorName = "Dr. Ahmed";
  final String specialization = "Pediatric Autism Specialist";

final List<Map<String, dynamic>> children = [
  {
    "id": 1,
    "name": "Ali",
    "reports": [
      {"id": 101, "date": "2024-12-20", "summary": "Routine Checkup"},
      {"id": 102, "date": "2024-12-15", "summary": "Therapy Session"}
    ]
  },
  {
    "id": 2,
    "name": "Sara",
    "reports": [
      {"id": 201, "date": "2024-12-18", "summary": "Progress Assessment"},
      {"id": 202, "date": "2024-12-10", "summary": "Behavioral Therapy"}
    ]
  },
  {
    "id": 3,
    "name": "Hassan",
    "reports": [
      {"id": 301, "date": "2024-12-22", "summary": "Diet Consultation"},
      {"id": 302, "date": "2024-12-19", "summary": "Routine Therapy"}
    ]
  },
  {
    "id": 4,
    "name": "Leila",
    "reports": [
      {"id": 401, "date": "2024-12-21", "summary": "Speech Assessment"},
      {"id": 402, "date": "2024-12-16", "summary": "Behavioral Therapy"}
    ]
  },
  {
    "id": 5,
    "name": "Nada",
    "reports": [
      {"id": 501, "date": "2024-12-25", "summary": "Therapy Progress Review"},
      {"id": 502, "date": "2024-12-11", "summary": "Follow-up Check"}
    ]
  },
  {
    "id": 6,
    "name": "Omar",
    "reports": [
      {"id": 601, "date": "2024-5-3", "summary": "Routine Therapy"},
      {"id": 602, "date": "2024-7-5", "summary": "Speech Assessment"}
    ]
  },
  {
    "id": 7,
    "name": "Mariam",
    "reports": [
      {"id": 701, "date": "2024-12-10", "summary": "Speech Therapy"},
      {"id": 702, "date": "2024-12-02", "summary": "Routine Checkup"}
    ]
  },
  {
    "id": 8,
    "name": "Amir",
    "reports": [
      {"id": 801, "date": "2024-12-15", "summary": "Progress Review"},
      {"id": 802, "date": "2024-12-01", "summary": "Therapy Consultation"}
    ]
  },
];

   DoctorDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    
    final int numberOfPatients = children.length;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.teal,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Welcome, $doctorName",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              "$specialization | $numberOfPatients patients",
              style: const TextStyle(fontSize: 14, color: Colors.white70),
            ),
          ],
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
        child: ListView.builder(
          itemCount: children.length,
          itemBuilder: (context, index) {
            final child = children[index];
            return InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChildReportsPage(
                      childName: child['name'],
                      reports: child['reports'],
                    ),
                  ),
                );
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
          },
        ),
      ),
    );
  }
}