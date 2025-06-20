import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:mind_speak_app/providers/theme_provider.dart';
import 'package:mind_speak_app/models/sessiondata.dart';

class ChildReportsPage extends StatefulWidget {
  final String childId;
  final String childName;

  const ChildReportsPage({
    super.key,
    required this.childId,
    required this.childName,
  });

  @override
  State<ChildReportsPage> createState() => _ChildReportsPageState();
}

class _ChildReportsPageState extends State<ChildReportsPage> {
  bool _isLoading = true;
  String? _errorMessage;
  List<SessionData> _sessions = [];
  Map<String, dynamic>? _carsData;
  Map<String, TextEditingController> _commentControllers = {};

  @override
  void initState() {
    super.initState();
    _loadSessions();
    _loadCarsData();
  }

  @override
  void dispose() {
    for (var controller in _commentControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSessions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('sessions')
          .where('childId', isEqualTo: widget.childId)
          .orderBy('sessionNumber', descending: true)
          .get();

      final sessions = snapshot.docs.map((doc) {
        final data = doc.data();
        return SessionData.fromJson(data);
      }).toList();

      // Initialize comment controllers
      for (var session in sessions) {
        final sessionId = session.sessionId ?? session.sessionNumber.toString();
        _commentControllers[sessionId] = TextEditingController();
      }

      setState(() {
        _sessions = sessions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load reports: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCarsData() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('Cars')
          .where('childId', isEqualTo: widget.childId)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        setState(() {
          _carsData = querySnapshot.docs.first.data();
        });
      }
    } catch (e) {
      print('Error fetching CARS data: $e');
      _carsData = null;
    }
  }

  Future<void> _saveDoctorComment(String sessionId, int sessionNumber) async {
    final comment = _commentControllers[sessionId]?.text.trim();
    if (comment == null || comment.isEmpty) return;

    try {
      await FirebaseFirestore.instance
          .collection('sessionComments')
          .doc(sessionId)
          .set({
        'commentId': sessionId,
        'childId': widget.childId,
        'sessionId': sessionId,
        'sessionNumber': sessionNumber,
        'comment': comment,
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comment saved successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save comment: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.childName}'s Reports"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(themeProvider.isDarkMode
                ? Icons.wb_sunny
                : Icons.nightlight_round),
            onPressed: () {
              themeProvider.toggleTheme();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : _sessions.isEmpty && _carsData == null
                  ? const Center(child: Text("No reports available."))
                  : Column(
                      children: [
                        if (_carsData != null) _buildCarsSection(),
                        if (_sessions.isNotEmpty)
                          Expanded(
                            child: ListView.builder(
                              itemCount: _sessions.length,
                              itemBuilder: (context, index) {
                                final session = _sessions[index];
                                return _buildSessionCard(session);
                              },
                            ),
                          ),
                      ],
                    ),
    );
  }

  Widget _buildCarsSection() {
    final List<dynamic> questions = _carsData!['selectedQuestions'] ?? [];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ExpansionTile(
          title: const Text(
            'CARS Evaluation',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          childrenPadding: const EdgeInsets.all(16.0),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16.0),
          children: [
            Table(
              border: TableBorder.all(color: Colors.grey.shade300),
              columnWidths: const {
                0: FlexColumnWidth(1),
                1: FlexColumnWidth(4),
              },
              children: questions.asMap().entries.map<TableRow>((entry) {
                final index = entry.key;
                final value = entry.value;
                return TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text('Q${index + 1}'),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(value.toString()),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionCard(SessionData session) {
    final startDate = DateFormat('yyyy-MM-dd HH:mm').format(session.startTime);
    final sessionId = session.sessionId ?? session.sessionNumber.toString();
    final controller = _commentControllers[sessionId]!;

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: ExpansionTile(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Session #${session.sessionNumber}'),
            Text(startDate, style: TextStyle(color: Colors.grey[600])),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBasicStatistics(session.statistics ?? {}),
                const Divider(),
                _buildConversationSection(session.conversation),
                const Divider(),
                _buildRecommendationsSection(session.recommendations),
                const SizedBox(height: 16),
                const Text(
                  'Doctor Comment',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Enter your comment here...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                ),
                const SizedBox(height: 8),
                Align(
  alignment: Alignment.centerRight,
  child: ElevatedButton.icon(
    style: ElevatedButton.styleFrom(
      backgroundColor: Theme.of(context).colorScheme.primary,
      foregroundColor: Theme.of(context).colorScheme.onPrimary,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      textStyle: const TextStyle(fontSize: 16),
    ),
    onPressed: () =>
        _saveDoctorComment(sessionId, session.sessionNumber),
    icon: const Icon(Icons.save),
    label: const Text('Save'),
  ),
),

              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicStatistics(Map<String, dynamic> stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Session Statistics',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Table(
          border: TableBorder.all(color: Colors.grey, width: 0.5),
          columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(1)},
          children: [
            _buildTableRow(
                'Total Messages', stats['totalMessages']?.toString() ?? '0'),
            _buildTableRow(
                'Child Messages', stats['childMessages']?.toString() ?? '0'),
            _buildTableRow(
                'Therapist Messages', stats['drMessages']?.toString() ?? '0'),
            _buildTableRow(
                'Duration (min)', stats['sessionDuration']?.toString() ?? '0'),
            _buildTableRow('Words/Message',
                stats['wordsPerMessage']?.toString() ?? '0'),
          ],
        ),
      ],
    );
  }

  TableRow _buildTableRow(String label, String value) {
    return TableRow(children: [
      Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(label),
      ),
      Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(value, textAlign: TextAlign.center),
      ),
    ]);
  }

  Widget _buildConversationSection(List<Map<String, String>> conversation) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Conversation',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: conversation.length,
          itemBuilder: (context, index) {
            final message = conversation[index];
            final isChild = message.containsKey('child');
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isChild ? Colors.blue[50] : Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
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

  Widget _buildRecommendationsSection(Map<String, dynamic>? recs) {
    if (recs == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Recommendations',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildRecommendationBox('For Parents', recs['parents'] ?? ''),
        const SizedBox(height: 8),
        _buildRecommendationBox('For Therapists', recs['therapists'] ?? ''),
      ],
    );
  }

  Widget _buildRecommendationBox(String title, String content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Text(content),
        ],
      ),
    );
  }
}
