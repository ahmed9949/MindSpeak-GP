import 'package:flutter/material.dart';

class Cars extends StatelessWidget {
  final String title;
  final List<String> questions;
  final List<double> scores;
  final ValueNotifier<double?> selectedScore;
  final Function(double) onValueChanged;

  const Cars({
    super.key,
    required this.title,
    required this.questions,
    required this.scores,
    required this.selectedScore,
    required this.onValueChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(10),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            ValueListenableBuilder<double?>(
              valueListenable: selectedScore,
              builder: (context, selected, child) {
                return Column(
                  children: List.generate(questions.length, (index) {
                    return RadioListTile<double>(
                      title: Text(questions[index]),
                      value: scores[index],
                      groupValue: selected, // Use `null` as the default state
                      onChanged: (value) {
                        selectedScore.value = value;
                        onValueChanged(value!);
                      },
                    );
                  }),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
