import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mind_speak_app/providers/color_provider.dart';

class ThemeColorSelectorPage extends StatelessWidget {
  ThemeColorSelectorPage({super.key});

  final List<List<Color>> gradientThemes = [
    [const Color(0xFFF9CFA5), const Color(0xFFFCE38A)],
    [const Color(0xFF42E695), const Color(0xFF3BB2B8)],
    [const Color(0xFFFCE38A), const Color(0xFFF38181)],
    [const Color(0xFF00C9FF), const Color(0xFF92FE9D)],
    [const Color(0xFF7F00FF), const Color(0xFFE100FF)],
    [const Color(0xFF6A11CB), const Color(0xFF2575FC)],
    [const Color(0xFFFFA17F), const Color(0xFF00223E)],
    [const Color(0xFFF7971E), const Color(0xFFFFD200)],
    [const Color(0xFF614385), const Color(0xFF516395)],
    [const Color(0xFF00B4DB), const Color(0xFF0083B0)],
    [const Color(0xFF4568DC), const Color(0xFFB06AB3)],
    [const Color(0xFFFF512F), const Color(0xFFDD2476)],
    [const Color(0xFFDA4453), const Color(0xFF89216B)],
    [const Color(0xFFBBD2C5), const Color(0xFF536976)],
    [const Color(0xFF0F2027), const Color(0xFF2C5364)],
    [const Color(0xFFFF5F6D), const Color(0xFFFFC371)],
    [const Color(0xFF4CA1AF), const Color(0xFFC4E0E5)],
    [const Color(0xFFFFB75E), const Color(0xFFED8F03)],
    [const Color(0xFF83A4D4), const Color(0xFFB6FBFF)],
    [const Color(0xFF2193B0), const Color(0xFF6DD5ED)],
    [const Color(0xFFE65C00), const Color(0xFFF9D423)],
    [const Color(0xFF1E9600), const Color(0xFFFFF200)],
    [const Color(0xFFFFEFBA), const Color(0xFFFFFFD5)],
    [const Color(0xFF8E2DE2), const Color(0xFF4A00E0)],
    [const Color(0xFF373B44), const Color(0xFF4286f4)],
    [const Color(0xFFff9966), const Color(0xFFff5e62)],
    [const Color(0xFF00F260), const Color(0xFF0575E6)],
    [const Color(0xFFe1eec3), const Color(0xFFf05053)],
    [const Color(0xFFd3cce3), const Color(0xFFe9e4f0)],
    [const Color(0xFFa1c4fd), const Color(0xFFc2e9fb)],
  ];

  @override
  Widget build(BuildContext context) {
    final colorProvider = Provider.of<ColorProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Theme Color'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose Theme Color:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: gradientThemes.map((gradientColors) {
                    final isSelected =
                        colorProvider.primaryColor == gradientColors[0];

                    return GestureDetector(
                      onTap: () {
                        colorProvider.setPrimaryColor(gradientColors[0]);
                      },
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: gradientColors,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                            color:
                                isSelected ? Colors.black : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
