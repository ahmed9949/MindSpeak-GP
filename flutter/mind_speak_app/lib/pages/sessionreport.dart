// lib/screens/session_report_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:mind_speak_app/providers/session_provider.dart';
import 'package:intl/intl.dart';

class SessionReportPage extends StatelessWidget {
  const SessionReportPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final sessionProvider = Provider.of<SessionProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Reports'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('sessions')
            .where('childId', isEqualTo: sessionProvider.childId)
            .orderBy('sessionNumber', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No sessions available'),
            );
          }

          final sessions = snapshot.data!.docs;
          return ListView.builder(
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              // Safely get the session data
              final sessionDoc = sessions[index];
              final sessionData = sessionDoc.data() as Map<String, dynamic>?;

              if (sessionData == null) {
                return const SizedBox.shrink();
              }

              // Safely get the start time
              final startTime = sessionData['startTime'];
              if (startTime == null) {
                return const ListTile(
                  title: Text('Session data incomplete'),
                );
              }

              // Parse the date safely
              DateTime? sessionDate;
              try {
                sessionDate = DateTime.parse(startTime.toString());
              } catch (e) {
                print(
                    'Error parsing date for session ${sessionData['sessionNumber']}: $e');
                return const ListTile(
                  title: Text('Invalid date format'),
                );
              }

              // Get session number safely
              final sessionNumber =
                  sessionData['sessionNumber']?.toString() ?? 'N/A';

              // Get statistics safely
              final statistics =
                  sessionData['statistics'] as Map<String, dynamic>? ?? {};

              // Get conversation safely
              final conversation =
                  sessionData['conversation'] as List<dynamic>? ?? [];

              return Card(
                margin: const EdgeInsets.all(8.0),
                child: ExpansionTile(
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Session #$sessionNumber'),
                      Text(
                        DateFormat('yyyy-MM-dd HH:mm').format(sessionDate),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStatisticsTable(statistics),
                          const Divider(height: 24),
                          _buildConversationSection(conversation),
                          const Divider(height: 24),
                          _buildRecommendationsSection(sessionData),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStatisticsTable(Map<String, dynamic> statistics) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Session Statistics',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Table(
          border: TableBorder.all(
            color: Colors.grey,
            width: 0.5,
          ),
          columnWidths: const {
            0: FlexColumnWidth(2),
            1: FlexColumnWidth(1),
          },
          children: [
            _buildTableHeader(),
            _buildTableRow('Total Messages',
                statistics['totalMessages']?.toString() ?? '0'),
            _buildTableRow('Child Messages',
                statistics['childMessages']?.toString() ?? '0'),
            _buildTableRow('Therapist Messages',
                statistics['drMessages']?.toString() ?? '0'),
            _buildTableRow('Duration (min)',
                statistics['sessionDuration']?.toString() ?? '0'),
            _buildTableRow('Words/Message',
                statistics['wordsPerMessage']?.toString() ?? '0'),
          ],
        ),
      ],
    );
  }

  TableRow _buildTableHeader() {
    return const TableRow(
      decoration: BoxDecoration(
        color: Colors.blue,
      ),
      children: [
        Padding(
          padding: EdgeInsets.all(8.0),
          child: Text(
            'Metric',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.all(8.0),
          child: Text(
            'Value',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  TableRow _buildTableRow(String label, String value) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(label),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            value,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildConversationSection(List<dynamic> conversation) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Conversation',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: conversation.length,
          itemBuilder: (context, index) {
            final message = conversation[index] as Map<String, dynamic>;
            final isChild = message.containsKey('child');

            return Container(
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: isChild ? Colors.blue[50] : Colors.grey[100],
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Text(
                '${isChild ? "Child" : "Therapist"}: ${message[isChild ? 'child' : 'dr']}',
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRecommendationsSection(Map<String, dynamic> session) {
    final recommendations = session['recommendations'] ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recommendations',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildRecommendationBox(
                'For Parents',
                recommendations['parents'] ?? 'No recommendations available',
                Colors.blue[50]!,
              ),
              const SizedBox(height: 12),
              _buildRecommendationBox(
                'For Therapists',
                recommendations['therapists'] ?? 'No recommendations available',
                Colors.green[50]!,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendationBox(String title, String content, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(content),
        ],
      ),
    );
  }
}
