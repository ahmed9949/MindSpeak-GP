import 'package:flutter/material.dart';
import 'package:mind_speak_app/models/Child.dart';
import 'package:mind_speak_app/pages/child_reports.dart';
import 'package:mind_speak_app/service/doctor_dashboard_service.dart';

class ChildItem extends StatelessWidget {
  final ChildModel child;
  final DoctorDashboardService doctorServices;

  const ChildItem({
    super.key,
    required this.child,
    required this.doctorServices,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChildReportsPage(
              childId: child.childId,
              childName: child.name,
            ),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 6,
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          leading: CircleAvatar(
            backgroundImage: child.childPhoto.isNotEmpty
                ? NetworkImage(child.childPhoto)
                : null,
            backgroundColor: Colors.blue[200],
            child: child.childPhoto.isEmpty
                ? Text(
                    child.name[0],
                    style: const TextStyle(fontSize: 18, color: Colors.white),
                  )
                : null,
          ),
          title: Text(
            child.name,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            'Age: ${child.age} • Interest: ${child.childInterest}',
            style: const TextStyle(fontSize: 14),
          ),
          trailing: const Icon(
            Icons.arrow_forward_ios,
            color: Colors.blue,
            size: 20,
          ),
        ),
      ),
    );
  }
}
