// lib/views/session/session_report_page.dart
import 'package:flutter/material.dart';
import 'package:mind_speak_app/models/sessiondata.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:mind_speak_app/controllers/sessioncontrollerCl.dart';
import 'package:mind_speak_app/providers/session_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SessionReportPage extends StatefulWidget {
  const SessionReportPage({Key? key}) : super(key: key);

  @override
  State<SessionReportPage> createState() => _SessionReportPageState();
}

class _SessionReportPageState extends State<SessionReportPage> {
  bool _isLoading = true;
  List<SessionData> _sessions = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get childId from the SessionProvider
      final childId =
          Provider.of<SessionProvider>(context, listen: false).childId;

      if (childId == null || childId.isEmpty) {
        setState(() {
          _errorMessage = 'No child selected';
          _isLoading = false;
        });
        return;
      }

      // Get sessions from Firestore
      final snapshot = await FirebaseFirestore.instance
          .collection('sessions')
          .where('childId', isEqualTo: childId)
          .orderBy('sessionNumber', descending: true)
          .get();

      final sessions = snapshot.docs.map((doc) {
        final data = doc.data();
        return SessionData.fromJson(data);
      }).toList();

      setState(() {
        _sessions = sessions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading sessions: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSessions,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadSessions,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_sessions.isEmpty) {
      return const Center(
        child: Text('No sessions available for this child'),
      );
    }

    return ListView.builder(
      itemCount: _sessions.length,
      itemBuilder: (context, index) {
        final session = _sessions[index];
        return _buildSessionCard(session);
      },
    );
  }

  Widget _buildSessionCard(SessionData session) {
    final startDate = DateFormat('yyyy-MM-dd HH:mm').format(session.startTime);

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: ExpansionTile(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Session #${session.sessionNumber}'),
            Text(
              startDate,
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
                _buildBasicStatistics(session.statistics ?? {}),
                const Divider(height: 24),
                _buildConversationSection(session.conversation),
                const Divider(height: 24),
                _buildRecommendationsSection(session.recommendations),
              ],
            ),
          ),
        ],
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

  Widget _buildConversationSection(List<Map<String, String>> conversation) {
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
            final message = conversation[index];
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

  Widget _buildRecommendationsSection(Map<String, dynamic>? recommendations) {
    if (recommendations == null) {
      return const SizedBox.shrink();
    }

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

