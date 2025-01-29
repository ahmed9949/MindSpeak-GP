import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:mind_speak_app/providers/session_provider.dart';

class SessionDataPage extends StatefulWidget {
  const SessionDataPage({super.key});

  @override
  State<SessionDataPage> createState() => _SessionDataPageState();
}

class _SessionDataPageState extends State<SessionDataPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> sessionDataList = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchSessionData();
  }

  Future<void> fetchSessionData() async {
    try {
      // Get the logged-in child's ID from the session provider
      final sessionProvider =
          Provider.of<SessionProvider>(context, listen: false);
      final userId = sessionProvider.userId;

      if (userId == null) {
        throw Exception('User not logged in.');
      }

      // Fetch the child's document
      QuerySnapshot childSnapshot = await _firestore
          .collection('child')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (childSnapshot.docs.isEmpty) {
        throw Exception('No child found for the logged-in user.');
      }

      final childId = childSnapshot.docs.first['childId'];

      // Fetch all session data for the child
      QuerySnapshot sessionSnapshot = await _firestore
          .collection('sessions')
          .where('childId', isEqualTo: childId)
          .get();

      if (sessionSnapshot.docs.isEmpty) {
        throw Exception('No session data found for this child.');
      }

      setState(() {
        sessionDataList = sessionSnapshot.docs
            .map((doc) => doc.data() as Map<String, dynamic>)
            .toList();
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching session data: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'),
        backgroundColor: Colors.red,
      ));
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Data'),
        backgroundColor: Colors.blue,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : sessionDataList.isEmpty
              ? const Center(
                  child: Text(
                    'No session data available.',
                    style: TextStyle(fontSize: 18),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ListView.builder(
                    itemCount: sessionDataList.length,
                    itemBuilder: (context, index) {
                      final sessionData = sessionDataList[index];
                      return _buildSessionCard(sessionData, index + 1);
                    },
                  ),
                ),
    );
  }

  Widget _buildSessionCard(Map<String, dynamic> sessionData, int sessionIndex) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Session $sessionIndex',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _buildDataRow('Child ID', sessionData['childId']),
            _buildDataRow('Date', sessionData['date']),
            _buildDataRow('Conversation', sessionData['conversation']),
            _buildDataRow(
                'Session Number for Child', sessionData['sessionNumforChild']),
            _buildDataRow('Therapist ID', sessionData['therapistId'] ?? 'N/A'),
            const Divider(),
            const Text(
              'Detection During Session',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildDataRow('Behavior Changes',
                sessionData['detectionduringsession']['behaviorChanges']),
            _buildDataRow('Behavior Counts',
                sessionData['detectionduringsession']['behaviorCounts']),
            _buildDataRow('Behavior Percentages',
                sessionData['detectionduringsession']['behaviorPercentages']),
            _buildDataRow('Emotion Changes',
                sessionData['detectionduringsession']['emotionChanges']),
            _buildDataRow('Emotion Counts',
                sessionData['detectionduringsession']['emotionCounts']),
            _buildDataRow('Emotion Percentages',
                sessionData['detectionduringsession']['emotionPercentages']),
            _buildDataRow('Total Frames',
                sessionData['detectionduringsession']['totalFrames']),
          ],
        ),
      ),
    );
  }

  Widget _buildDataRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(value?.toString() ?? 'N/A'),
          ),
        ],
      ),
    );
  }
}
