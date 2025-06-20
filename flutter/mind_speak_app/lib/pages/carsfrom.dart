import 'package:flutter/material.dart';
import 'package:mind_speak_app/providers/color_provider.dart';
import 'package:mind_speak_app/providers/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:mind_speak_app/providers/session_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mind_speak_app/components/cars.dart';
import 'package:mind_speak_app/components/drawer.dart';
import 'package:mind_speak_app/pages/homepage.dart';

// Second Page: UI Page
class CarsForm extends StatefulWidget {
  const CarsForm({super.key});

  @override
  _CategorySelectionPageState createState() => _CategorySelectionPageState();
}

class _CategorySelectionPageState extends State<CarsForm> {
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
      "تقليد مناسب للأصوات والحركات.",
      "تقليد بسيط غير طبيعي للحركات أو الأصوات.",
      "تقليد متوسط يتطلب حثًّا أو تكرارًا.",
      "عدم القدرة على التقليد حتى مع الحث."
    ],
    "scores": [0.0, 1.5, 2.5, 3.5]
  },
  {
    "category": "الاستجابة العاطفية",
    "questions": [
      "استجابة عاطفية مناسبة للموقف والعمر.",
      "استجابة عاطفية بسيطة غير مترابطة بالموقف.",
      "استجابة عاطفية ثابتة وغير مناسبة.",
      "استجابة شديدة غير طبيعية ومزاج يصعب تغييره."
    ],
    "scores": [0.0, 1.5, 2.5, 3.5]
  },
  {
    "category": "استخدام الجسم",
    "questions": [
      "استخدام طبيعي للجسم وتناسق حركي مناسب.",
      "استخدام بسيط غير طبيعي للجسم أو ضعف تآزر.",
      "حركات متكررة أو غير مألوفة مثل الدوران.",
      "استخدام جسد شديد غير طبيعي يصعب منعه."
    ],
    "scores": [0.0, 1.5, 2.5, 3.5]
  },
  {
    "category": "استخدام الأشياء",
    "questions": [
      "استخدام طبيعي ومناسب للأشياء.",
      "استخدام بسيط غير طبيعي أو غير هادف للأشياء.",
      "استخدام متكرر أو محدود للأشياء بشكل غريب.",
      "سلوك تكراري شديد في استخدام الأشياء."
    ],
    "scores": [0.0, 1.5, 2.5, 3.5]
  },
  {
    "category": "التكيف مع التغيير",
    "questions": [
      "تكيف طبيعي وسهل مع التغيير.",
      "تكيف بسيط غير طبيعي عند تغيير الروتين.",
      "تكيف متوسط غير طبيعي ومقاومة واضحة للتغيير.",
      "تكيف شديد غير طبيعي ومقاومة شديدة للروتين."
    ],
    "scores": [0.0, 1.5, 2.5, 3.5]
  },
  {
    "category": "الاستجابة البصرية",
    "questions": [
      "استجابة بصرية طبيعية ومناسبة.",
      "تجاهل بسيط للنظر أو تركيز غير معتاد.",
      "استخدام بصري غير طبيعي بزاويا أو قرب زائد.",
      "تجنب بصري واضح أو سلوك بصري شديد الغرابة."
    ],
    "scores": [0.0, 1.5, 2.5, 3.5]
  },
  {
    "category": "الاستجابة السمعية",
    "questions": [
      "استجابة سمعية طبيعية ومناسبة للعمر.",
      "استجابة بسيطة غير طبيعية أو تأخير في الرد.",
      "استجابة سمعية متقلبة أو تجاهل الأصوات.",
      "مبالغة في الاستجابة أو التجاهل الشديد للأصوات."
    ],
    "scores": [0.0, 1.5, 2.5, 3.5]
  },
  {
    "category": "الاستجابة للتذوق والشم واللمس",
    "questions": [
      "استجابات حسية طبيعية.",
      "استجابات حسية بسيطة غير طبيعية لبعض المثيرات.",
      "استجابات متوسطة غير طبيعية ومفرطة أو ناقصة.",
      "استجابات شديدة غير طبيعية ومبالغ بها أو منعدمة."
    ],
    "scores": [0.0, 1.5, 2.5, 3.5]
  },
  {
    "category": "الخوف أو العصبية",
    "questions": [
      "مستوى خوف أو عصبية طبيعي ومناسب.",
      "خوف أو عصبية بسيطة تجاه مواقف معينة.",
      "خوف أو قلق متوسط يسبب تقييد في الأداء.",
      "خوف أو عصبية شديدة تؤثر على الوظائف اليومية."
    ],
    "scores": [0.0, 1.5, 2.5, 3.5]
  },
  {
    "category": "التواصل اللفظي",
    "questions": [
      "تواصل لفظي طبيعي ومفهوم.",
      "تواصل لفظي بسيط غير طبيعي أو محدود.",
      "تواصل لفظي غير مترابط أو ذو محتوى غريب.",
      "غياب الحديث أو أصوات غير مفهومة تماماً."
    ],
    "scores": [0.0, 1.5, 2.5, 3.5]
  },
  {
    "category": "التواصل غير اللفظي",
    "questions": [
      "تواصل غير لفظي طبيعي (إيماءات، تعبيرات).",
      "إيماءات بسيطة أو غير واضحة.",
      "إيماءات غير مناسبة أو محدودة المعنى.",
      "غياب التواصل غير اللفظي أو إيماءات غريبة."
    ],
    "scores": [0.0, 1.5, 2.5, 3.5]
  },
  {
    "category": "مستوى النشاط",
    "questions": [
      "مستوى نشاط طبيعي للعمر.",
      "نشاط زائد أو خمول بسيط.",
      "نشاط مفرط أو خمول واضح يؤثر على الأداء.",
      "تقلب شديد بين النشاط والخمول."
    ],
    "scores": [0.0, 1.5, 2.5, 3.5]
  },
  {
    "category": "اتساق الاستجابة الفكرية",
    "questions": [
      "استجابة فكرية طبيعية ومتسقة.",
      "ذكاء منخفض بدون تباين كبير في المهارات.",
      "ذكاء منخفض مع تباين في المهارات.",
      "مهارات فكرية متقدمة جداً أو موهبة استثنائية."
    ],
    "scores": [0.0, 1.5, 2.5, 3.5]
  },
  {
    "category": "الانطباع العام",
    "questions": [
      "لا توجد أعراض توحد.",
      "أعراض بسيطة للتوحد.",
      "أعراض متوسطة للتوحد.",
      "أعراض شديدة وواضحة للتوحد."
    ],
    "scores": [0.0, 1.5, 2.5, 3.5]
  }
];


  final ValueNotifier<List<double?>> selectedScores =
      ValueNotifier<List<double?>>(List.generate(15, (_) => null));
  bool isLoading = true; // Track loading state

  @override
  void initState() {
    super.initState();
    // Ensure child ID is fetched when the widget is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sessionProvider =
          Provider.of<SessionProvider>(context, listen: false);
      sessionProvider.fetchChildId();
    });
  }

  void showCustomPopup(BuildContext context, String message) {
  final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
  final colorProvider = Provider.of<ColorProvider>(context, listen: false);
  final overlay = Overlay.of(context);

  OverlayEntry? overlayEntry;
  overlayEntry = OverlayEntry(
    builder: (context) => Positioned(
      top: MediaQuery.of(context).size.height / 3,
      left: MediaQuery.of(context).size.width / 10,
      width: MediaQuery.of(context).size.width * 0.8,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: themeProvider.isDarkMode
                  ? [Colors.grey[900]!, Colors.black]
                  : [
                      colorProvider.primaryColor,
                      colorProvider.primaryColor.withAlpha(230)
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(8.0),
            boxShadow: const [
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
              const Text(
                'نتيجة التشخيص',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: themeProvider.isDarkMode
                      ? Colors.black
                      : colorProvider.primaryColor,
                ),
                onPressed: () {
                  overlayEntry?.remove();
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const HomePage()),
                    (route) => false,
                  );
                },
                child: const Text('حسنًا'),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  overlay.insert(overlayEntry);
}


  @override
   Widget build(BuildContext context) {
        final themeProvider = Provider.of<ThemeProvider>(context);

    
    final sessionProvider = Provider.of<SessionProvider>(context);
        final colorProvider = Provider.of<ColorProvider>(context);


    return Scaffold(
      appBar: AppBar(
        title: const Text('اختيار مستوى التوحد'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: ElevatedButton(
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const HomePage()),
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: const Text('تخطي', style: TextStyle(fontSize: 16)),
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
                const SnackBar(
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
                const SnackBar(
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
                const SnackBar(
                  content: Text('تم حفظ الإجابات بنجاح.'),
                  backgroundColor: Colors.green,
                ),
              );
            } catch (e) {
              print('Error saving form data: $e');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('حدث خطأ أثناء حفظ البيانات. حاول مرة أخرى.'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: themeProvider.isDarkMode
          ? Colors.grey[900]
          : colorProvider.primaryColor,
      foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16.0),
          ),
          child: const Text(
            'إكمال',
            style: TextStyle(fontSize: 18),
          ),
        ),
      ),
    );
  }
}