import 'package:flutter/material.dart';
import 'package:mind_speak_app/components/child_item.dart';
import 'package:mind_speak_app/models/Child.dart';
import 'package:mind_speak_app/service/doctor_dashboard_service.dart';

class ChildrenList extends StatelessWidget {
  final List<ChildModel> children;
  final bool isLoading;
  final DoctorDashboardService doctorServices;

  const ChildrenList({
    super.key,
    required this.children,
    required this.isLoading,
    required this.doctorServices,
  });

  @override
  Widget build(BuildContext context) {
    return isLoading
        ? const Center(child: CircularProgressIndicator())
        : children.isEmpty
            ? const Center(
                child: Text(
                "No children found",
                style: TextStyle(
                    fontSize: 22,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold),
              ))
            : Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.white, Colors.white],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.all(16.0),
                child: ListView.builder(
                  itemCount: children.length,
                  itemBuilder: (context, index) {
                    final child = children[index];
                    return ChildItem(
                        child: child, doctorServices: doctorServices);
                  },
                ),
              );
  }
}
