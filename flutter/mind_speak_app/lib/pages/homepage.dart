import 'package:flutter/material.dart';
import 'package:mind_speak_app/pages/carsfrom.dart';
import 'package:mind_speak_app/pages/predict.dart';
import 'package:mind_speak_app/pages/choose_avatar_page.dart';
import 'package:mind_speak_app/pages/searchpage.dart';
import 'package:mind_speak_app/components/drawer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mind_speak_app/pages/signup.dart';
import 'package:provider/provider.dart';
import 'package:mind_speak_app/providers/session_provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? childPhoto;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchChildPhoto();
  }

  Future<void> fetchChildPhoto() async {
    try {
      final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
      final userId = sessionProvider.userId;

      if (userId == null) {
        throw Exception('User not logged in');
      }

      // Query Firestore for the current user's child
      final querySnapshot = await FirebaseFirestore.instance
          .collection('child')
          .where('userId', isEqualTo: userId)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        setState(() {
          childPhoto = querySnapshot.docs.first.data()['childPhoto'] as String?;
          isLoading = false;
        });
      } else {
        setState(() {
          childPhoto = null; // No child photo found
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching child photo: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const NavigationDrawe(),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            IconButton(
              icon: const Icon(Icons.favorite_border),
              onPressed: () {},
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              const SizedBox(width: 10),
              CircleAvatar(
                backgroundImage: childPhoto != null
                    ? NetworkImage(childPhoto!) // Use fetched image
                    : const AssetImage('assets/user_image.png') as ImageProvider, // Fallback image
                child: childPhoto == null
                    ? const Icon(Icons.person, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 10),
            ],
          ),
        ],
      ),
      
      body: Container(
        color: Colors.blue,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                  const SizedBox(height: 30), // Adjust the height here to control the gap

            // Top 4 Cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildTopCard(
                    context,
                    "Doctors",
                    "assets/doctor.png",
                    const SearchPage(),
                  ),
                  _buildTopCard(
                    context,
                    "Cars Form",
                    "assets/cars.png",
                    carsform(),
                  ),
                  _buildTopCard(
                    context,
                    "Prediction",
                    "assets/predict.png",
                    const Predict(),
                  ),
                  _buildTopCard(
                    context,
                    "Choose Avatars",
                    "assets/avatar.png",
                    // const ChooseAvatarPage(),
                    const SignUp()
                  ),
                ],
              ),
            ),
            const SizedBox(height: 35),

            // Top Doctors Section
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Top Doctor",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 150,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              _buildDoctorCard(
                                  "Dr. Kawsar Ahmed", "Dental Sargon"),
                              _buildDoctorCard("Dr. Mohbuba Is", "Dental Sargon"),
                              _buildDoctorCard("Dr. Riyadh", "Dental Sargon"),
                            ],
                          ),
                        ),
                        const SizedBox(height: 90),
                        // Green Start Session Button
          Center(
            child: ElevatedButton(
              onPressed: () {
                // Handle button press
                print("Start Session button pressed!");
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green, // Button color
                padding: const EdgeInsets.symmetric(
                  horizontal: 50,
                  vertical: 30,
                ), // Button size
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text(
                "Start Session",
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
          ),

                      
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopCard(
      BuildContext context, String title, String iconPath, Widget page) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => page),
        );
      },
      child: Column(
        children: [
          Container(
            height: 60,
            width: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Center(
              child: Image.asset(
                iconPath,
                height: 30,
                width: 30,
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorCard(String name, String specialty) {
    return Container(
      margin: const EdgeInsets.only(right: 10),
      width: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.white,
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const CircleAvatar(
            radius: 30,
            backgroundImage: AssetImage('assets/doctor_image.png'),
          ),
          const SizedBox(height: 10),
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          Text(
            specialty,
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableDoctor(String title) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.white,
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 25,
            backgroundImage: AssetImage('assets/doctor_image.png'),
          ),
          const SizedBox(width: 15),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
