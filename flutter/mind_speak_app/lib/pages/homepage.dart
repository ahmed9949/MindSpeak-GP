import 'package:flutter/material.dart';
import 'package:mind_speak_app/controllers/ProfileController.dart';
import 'package:mind_speak_app/pages/avatarpages/detections.dart';
import 'package:mind_speak_app/pages/carsfrom.dart';
import 'package:mind_speak_app/pages/profilepage.dart';
import 'package:mind_speak_app/pages/searchpage.dart';
import 'package:mind_speak_app/components/drawer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mind_speak_app/pages/avatarpages/startsession.dart';
import 'package:mind_speak_app/providers/session_provider.dart';
import 'package:mind_speak_app/providers/theme_provider.dart';
import 'package:provider/provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> therapists = [];
  String? childPhoto;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchChildPhoto();
    _fetchTherapists();
  }

  Future<void> fetchChildPhoto() async {
    try {
      final sessionProvider =
          Provider.of<SessionProvider>(context, listen: false);
      final userId = sessionProvider.userId;

      if (userId == null) {
        throw Exception('User not logged in');
      }

      final querySnapshot = await _firestore
          .collection('child')
          .where('userId', isEqualTo: userId)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        setState(() {
          childPhoto = querySnapshot.docs.first.data()['childPhoto'] as String?;
        });
      } else {
        setState(() {
          childPhoto = null;
        });
      }
    } catch (e) {
      print('Error fetching child photo: $e');
    }
  }

  Future<void> _fetchTherapists() async {
    try {
      QuerySnapshot therapistSnapshot = await _firestore
          .collection('therapist')
          .where('status', isEqualTo: true)
          .get();

      List<Map<String, dynamic>> tempTherapists = [];

      for (var doc in therapistSnapshot.docs) {
        var therapistData = doc.data() as Map<String, dynamic>;

        if (therapistData['userid'] == null ||
            therapistData['userid'].toString().isEmpty) {
          print('Skipping therapist document with invalid userid: ${doc.id}');
          continue;
        }

        DocumentSnapshot userDoc = await _firestore
            .collection('user')
            .doc(therapistData['userid'])
            .get();

        if (userDoc.exists) {
          var userData = userDoc.data() as Map<String, dynamic>;

          tempTherapists.add({
            'name': userData['username'] ?? 'Unknown',
            'email': userData['email'] ?? 'N/A',
            'therapistPhoneNumber':
                therapistData['therapistnumber']?.toString() ?? 'N/A',
            'bio': therapistData['bio'] ?? 'N/A',
            'therapistImage': therapistData['therapistimage'] ?? '',
            'therapistId': doc.id,
          });
        } else {
          print(
              'Associated user document not found for userid: ${therapistData['userid']}');
        }
      }

      setState(() {
        therapists = tempTherapists;
        isLoading = false;
      });

      print('Fetched ${therapists.length} therapists successfully.');
    } catch (e) {
      print('Error fetching therapists: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      drawer: const NavigationDrawe(),
      appBar: AppBar(
        elevation: 0,
        backgroundColor:
            themeProvider.isDarkMode ? Colors.grey[900] : Colors.blue,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            IconButton(
              icon: Icon(themeProvider.isDarkMode
                  ? Icons.wb_sunny
                  : Icons.nightlight_round),
              onPressed: () {
                themeProvider.toggleTheme();
              },
            ),
            IconButton(
              icon: const Icon(Icons.favorite_border),
              onPressed: () {},
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              const SizedBox(width: 20),
              CircleAvatar(
                radius: 50,
                backgroundImage:
                    childPhoto != null ? NetworkImage(childPhoto!) : null,
                child: childPhoto == null
                    ? const Icon(Icons.person, color: Colors.white, size: 40)
                    : null,
              ),
              const SizedBox(width: 5),
            ],
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Container(
              color: themeProvider.isDarkMode ? Colors.black : Colors.blue,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 30),
                  Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: MediaQuery.of(context).size.width *
                            0.04), // Dynamic padding
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment
                          .spaceBetween, // Ensures even spacing between cards
                      children: [
                        _buildTopCard(
                          context,
                          "Doctors",
                          "assets/doctor.png",
                          const SearchPage(),
                        ),
                        // _buildTopCard(
                        //     context, "tts", "assets/cars.png", const TTSPage()),
                        // _buildTopCard(
                        //     context, "stt", "assets/cars.png", const STTPage()),

                        _buildTopCard(context, "3d session",
                            "assets/predict.png", StartSessionPage()),
                        _buildTopCard(
                          context,
                          "Cars",
                          "assets/cars.png",
                          const carsform(),
                        ),
                        _buildTopCard(
                          context,
                          "Prediction",
                          "assets/predict.png",
                          const detection(),
                        ),
                        _buildTopCard(
                          context,
                          "Profile",
                          "assets/profile.jpg",
                          ProfilePage(controller: ProfileController()),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 35),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: themeProvider.isDarkMode
                            ? Colors.grey[900]
                            : Colors.white,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Top Therapists",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: themeProvider.isDarkMode
                                    ? Colors.white
                                    : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              height:
                                  150, // Set a fixed height for the ListView
                              child: ListView.builder(
                                scrollDirection: Axis
                                    .horizontal, // Enable horizontal scrolling
                                physics: const BouncingScrollPhysics(),
                                itemCount: therapists.length,
                                itemBuilder: (context, index) {
                                  final therapist = therapists[index];
                                  return Padding(
                                    padding: const EdgeInsets.only(
                                        right: 10), // Add spacing between cards
                                    child: _buildTherapistCard(therapist),
                                  );
                                },
                              ),
                            ),
                            // Add Quick Tips Section
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: themeProvider.isDarkMode
                                    ? Colors.grey[850]
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 10,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "Quick Tips for Parents",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                          color: themeProvider.isDarkMode
                                              ? Colors.white
                                              : Colors.black,
                                        ),
                                      ),
                                      Icon(Icons.tips_and_updates,
                                          color: Colors.blueAccent, size: 24),
                                    ],
                                  ),
                                  const SizedBox(height: 10),

                                  // Using Flutter's Built-in Carousel
                                  SizedBox(
                                    height: 120,
                                    child: PageView(
                                      scrollDirection: Axis.horizontal,
                                      children: [
                                        _buildTipCard(Icons.visibility,
                                            "Encourage eye contact with interactive games."),
                                        _buildTipCard(Icons.schedule,
                                            "Use visual schedules to reduce anxiety."),
                                        _buildTipCard(Icons.emoji_events,
                                            "Reward small achievements with positive reinforcement."),
                                        _buildTipCard(Icons.hearing,
                                            "Use clear and slow speech when communicating."),
                                        _buildTipCard(Icons.groups,
                                            "Encourage social interactions through storytelling."),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(
                                height:
                                    20), // Add spacing before the Start Session button // Add spacing before the Start Session button
                          ],
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

  Widget _buildTherapistCard(Map<String, dynamic> therapist) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 25,
            backgroundImage: therapist['therapistImage'] != null
                ? NetworkImage(therapist['therapistImage'])
                : null,
            child: therapist['therapistImage'] == null
                ? const Icon(Icons.person)
                : null,
          ),
          const SizedBox(height: 5),
          Text(
            therapist['name'],
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          Text(
            therapist['bio'],
            style: const TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

Widget _buildTipCard(IconData icon, String text) {
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.blueAccent.withOpacity(0.1),
      borderRadius: BorderRadius.circular(15),
      boxShadow: [
        BoxShadow(
          color: Colors.black12,
          blurRadius: 8,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Row(
      children: [
        Icon(icon, size: 30, color: Colors.blueAccent),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    ),
  );
}
