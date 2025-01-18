import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mind_speak_app/providers/theme_provider.dart';
import 'package:provider/provider.dart';
import '../Components/CustomBottomNavigationBar.dart';

class ViewDoctorsPage extends StatelessWidget {
  const ViewDoctorsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: Icon(themeProvider.isDarkMode
                ? Icons.wb_sunny
                : Icons.nightlight_round),
            onPressed: () {
              themeProvider.toggleTheme(); // Toggle the theme
            },
          ),
        ],
        centerTitle: true,
        backgroundColor: themeProvider.isDarkMode
            ? Colors.black
            : Colors.lightBlue, // Custom color for this screen
        title: const Text(
          "View Therapists",
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: const ViewDoctors(),
      bottomNavigationBar: const CustomBottomNavigationBar(currentIndex: 1),
    );
  }
}

class ViewDoctors extends StatefulWidget {
  const ViewDoctors({super.key});

  @override
  State<ViewDoctors> createState() => _ViewDoctorsState();
}

class _ViewDoctorsState extends State<ViewDoctors> {
  List<Map<String, dynamic>> _allTherapist = [];
  List<Map<String, dynamic>> _foundTherapist = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchApprovedTherapist();
  }

  Future<void> fetchApprovedTherapist() async {
    try {
      // Fetch all approved therapists
      QuerySnapshot therapistSnapshot = await FirebaseFirestore.instance
          .collection('therapist')
          .where('status', isEqualTo: true)
          .get();

      // Get all user IDs from the fetched therapists
      List<String> userIds = therapistSnapshot.docs
          .map((doc) => doc['userid'] as String)
          .where((id) => id != null && id.isNotEmpty)
          .toList();

      if (userIds.isEmpty) {
        print("No approved therapists found.");
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Split userIds into batches to handle Firestore's limit of 10 items in 'whereIn'
      List<List<String>> batches = [];
      const batchSize = 10;
      for (int i = 0; i < userIds.length; i += batchSize) {
        batches.add(userIds.sublist(i,
            i + batchSize > userIds.length ? userIds.length : i + batchSize));
      }

      List<DocumentSnapshot> allDocs = [];
      for (var batch in batches) {
        QuerySnapshot userSnapshot = await FirebaseFirestore.instance
            .collection('user')
            .where(FieldPath.documentId, whereIn: batch)
            .get();
        allDocs.addAll(userSnapshot.docs);
      }

      // Create a map of userId to user data for quick lookup
      Map<String, Map<String, dynamic>> userMap = {
        for (var doc in allDocs) doc.id: doc.data() as Map<String, dynamic>
      };

      // Combine therapist data with user data
      List<Map<String, dynamic>> loadedTherapists = therapistSnapshot.docs.map(
        (doc) {
          var therapistData = doc.data() as Map<String, dynamic>;
          var userData = userMap[therapistData['userid']] ?? {};

          return {
            'id': doc.id,
            'name': userData['username'] ?? 'N/A',
            'email': userData['email'] ?? 'N/A',
            'nationalid': therapistData['nationalid'] ?? 'N/A',
          };
        },
      ).toList();

      setState(() {
        _allTherapist = loadedTherapists;
        _foundTherapist = loadedTherapists;
        _isLoading = false;
      });
    } catch (e, stacktrace) {
      print('Error fetching therapists: $e');
      print('Stacktrace: $stacktrace');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error fetching therapists: $e'),
        backgroundColor: Colors.red,
      ));
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _runFilter(String searchNames) {
    List<Map<String, dynamic>> results = [];
    if (searchNames.isEmpty) {
      results = _allTherapist;
    } else {
      results = _allTherapist
          .where((user) =>
              user["name"].toLowerCase().contains(searchNames.toLowerCase()))
          .toList();
    }

    setState(() {
      _foundTherapist = results;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Scaffold(
            resizeToAvoidBottomInset:
                true, // Adjusts layout when the keyboard is open
            body: SingleChildScrollView(
              // Ensures the content is scrollable to prevent overflow
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  TextField(
                    onChanged: (value) => _runFilter(value),
                    decoration: const InputDecoration(
                      labelText: 'Search',
                      suffixIcon: Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _foundTherapist.isNotEmpty
                      ? ListView.builder(
                          shrinkWrap:
                              true, // Ensures the ListView only takes necessary space
                          physics:
                              const NeverScrollableScrollPhysics(), // Disables ListView's scroll to let SingleChildScrollView handle it
                          itemCount: _foundTherapist.length,
                          itemBuilder: (context, index) => Card(
                            key: ValueKey(_foundTherapist[index]["id"]),
                            color: Colors.blue,
                            elevation: 4,
                            margin: const EdgeInsets.symmetric(vertical: 10),
                            child: ListTile(
                              leading: Text(
                                (index + 1).toString(),
                                style: const TextStyle(
                                    fontSize: 24, color: Colors.white),
                              ),
                              title: Text(
                                _foundTherapist[index]['name'],
                                style: const TextStyle(color: Colors.white),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Email: ${_foundTherapist[index]['email']}',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  Text(
                                    'National ID: ${_foundTherapist[index]['nationalid']}',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : const Center(
                          child: Text(
                            'No approved doctors found.',
                            style: TextStyle(fontSize: 20),
                          ),
                        ),
                ],
              ),
            ),
          );
  }
}
