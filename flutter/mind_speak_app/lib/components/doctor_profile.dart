import 'package:flutter/material.dart';

class DoctorProfile extends StatelessWidget {
  final String? therapistImage;
  final String name;
  final String bio;

  const DoctorProfile({super.key,  
    required this.name,
    required this.bio,
    this.therapistImage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Center(
          child: CircleAvatar(
            radius: 50,
            backgroundImage: therapistImage != null
                ? NetworkImage(therapistImage!)
                : null,
            child: therapistImage == null
                ? const Icon(Icons.person, size: 50)
                : null,
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            name,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            bio,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Divider(color: Colors.grey.shade300, thickness: 1),
      ],
    );
  }
}
