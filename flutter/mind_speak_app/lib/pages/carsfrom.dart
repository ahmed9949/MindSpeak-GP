import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mind_speak_app/providers/session_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mind_speak_app/components/cars.dart';
import 'package:mind_speak_app/components/drawer.dart';
import 'package:mind_speak_app/pages/homepage.dart';
// Second Page: UI Page
class carsform extends StatefulWidget {
  @override
  _CategorySelectionPageState createState() => _CategorySelectionPageState();
}

class _CategorySelectionPageState extends State<carsform> {
  final List<Map<String, dynamic>> categories = [
    {
      "category": "التواصل مع الناس",
      "questions": [
        "تفاعل اجتماعي طبيعي.",
        "تفاعل اجتماعي بسيط غير طبيعي.",
        "تفاعل اجتماعي متوسط غير طبيعي.",
        "تفاعل اجتماعي شديد غير طبيعي."
      ],
      "scores": [0.0, 1.5, 2.5, 3.5]
    },
    {
      "category": "التقليد",
      "questions": [
        "تقليد مناسب.",
        "صعوبة تقليد بسيطة.",
        "صعوبة تقليد متوسطة.",
        "عدم القدرة على التقليد."
      ],
      "scores": [0.0, 1.5, 2.5, 3.5]
    },
    {
      "category": "الاستجابة العاطفية",
      "questions": [
        "استجابة عاطفية مناسبة.",
        "استجابة عاطفية بسيطة غير طبيعية.",
        "استجابة عاطفية متوسطة غير طبيعية.",
        "استجابة عاطفية شديدة غير طبيعية."
      ],
      "scores": [0.0, 1.5, 2.5, 3.5]
    },
    {
      "category": "استخدام الجسم",
      "questions": [
        "استخدام طبيعي للجسم.",
        "استخدام بسيط غير طبيعي للجسم.",
        "استخدام متوسط غير طبيعي للجسم.",
        "استخدام شديد غير طبيعي للجسم."
      ],
      "scores": [0.0, 1.5, 2.5, 3.5]
    },
    {
      "category": "التكيف مع التغيير",
      "questions": [
        "تكيف طبيعي مع التغيير.",
        "تكيف بسيط غير طبيعي مع التغيير.",
        "تكيف متوسط غير طبيعي مع التغيير.",
        "تكيف شديد غير طبيعي مع التغيير."
      ],
      "scores": [0.0, 1.5, 2.5, 3.5]
    },
    {
      "category": "الاستجابة البصرية",
      "questions": [
        "استجابة بصرية طبيعية.",
        "استجابة بصرية بسيطة غير طبيعية.",
        "استجابة بصرية متوسطة غير طبيعية.",
        "استجابة بصرية شديدة غير طبيعية."
      ],
      "scores": [0.0, 1.5, 2.5, 3.5]
    },
    {
      "category": "الاستجابة السمعية",
      "questions": [
        "استجابة سمعية طبيعية.",
        "استجابة سمعية بسيطة غير طبيعية.",
        "استجابة سمعية متوسطة غير طبيعية.",
        "استجابة سمعية شديدة غير طبيعية."
      ],
      "scores": [0.0, 1.5, 2.5, 3.5]
    },
    {
      "category": "التذوق، الشم، واللمس",
      "questions": [
        "استجابة حسية طبيعية.",
        "استجابة حسية بسيطة غير طبيعية.",
        "استجابة حسية متوسطة غير طبيعية.",
        "استجابة حسية شديدة غير طبيعية."
      ],
      "scores": [0.0, 1.5, 2.5, 3.5]
    },
    {
      "category": "الخوف أو العصبية",
      "questions": [
        "مستوى خوف أو عصبية طبيعي.",
        "مستوى خوف أو عصبية بسيط غير طبيعي.",
        "مستوى خوف أو عصبية متوسط غير طبيعي.",
        "مستوى خوف أو عصبية شديد غير طبيعي."
      ],
      "scores": [0.0, 1.5, 2.5, 3.5]
    },
    {
      "category": "التواصل اللفظي",
      "questions": [
        "تواصل لفظي طبيعي.",
        "تواصل لفظي بسيط غير طبيعي.",
        "تواصل لفظي متوسط غير طبيعي.",
        "تواصل لفظي شديد غير طبيعي."
      ],
      "scores": [0.0, 1.5, 2.5, 3.5]
    },
    {
      "category": "التواصل غير اللفظي",
      "questions": [
        "تواصل غير لفظي طبيعي.",
        "تواصل غير لفظي بسيط غير طبيعي.",
        "تواصل غير لفظي متوسط غير طبيعي.",
        "تواصل غير لفظي شديد غير طبيعي."
      ],
      "scores": [0.0, 1.5, 2.5, 3.5]
    },
    {
      "category": "مستوى النشاط",
      "questions": [
        "مستوى نشاط طبيعي.",
        "مستوى نشاط بسيط غير طبيعي.",
        "مستوى نشاط متوسط غير طبيعي.",
        "مستوى نشاط شديد غير طبيعي."
      ],
      "scores": [0.0, 1.5, 2.5, 3.5]
    },
    {
      "category": "اتساق الاستجابة الفكرية",
      "questions": [
        "استجابة فكرية طبيعية.",
        "استجابة فكرية بسيطة غير طبيعية.",
        "استجابة فكرية متوسطة غير طبيعية.",
        "استجابة فكرية شديدة غير طبيعية."
      ],
      "scores": [0.0, 1.5, 2.5, 3.5]
    },
    {
      "category": "الانطباع العام",
      "questions": [
        "لا توجد أعراض للتوحد.",
        "أعراض طفيفة للتوحد.",
        "أعراض متوسطة للتوحد.",
        "أعراض شديدة للتوحد."
      ],
      "scores": [0.0, 1.5, 2.5, 3.5]
    },
    {
      "category": "شدة التوحد",
      "questions": [
        "غياب كامل للأعراض.",
        "أعراض طفيفة.",
        "أعراض متوسطة.",
        "أعراض شديدة."
      ],
      "scores": [0.0, 1.5, 2.5, 3.5]
    }
  ];


