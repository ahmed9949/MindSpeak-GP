import 'package:flutter/material.dart';

class ContactInfoCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;

  const ContactInfoCard({super.key, 
    required this.title,
    this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 1,
      child: ListTile(
        leading: Icon(icon, color: Colors.blue),
        title: Text(title),
        subtitle: Text(subtitle ?? 'Not provided'),
      ),
    );
  }
}
