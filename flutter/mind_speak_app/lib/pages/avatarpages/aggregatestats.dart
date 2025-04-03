// lib/screens/aggregate_stats_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:mind_speak_app/providers/session_provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class AggregateStatsPage extends StatelessWidget {
  const AggregateStatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final sessionProvider = Provider.of<SessionProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Overall Progress'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('child')
            .doc(sessionProvider.childId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final childData = snapshot.data!.data() as Map<String, dynamic>;
          final aggregateStats = childData['aggregateStats'] ?? {};

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildChildInfoCard(childData),
                const SizedBox(height: 16),
                _buildOverallStatsCard(aggregateStats),
                const SizedBox(height: 16),
                _buildProgressCharts(context, sessionProvider.childId!),
                const SizedBox(height: 16),
                _buildLatestRecommendations(childData['latestRecommendations']),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildChildInfoCard(Map<String, dynamic> childData) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              childData['name'] ?? 'Child',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text('Age: ${childData['age']}'),
            Text('Interest: ${childData['childInterest']}'),
          ],
        ),
      ),
    );
  }

  Widget _buildOverallStatsCard(Map<String, dynamic> stats) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Overall Statistics',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildStatRow(
                'Total Sessions', stats['totalSessions']?.toString() ?? '0'),
            _buildStatRow(
                'Total Messages', stats['totalMessages']?.toString() ?? '0'),
            _buildStatRow('Average Session Duration',
                '${stats['averageSessionDuration']?.toString() ?? '0'} minutes'),
            _buildStatRow('Average Messages/Session',
                stats['averageMessagesPerSession']?.toString() ?? '0'),
            if (stats['lastSessionDate'] != null)
              _buildStatRow(
                'Last Session',
                DateFormat('yyyy-MM-dd')
                    .format(DateTime.parse(stats['lastSessionDate'])),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 16),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCharts(BuildContext context, String childId) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('sessions')
              .where('childId', isEqualTo: childId)
              .orderBy('sessionNumber')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text('Error loading charts: ${snapshot.error}'),
              );
            }

            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.data!.docs.isEmpty) {
              return const Center(
                child: Text('No session data available'),
              );
            }

            final sessions = snapshot.data!.docs;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Progress Charts',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 300,
                  child: _buildMessagesChart(sessions),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 300,
                  child: _buildDurationChart(sessions),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMessagesChart(List<QueryDocumentSnapshot> sessions) {
    final List<FlSpot> childSpots = [];
    final List<FlSpot> therapistSpots = [];

    for (var i = 0; i < sessions.length; i++) {
      final session = sessions[i].data() as Map<String, dynamic>;
      final stats = session['statistics'] ?? {};
      if (stats['childMessages'] != null) {
        childSpots.add(FlSpot(
          i.toDouble(),
          (stats['childMessages'] as num).toDouble(),
        ));
        therapistSpots.add(FlSpot(
          i.toDouble(),
          (stats['drMessages'] as num).toDouble(),
        ));
      }
    }

    if (childSpots.isEmpty) {
      return const Center(
        child: Text('No message data available'),
      );
    }

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Text(
                    'S${value.toInt() + 1}',
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          LineChartBarData(
            spots: childSpots,
            isCurved: true,
            color: Colors.blue,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            isStrokeCapRound: true,
            belowBarData: BarAreaData(show: false),
          ),
          LineChartBarData(
            spots: therapistSpots,
            isCurved: true,
            color: Colors.green,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            isStrokeCapRound: true,
            belowBarData: BarAreaData(show: false),
          ),
        ],
      ),
    );
  }

  Widget _buildDurationChart(List<QueryDocumentSnapshot> sessions) {
    final List<FlSpot> spots = [];

    for (var i = 0; i < sessions.length; i++) {
      final session = sessions[i].data() as Map<String, dynamic>;
      final stats = session['statistics'] ?? {};
      if (stats['sessionDuration'] != null) {
        spots.add(FlSpot(
          i.toDouble(),
          (stats['sessionDuration'] as num).toDouble(),
        ));
      }
    }

    if (spots.isEmpty) {
      return const Center(
        child: Text('No duration data available'),
      );
    }

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Text(
                    'S${value.toInt() + 1}',
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toInt()}m',
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.orange,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            isStrokeCapRound: true,
            belowBarData: BarAreaData(show: false),
          ),
        ],
      ),
    );
  }

  Widget _buildLatestRecommendations(Map<String, dynamic>? recommendations) {
    if (recommendations == null) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Latest Recommendations',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildRecommendationSection(
              'For Parents',
              recommendations['parentRecommendations'] ?? '',
              Colors.blue[50]!,
            ),
            const SizedBox(height: 12),
            _buildRecommendationSection(
              'For Therapists',
              recommendations['therapistRecommendations'] ?? '',
              Colors.green[50]!,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationSection(
      String title, String content, Color bgColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(content),
        ],
      ),
    );
  }
}
 