 final ValueNotifier<List<double?>> selectedScores =
      ValueNotifier<List<double?>>(List.generate(15, (_) => null));
  String? childId; // Make childId nullable
  bool isLoading = true; // Track loading state

 void showCustomPopup(BuildContext context, String message) {
    final overlay = Overlay.of(context);

    // Declare the overlayEntry with a placeholder
    OverlayEntry? overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).size.height / 3,
        left: MediaQuery.of(context).size.width / 10,
        width: MediaQuery.of(context).size.width * 0.8,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'نتيجة التشخيص',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    overlayEntry?.remove();
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => HomePage()),
                      (route) => false,
                    );
                  },
                  child: Text('حسنًا'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    overlay?.insert(overlayEntry);
  }



  @override
   Widget build(BuildContext context) {
    final sessionProvider = Provider.of<SessionProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('اختيار مستوى التوحد'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: ElevatedButton(
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => HomePage()),
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: Text('تخطي', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
      drawer: const NavigationDrawe(),
      body: ValueListenableBuilder<List<double?>>(
        valueListenable: selectedScores,
        builder: (context, scores, child) {
          return ListView.builder(
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              return Cars(
                title: category["category"],
                questions: List<String>.from(category["questions"]),
                scores: List<double>.from(category["scores"]),
                selectedScore: ValueNotifier(scores[index]),
                onValueChanged: (value) {
                  setState(() {
                    selectedScores.value[index] = value;
                  });
                },
              );
            },
          );
        },
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          onPressed: () async {
            if (sessionProvider.childId == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('لم يتم تحديد معرف الطفل.'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }

            // Check if all categories have one question selected
            bool allSelected = !selectedScores.value.contains(null);

            if (!allSelected) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'يرجى الإجابة على جميع الأسئلة.',
                    style: TextStyle(color: Colors.white),
                  ),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 5),
                ),
              );
              return;
            }

            // Calculate total score
            double totalScore = selectedScores.value
                .whereType<double>()
                .reduce((a, b) => a + b);
            
           String message;
            if (totalScore < 15) {
              message = 'طفلك ليس مصابًا بالتوحد.';
            } else if (totalScore >= 15 && totalScore <= 29.5) {
              message = 'طفلك مصاب بالتوحد بدلرجة ضئيلة.';
            } else if (totalScore >= 30 && totalScore <= 36.5) {
              message = 'طفلك مصاب بالتوحد بدرجة متوسطة.';
            } else {
              message =
                  'طفلك مصاب بالتوحد بدرجة شديدة. لا يمكننا مساعدتك. الرجاء مراجعة الطبيب للحصول على المساعدة.';
            }

            showCustomPopup(context, message);

            try {
              await FirebaseFirestore.instance.collection('Cars').add({
                'childId': sessionProvider.childId,
                'totalScore': totalScore,
                'selectedQuestions': selectedScores.value,
                'status': true,
              });

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('تم حفظ الإجابات بنجاح.'),
                  backgroundColor: Colors.green,
                ),
              );
            } catch (e) {
              print('Error saving form data: $e');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('حدث خطأ أثناء حفظ البيانات. حاول مرة أخرى.'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            padding: EdgeInsets.symmetric(vertical: 16.0),
          ),
          child: Text(
            'إكمال',
            style: TextStyle(fontSize: 18),
          ),
        ),
      ),
    );
  }
}