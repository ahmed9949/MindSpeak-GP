
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class SessionAnalyzer {
  final GenerativeModel _model;
  
  SessionAnalyzer(this._model);

  Future<Map<String, String>> generateRecommendations({
    required Map<String, dynamic> childData,
    required List<Map<String, dynamic>> sessionData,
    required Map<String, dynamic> aggregateStats,
  }) async {
    final String childInfo = '''
Child Information:
- Name: ${childData['name']}
- Age: ${childData['age']}
- Main Interest: ${childData['childInterest']}
    ''';

    final String sessionStats = '''
Session Statistics:
- Total Sessions: ${aggregateStats['totalSessions']}
- Average Session Duration: ${aggregateStats['averageSessionDuration']} minutes
- Average Messages per Session: ${aggregateStats['averageMessagesPerSession']}
    ''';

    String conversationSummary = 'Recent Sessions:\n';
    for (var session in sessionData) {
      conversationSummary += '\nSession #${session['sessionNumber']}:\n';
      List<Map<String, String>> conversation = 
          List<Map<String, String>>.from(session['conversation']);
      for (var message in conversation) {
        message.forEach((speaker, text) {
          conversationSummary += '$speaker: $text\n';
        });
      }
    }

    final String analysisPrompt = '''
You are a specialized AI consultant analyzing therapy sessions for a child with autism.

$childInfo

$sessionStats

$conversationSummary

Based on these interactions, please provide two separate recommendations in Arabic:

1. For Parents:
- Focus on practical, implementable advice
- Include specific activities or approaches they can try at home
- Highlight positive patterns and areas for improvement
- Keep it supportive and encouraging

2. For Therapists:
- Focus on professional therapeutic strategies
- Identify communication patterns and areas of progress
- Suggest specific therapeutic approaches based on the child's responses
- Include recommendations for future sessions

Please structure your response in clear sections for parents and therapists.
''';

    try {
      final chat = _model.startChat();
      final response = await chat.sendMessage(Content.text(analysisPrompt));
      final recommendations = response.text ?? "عذراً، لم نتمكن من توليد التوصيات.";

      return _splitRecommendations(recommendations);
    } catch (e) {
      print('Error generating recommendations: $e');
      return {
        'parents': 'عذراً، حدث خطأ في توليد التوصيات للوالدين.',
        'therapists': 'عذراً، حدث خطأ في توليد التوصيات للمعالجين.'
      };
    }
  }

  Map<String, String> _splitRecommendations(String fullText) {
    final parts = fullText.split('2. For Therapists:');
    if (parts.length != 2) {
      return {
        'parents': fullText,
        'therapists': ''
      };
    }
    
    String parentsSection = parts[0].replaceFirst('1. For Parents:', '').trim();
    String therapistsSection = parts[1].trim();
    
    return {
      'parents': parentsSection,
      'therapists': therapistsSection
    };
  }

  Future<void> saveRecommendations({
    required String childId,
    required Map<String, String> recommendations,
  }) async {
    try {
      final recommendationDoc = {
        'childId': childId,
        'timestamp': DateTime.now().toIso8601String(),
        'parentRecommendations': recommendations['parents'],
        'therapistRecommendations': recommendations['therapists'],
      };

      await FirebaseFirestore.instance
          .collection('recommendations')
          .add(recommendationDoc);

      await FirebaseFirestore.instance
          .collection('child')
          .doc(childId)
          .update({
            'latestRecommendations': recommendationDoc,
          });
    } catch (e) {
      print('Error saving recommendations: $e');
    }
  }
}