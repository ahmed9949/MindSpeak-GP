// Create a new file: lib/components/dashboard_count_cards.dart

import 'package:flutter/material.dart';
import 'package:mind_speak_app/service/doctor_dashboard_service.dart';

class DashboardCountCards extends StatefulWidget {
  final String sessionId; // This is the therapist ID
  final List<Map<String, dynamic>> children;

  const DashboardCountCards({
    super.key,
    required this.sessionId,
    required this.children,
  });

  @override
  State<DashboardCountCards> createState() => _DashboardCountCardsState();
}

class _DashboardCountCardsState extends State<DashboardCountCards> {
  final DoctorDashboardService _doctorServices = DoctorDashboardService();
  int totalReports = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTotalReports();
  }

  @override
  void didUpdateWidget(DashboardCountCards oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.children.length != widget.children.length) {
      _fetchTotalReports();
    }
  }

  Future<void> _fetchTotalReports() async {
    if (widget.children.isEmpty) {
      setState(() {
        totalReports = 0;
        isLoading = false;
      });
      return;
    }

    int reports = 0;
    for (var child in widget.children) {
      String childId = child['childId'] ?? '';
      if (childId.isNotEmpty) {
        List<Map<String, dynamic>> childReports =
            await _doctorServices.fetchReport(childId);
        reports += childReports.length;
      }
    }

    if (mounted) {
      setState(() {
        totalReports = reports;
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
            child: Text(
              'Dashboard Overview',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildCountCard(
                  icon: Icons.people,
                  title: 'Patients',
                  count: widget.children.length,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildCountCard(
                  icon: Icons.description,
                  title: 'Reports',
                  count: isLoading ? null : totalReports,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCountCard({
    required IconData icon,
    required String title,
    required Color color,
    int? count,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: color,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            count == null
                ? const Center(child: CircularProgressIndicator())
                : Text(
                    count.toString(),
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
