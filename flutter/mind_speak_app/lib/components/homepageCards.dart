import 'package:flutter/material.dart';

class smallcard extends StatelessWidget {
  const smallcard({super.key, required this.color, required this.text});
  final Color color;
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: Container(
        width: 125,
        height: 125,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Center(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class BiggerCard extends StatelessWidget {
  const BiggerCard({super.key});

  @override
  Widget build(BuildContext context) {
    return  Container(
              width: double.infinity, // Take full width
              height: 200, // Bigger height
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(25),
              ),
              child: const Center(
                child: Text(
                  'Big Card',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24, // Bigger font size
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
  }
}
