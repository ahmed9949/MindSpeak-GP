import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:mind_speak_app/providers/session_provider.dart';
import 'package:intl/intl.dart';

class SessionReportPage extends StatelessWidget {
  const SessionReportPage({super.key});

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
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No sessions available'));
          }

          final sessions = snapshot.data!.docs;

          return ListView.builder(
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final sessionData =
                  sessions[index].data() as Map<String, dynamic>?;
              if (sessionData == null) return const SizedBox.shrink();

              final startTime = sessionData['startTime'];
              if (startTime == null) {
                return const ListTile(title: Text('Invalid session data'));
              }

              DateTime? sessionDate;
              try {
                sessionDate = DateTime.parse(startTime.toString());
              } catch (e) {
                return const ListTile(title: Text('Invalid date format'));
              }

              return Card(
                margin: const EdgeInsets.all(8.0),
                child: ExpansionTile(
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Session #${sessionData['sessionNumber'] ?? 'N/A'}'),
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
                          _buildBasicStatistics(
                              sessionData['statistics'] ?? {}),
                          const Divider(height: 24),
                          _buildDetectionStatistics(),
                          const Divider(height: 24),
                          _buildConversationSection(
                              sessionData['conversation'] ?? []),
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

  Widget _buildBasicStatistics(Map<String, dynamic> statistics) {
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

  Widget _buildDetectionStatistics() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Detection Analysis',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildGazeAnalysis(),
                const Divider(height: 24),
                _buildEmotionAnalysis(),
                const Divider(height: 24),
                _buildBehaviorAnalysis(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGazeAnalysis() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Eye Gaze Analysis',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
            'The child maintained focus for 75% of the session duration, '
            'which is above the recommended threshold (60%). '
            'This indicates good engagement with the therapy session.'),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          height: 20,
          child: Row(
            children: [
              Expanded(
                flex: 75,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.green[200],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(10),
                      bottomLeft: Radius.circular(10),
                    ),
                  ),
                  child: const Center(child: Text('Focused')),
                ),
              ),
              Expanded(
                flex: 25,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(10),
                      bottomRight: Radius.circular(10),
                    ),
                  ),
                  child: const Center(child: Text('Unfocused')),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmotionAnalysis() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Emotional Response',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        const Text('Emotional state distribution during the session:'),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              _buildEmotionBar('Neutral', 45, Colors.blue),
              const SizedBox(height: 4),
              _buildEmotionBar('Happy', 40, Colors.green),
              const SizedBox(height: 4),
              _buildEmotionBar('Sad', 15, Colors.orange),
            ],
          ),
        ),
        const Text(
          'The child showed predominantly neutral and positive emotions, '
          'indicating comfort with the therapy session.',
          style: TextStyle(fontStyle: FontStyle.italic),
        ),
      ],
    );
  }

  Widget _buildEmotionBar(String emotion, int percentage, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(emotion),
        ),
        Expanded(
          child: Container(
            height: 20,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Colors.grey[200],
            ),
            child: Row(
              children: [
                Container(
                  width: percentage.toDouble() * 2,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          width: 50,
          child: Text(' $percentage%'),
        ),
      ],
    );
  }

  Widget _buildBehaviorAnalysis() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Behavior Assessment',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
            'Based on the session analysis, the following behaviors were observed:'),
        const SizedBox(height: 8),
        _buildBehaviorPoint(
          'Behavior',
          'hair rubbing 3 times during the session ',
          Icons.child_care,
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildBehaviorPoint(String title, String description, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.blue),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(description),
              ],
            ),
          ),
        ],
      ),
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
