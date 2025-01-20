import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mind_speak_app/providers/session_provider.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> therapists = [];
  List<Map<String, dynamic>> filteredTherapists = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTherapists();
  }

  Future<void> _fetchTherapists() async {
    try {
      // Fetch all therapists with 'status' equal to true
      QuerySnapshot therapistSnapshot = await _firestore
          .collection('therapist')
          .where('status', isEqualTo: true)
          .get();

      List<Map<String, dynamic>> tempTherapists = [];

      for (var doc in therapistSnapshot.docs) {
        var therapistData = doc.data() as Map<String, dynamic>;

        // Skip documents with invalid or missing 'userid'
        if (therapistData['userid'] == null ||
            therapistData['userid'].toString().isEmpty) {
          print('Skipping therapist document with invalid userid: ${doc.id}');
          continue;
        }

        // Fetch associated user document
        DocumentSnapshot userDoc = await _firestore
            .collection('user')
            .doc(therapistData['userid'])
            .get();

        if (userDoc.exists) {
          var userData = userDoc.data() as Map<String, dynamic>;

          // Combine therapist and user data
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

      // Update the state with the fetched data
      setState(() {
        therapists = tempTherapists;
        filteredTherapists = tempTherapists;
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

  Future<void> _assignTherapistToChild(String therapistId) async {
    final sessionProvider =
        Provider.of<SessionProvider>(context, listen: false);
    final userId = sessionProvider.userId;

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No logged-in user.')),
      );
      print('Error: userId is null.');
      return;
    }

    try {
      // Ensure the therapist exists before proceeding
      DocumentSnapshot therapistDoc =
          await _firestore.collection('therapist').doc(therapistId).get();

      if (!therapistDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selected therapist does not exist.')),
        );
        return;
      }

      // Reference the child document
      QuerySnapshot childQuery = await _firestore
          .collection('child')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (childQuery.docs.isEmpty) {
        // Log and create the document if not found
        print('Child document does not exist. Creating a new document.');
        await _firestore.collection('child').add({
          'userId': userId,
          'therapistId': therapistId,
          'assigned': true,
        });
        print('New child document created.');
      } else {
        // Update the existing document
        print('Child document exists. Updating the document.');
        await childQuery.docs.first.reference.update({
          'therapistId': therapistId,
          'assigned': true,
        });
        print('Child document updated.');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Therapist assigned successfully!')),
      );
    } catch (e) {
      print('Error assigning therapist: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to assign therapist.')),
      );
    }
  }

  void _showTherapistDetails(Map<String, dynamic> therapist) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Therapist Image
                  if (therapist['therapistImage'] != null &&
                      therapist['therapistImage'].isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        therapist['therapistImage'],
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    Container(
                      height: 200,
                      width: double.infinity,
                      color: Colors.grey[300],
                      child: const Icon(Icons.person,
                          size: 100, color: Colors.grey),
                    ),
                  const SizedBox(height: 16),
                  // Therapist Name
                  Text(
                    therapist['name'] ?? 'Unknown',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Email
                  Row(
                    children: [
                      const Icon(Icons.email, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          therapist['email'] ?? 'N/A',
                          style: const TextStyle(fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Phone Number
                  Row(
                    children: [
                      const Icon(Icons.phone, color: Colors.green),
                      const SizedBox(width: 8),
                      Text(
                        therapist['therapistPhoneNumber'] ?? 'N/A',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Bio
                  Text(
                    therapist['bio'] ?? 'No bio available',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  // Assign Button
                  ElevatedButton(
                    onPressed: () async {
                      await _assignTherapistToChild(therapist['therapistId']);
                      Navigator.pop(context);
                    },
                    child: const Text('Assign'),
                  ),
                  const SizedBox(height: 8),
                  // Close Button
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Search Therapists',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue,
      ),
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextField(
                      onChanged: (query) {
                        setState(() {
                          filteredTherapists = therapists
                              .where((therapist) => therapist['name']
                                  .toLowerCase()
                                  .contains(query.toLowerCase()))
                              .toList();
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search therapist by name',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: filteredTherapists.isNotEmpty
                        ? GridView.builder(
                            padding: const EdgeInsets.all(16.0),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 0.8,
                            ),
                            itemCount: filteredTherapists.length,
                            itemBuilder: (context, index) {
                              final therapist = filteredTherapists[index];
                              return GestureDetector(
                                onTap: () => _showTherapistDetails(therapist),
                                child: Card(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  elevation: 4,
                                  child: Column(
                                    children: [
                                      // Therapist Image
                                      if (therapist['therapistImage'] != null &&
                                          therapist['therapistImage']
                                              .isNotEmpty)
                                        ClipRRect(
                                          borderRadius:
                                              const BorderRadius.vertical(
                                            top: Radius.circular(15),
                                          ),
                                          child: Image.network(
                                            therapist['therapistImage'],
                                            height: 120,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                      else
                                        Container(
                                          height: 120,
                                          width: double.infinity,
                                          color: Colors.grey[300],
                                          child: const Icon(Icons.person,
                                              size: 60, color: Colors.grey),
                                        ),
                                      // Therapist Name
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          therapist['name'] ?? 'Unknown',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          )
                        : const Center(
                            child: Text('No therapists found.'),
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}
