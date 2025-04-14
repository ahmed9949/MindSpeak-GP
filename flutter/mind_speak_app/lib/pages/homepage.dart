import 'package:flutter/material.dart';
import 'package:mind_speak_app/controllers/ProfileController.dart';
// import 'package:mind_speak_app/pages/avatarpages/detections.dart';
import 'package:mind_speak_app/pages/carsfrom.dart';
import 'package:mind_speak_app/pages/profilepage.dart';
import 'package:mind_speak_app/pages/searchpage.dart';
import 'package:mind_speak_app/components/drawer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mind_speak_app/pages/avatarpages/startsessioncl.dart';
import 'package:mind_speak_app/providers/session_provider.dart';
import 'package:mind_speak_app/providers/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:mind_speak_app/providers/color_provider.dart';


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
      print('Fetching therapists for home page...');
      // Get therapists with status = true
      QuerySnapshot therapistSnapshot = await _firestore
          .collection('therapist')
          .where('status', isEqualTo: true)
          .get();

      print(
          'Found ${therapistSnapshot.docs.length} therapists with status=true');
      List<Map<String, dynamic>> tempTherapists = [];

      for (var doc in therapistSnapshot.docs) {
        var therapistData = doc.data() as Map<String, dynamic>;
        String therapistId = doc.id;

        print('Processing therapist: $therapistId');

        // Query the users collection
        DocumentSnapshot userDoc = await _firestore
            .collection(
                'users') // Make sure this is the correct collection name
            .doc(therapistId)
            .get();

        if (userDoc.exists) {
          print('Found user data for therapist: $therapistId');
          var userData = userDoc.data() as Map<String, dynamic>;

          tempTherapists.add({
            'name': userData['username'] ?? 'Unknown',
            'email': userData['email'] ?? 'N/A',
            'phoneNumber': userData['phoneNumber']?.toString() ?? 'N/A',
            'bio': therapistData['bio'] ?? 'N/A',
            'therapistImage': therapistData['therapistimage'] ?? '',
            'therapistId': therapistId,
          });

          print(
              'Added therapist to list: ${userData['username'] ?? 'Unknown'}');
        } else {
          print('User document not found for therapist ID: $therapistId');

          // Add therapist with available data even if user data is missing
          tempTherapists.add({
            'name': 'Unknown',
            'email': 'N/A',
            'phoneNumber': 'N/A',
            'bio': therapistData['bio'] ?? 'N/A',
            'therapistImage': therapistData['therapistimage'] ?? '',
            'therapistId': therapistId,
          });
        }
      }


      setState(() {
        therapists = tempTherapists;
        isLoading = false;
      });

      print(
          'Fetched ${therapists.length} therapists successfully for home page.');
    } catch (e) {
      print('Error fetching therapists for home page: $e');
      setState(() {
        isLoading = false;
      });
    }
  }
  

  void checkCarsFormAndStartSession(BuildContext context) async {
    final sessionProvider =
        Provider.of<SessionProvider>(context, listen: false);
    await sessionProvider.fetchChildId(); // <- Ensure it's up to date
    final userId = sessionProvider.userId;

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User not logged in'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // ✅ Fetch child data
      final childSnapshot = await FirebaseFirestore.instance
          .collection('child')
          .where('userId', isEqualTo: userId)
          .get();

      if (childSnapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No child data found for the logged-in user.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final childId = childSnapshot.docs.first.id;

      // ✅ Fetch Cars form
      final carsSnapshot = await FirebaseFirestore.instance
          .collection('Cars')
          .where('childId', isEqualTo: childId)
          .get();

      if (carsSnapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No Cars form data found.'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Complete Cars Form',
              textColor: Colors.white,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CarsForm()),
                );
              },
            ),
          ),
        );
        return;
      }


      final rawData = carsSnapshot.docs.first.data();

      final formStatus = rawData['status'] ?? false;

      if (formStatus == true) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const StartSessionPage()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'You should complete the Cars form first to start the session.'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Cars Form',
              textColor: Colors.white,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CarsForm()),
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Something went wrong: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  

  Widget _buildTopCard(
    
    BuildContext context,
    String title,
    String iconPath,
    Widget page, {
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: () {
        final sessionProvider =
            Provider.of<SessionProvider>(context, listen: false);

        // ✅ Handle "3D Session" card with session check
        if (title.toLowerCase() == "3d session") {
          if (sessionProvider.isLoading) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Loading user session..."),
                backgroundColor: Colors.orange,
              ),
            );
            return;
          }

          if (!sessionProvider.isLoggedIn || sessionProvider.userId == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Please log in to start a session."),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }

          // ✅ Proceed to session validation
          checkCarsFormAndStartSession(context);
        } else {
          // ✅ Navigate for other cards
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => page),
          );
        }
      },
      child: Column(
        children: [
          Container(
            height: 60,
            width: 60,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black26 : Colors.grey.withOpacity(0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Image.asset(
                iconPath,
                height: 30,
                width: 30,
                color: isDark ? Colors.white : null,
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            title,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final colorProvider = Provider.of<ColorProvider>(context);


    return Scaffold(
      drawer: const NavigationDrawe(),
      backgroundColor: themeProvider.isDarkMode ? Colors.black : Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(240),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
                               colors: themeProvider.isDarkMode
    ? [Colors.grey[900]!, Colors.black]
    : [colorProvider.primaryColor, colorProvider.primaryColor.withOpacity(0.9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(30),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          // 🔹 Drawer hamburger icon
                          Builder(
                            builder: (context) => IconButton(
                              icon: const Icon(Icons.menu, color: Colors.white),
                              onPressed: () =>
                                  Scaffold.of(context).openDrawer(),
                            ),
                          ),
                          const CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.white,
                            child: Icon(Icons.apps,
                                color: Colors.blueAccent, size: 18),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            "MindSpeak",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              themeProvider.isDarkMode
                                  ? Icons.wb_sunny
                                  : Icons.nightlight_round,
                              color: Colors.white,
                            ),
                            onPressed: () => themeProvider.toggleTheme(),
                          ),
                          const SizedBox(width: 5),
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.white,
                            backgroundImage: childPhoto != null
                                ? NetworkImage(childPhoto!)
                                : null,
                            child: childPhoto == null
                                ? const Icon(Icons.person,
                                    size: 20, color: Colors.grey)
                                : null,
                          ),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Explore",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment
                          .center, // Center the items horizontally
                      children: [
                        const SizedBox(
                            width:
                                35), // Add padding to the left side for spacing
                        _buildTopCard(
                          context,
                          "Doctors",
                          "assets/doctor.png",
                          const SearchPage(),
                          isDark: themeProvider.isDarkMode,
                        ),
                        const SizedBox(width: 20), // Add spacing between cards
                        _buildTopCard(
                          context,
                          "3D Session",
                          "assets/predict.png",
                          const StartSessionPage(),
                          isDark: themeProvider.isDarkMode,
                        ),
                        const SizedBox(width: 20), // Add spacing between cards
                        _buildTopCard(
                          context,
                          "Cars",
                          "assets/cars.png",
                          const CarsForm(),
                          isDark: themeProvider.isDarkMode,
                        ),
                        const SizedBox(width: 20), // Add spacing between cards
                        _buildTopCard(
                          context,
                          "Profile",
                          "assets/profile.jpg",
                          ProfilePage(controller: ProfileController()),
                          isDark: themeProvider.isDarkMode,
                        ),
                        const SizedBox(
                            width:
                                20), // Add padding to the right side for spacing
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: themeProvider.isDarkMode
                      ? [Colors.black, Colors.grey[900]!]
                      : [Colors.blue.shade50, Colors.white],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: MediaQuery.of(context).size.width *
                            0.04), // Dynamic padding
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment
                          .spaceBetween, // Ensures even spacing between cards
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      // Wrapping the whole content to make it scrollable
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top Therapists Section
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
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
                                  Text(
                                    "Found: ${therapists.length}",
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              therapists.isEmpty
                                  ? const Center(
                                      child: Padding(
                                        padding:
                                            EdgeInsets.symmetric(vertical: 20),
                                        child: Text(
                                          "No therapists available",
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    )
                                  : SizedBox(
                                      height: 200,
                                      child: ListView.builder(
                                        scrollDirection: Axis.horizontal,
                                        physics: const BouncingScrollPhysics(),
                                        itemCount: therapists.length,
                                        itemBuilder: (context, index) {
                                          final therapist = therapists[index];
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                                right: 12),
                                            child: _buildTherapistCard(
                                              therapist,
                                              isDark: themeProvider.isDarkMode,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                              const SizedBox(height: 20),

                              // Quick Tips for Parents Section
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: themeProvider.isDarkMode
                                      ? Colors.grey[850]
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: const [
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
                                        const Icon(Icons.tips_and_updates,
                                            color: Colors.blueAccent, size: 24),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      height: 120,
                                      child: PageView(
                                        scrollDirection: Axis.horizontal,
                                        children: [
                                          _buildTipCard(
                                              Icons.visibility,
                                              "Encourage eye contact with interactive games.",
                                              context),
                                          _buildTipCard(
                                              Icons.schedule,
                                              "Use visual schedules to reduce anxiety.",
                                              context),
                                          _buildTipCard(
                                              Icons.emoji_events,
                                              "Reward small achievements with positive reinforcement.",
                                              context),
                                          _buildTipCard(
                                              Icons.hearing,
                                              "Use clear and slow speech when communicating.",
                                              context),
                                          _buildTipCard(
                                              Icons.groups,
                                              "Encourage social interactions through storytelling.",
                                              context),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              Consumer<SessionProvider>(
                                builder: (context, sessionProvider, _) {
                                  final sessionCount =
                                      sessionProvider.thisWeekSessionCount;
                                  final improvementText = sessionCount >= 3
                                      ? "Great progress this week!"
                                      : sessionCount > 0
                                          ? "Keep practicing together."
                                          : "Start a session to begin tracking.";

                                  final isDark = themeProvider.isDarkMode;

                                  return Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: isDark
                                            ? [
                                                Colors.blueGrey.shade800,
                                                Colors.blueGrey.shade700,
                                              ]
                                            : [
                                                Color(0xFFFFC1CC),
                                                Color(0xFFBDE0FE),
                                              ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black12,
                                          blurRadius: 10,
                                          offset: Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.insights,
                                            size: 40, color: Colors.white),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                "Child Progress",
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                "Sessions this week: $sessionCount\n$improvementText",
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.white
                                                      .withOpacity(0.9),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                ],
              ),
            ),
    );
  }

  Widget _buildTherapistCard(Map<String, dynamic> therapist,
      {required bool isDark}) {
    return SizedBox(
      width: 160,
      child: Card(
        color: isDark ? Colors.grey[850] : Colors.white,
        elevation: 6,
        shadowColor: Colors.black26,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Image
              therapist['therapistImage'] != null &&
                      therapist['therapistImage'].isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(40),
                      child: Image.network(
                        therapist['therapistImage'],
                        height: 70,
                        width: 70,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          print('Image load error: $error');
                          return CircleAvatar(
                            radius: 35,
                            backgroundColor: Colors.grey[300],
                            child: const Icon(Icons.person, color: Colors.grey),
                          );
                        },
                      ),
                    )
                  : CircleAvatar(
                      radius: 35,
                      backgroundColor: Colors.grey[300],
                      child: const Icon(Icons.person, color: Colors.grey),
                    ),

              const SizedBox(height: 10),

              // Name
              Text(
                therapist['name'] ?? 'Unknown',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: isDark ? Colors.white : Colors.black,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 4),

              // Bio
              Text(
                therapist['bio'] ?? 'N/A',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[300] : Colors.grey[600],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTipCard(IconData icon, String text, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.blueAccent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.3) : Colors.black12,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.blueGrey : Colors.blueAccent.withOpacity(0.3),
          width: 1.2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 28, color: Colors.blueAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black87,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
