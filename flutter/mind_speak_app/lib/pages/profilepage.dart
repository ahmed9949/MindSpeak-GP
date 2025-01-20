import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mind_speak_app/providers/theme_provider.dart';
import 'package:mind_speak_app/providers/session_provider.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';


class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String? parentId;
  Map<String, dynamic>? parentData;
  List<Map<String, dynamic>> childrenData = [];
  List<Map<String, dynamic>> carsData = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchParentAndChildData();
  }

  Future<void> fetchParentAndChildData() async {
    try {
      final sessionProvider =
          Provider.of<SessionProvider>(context, listen: false);
      final userId = sessionProvider.userId;

      if (userId == null) {
        throw Exception('User not logged in');
      }

      // Fetch parent data
      DocumentSnapshot parentSnapshot =
          await FirebaseFirestore.instance.collection('user').doc(userId).get();

      if (!parentSnapshot.exists) {
        throw Exception('Parent not found');
      }

      parentData = parentSnapshot.data() as Map<String, dynamic>;

      // Fetch child data
      QuerySnapshot childSnapshot = await FirebaseFirestore.instance
          .collection('child')
          .where('userId', isEqualTo: userId)
          .get();

      List<Map<String, dynamic>> childrenWithDetails = [];
      List<Map<String, dynamic>> carsWithDetails = [];

      for (var child in childSnapshot.docs) {
        final childId = child['childId'];
        QuerySnapshot carDetailsSnapshot = await FirebaseFirestore.instance
            .collection('Cars')
            .where('childId', isEqualTo: childId)
            .get();

        Map<String, dynamic> childData = child.data() as Map<String, dynamic>;

        int trialCounter = 1;
        for (var carDetails in carDetailsSnapshot.docs) {
          carsWithDetails.add({
            'trial': trialCounter++, // Add trial count
            'childId': carDetails['childId'],
            'totalScore': carDetails['totalScore'],
            'selectedQuestions': carDetails['selectedQuestions'],
            'status': carDetails['status'],
          });
        }

        childrenWithDetails.add({...childData, 'id': child.id});
      }

      setState(() {
        parentId = userId;
        childrenData = childrenWithDetails;
        carsData = carsWithDetails;
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> updateChild(
      String childId, Map<String, dynamic> updatedData) async {
    try {
      await FirebaseFirestore.instance
          .collection('child')
          .doc(childId)
          .update(updatedData);

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Child updated successfully!'),
        backgroundColor: Colors.green,
      ));

      fetchParentAndChildData(); // Refresh data
    } catch (e) {
      print('Error updating child: $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Error updating child'),
        backgroundColor: Colors.red,
      ));
    }
  }

  Future<void> _pickImage(String childId) async {
  final picker = ImagePicker();
  final pickedFile = await picker.pickImage(source: ImageSource.gallery);

  if (pickedFile != null) {
    File file = File(pickedFile.path);

    try {
      // Upload the image to Firebase Storage
      final storageRef = FirebaseStorage.instance.ref().child('child_images/$childId.jpg');
      await storageRef.putFile(file);

      // Get the uploaded image URL
      String imageUrl = await storageRef.getDownloadURL();

      // Update Firestore with the new image URL
      await updateChild(childId, {'childPhoto': imageUrl});
    } catch (e) {
      print('Error updating photo: $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Error uploading photo.'),
        backgroundColor: Colors.red,
      ));
    }
  }
}
  void _showUpdateDialog(Map<String, dynamic> child) {
    TextEditingController ageController =
        TextEditingController(text: child['age'].toString());
    TextEditingController interestController =
        TextEditingController(text: child['childInterest']);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Update Child'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: ageController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Age'),
                ),
                TextField(
                  controller: interestController,
                  decoration: const InputDecoration(labelText: 'Interest'),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: () => _pickImage(child['id']),
                  icon: const Icon(Icons.image),
                  label: const Text('Update Photo'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                int age = int.tryParse(ageController.text) ?? -1;
                if (age < 3 || age > 12) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Age must be between 3 and 12'),
                    backgroundColor: Colors.red,
                  ));
                  return;
                }
                updateChild(child['id'], {
                  'age': age,
                  'childInterest': interestController.text.trim(),
                });
                Navigator.pop(context);
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Profile Page'),
        actions: [
          IconButton(
            icon: Icon(themeProvider.isDarkMode
                ? Icons.wb_sunny
                : Icons.nightlight_round),
            onPressed: () {
              themeProvider.toggleTheme();
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Parent Info',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 10),
                    Card(
                      elevation: 4,
                      child: ListTile(
                        title: Text('Name: ${parentData?['username'] ?? 'N/A'}'),
                        subtitle:
                            Text('Email: ${parentData?['email'] ?? 'N/A'}'),
                      ),
                    ),
                    const Divider(height: 30),
                    Text(
                      'Children',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 10),
                    childrenData.isNotEmpty
                        ? ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: childrenData.length,
                            itemBuilder: (context, index) {
                              final child = childrenData[index];
                              return Card(
                                margin:
                                    const EdgeInsets.symmetric(vertical: 8.0),
                                elevation: 4,
                                 child: ListTile(
                                   leading: CircleAvatar(
    backgroundImage: child['childPhoto'] != null
        ? NetworkImage(child['childPhoto']) // Display from URL
        : null,
    child: child['childPhoto'] == null
        ? const Icon(Icons.person) // Fallback if no photo
        : null,
  ),
  title: Text(child['name']),
  subtitle: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Age: ${child['age']}'),
      Text('Interest: ${child['childInterest']}'),
    ],
  ),
  trailing: IconButton(
    icon: const Icon(Icons.edit, color: Colors.blue),
    onPressed: () {
      _showUpdateDialog(child);
    },
  ),
                                ),
                              );
                            },
                          )
                        : const Text('No children added yet.'),
                    const Divider(height: 30),
                    Text(
                      'Cars Trials Forms',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 10),
                    carsData.isNotEmpty
                        ? ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: carsData.length,
                            itemBuilder: (context, index) {
                              final car = carsData[index];
                              return Card(
                                margin:
                                    const EdgeInsets.symmetric(vertical: 8.0),
                                elevation: 4,
                                child: ListTile(
                                  title: Text(
                                      'Cars Form Trial ${car['trial']}'),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Child ID: ${car['childId']}'),
                                      Text(
                                          'Total Score: ${car['totalScore']}'),
                                      Text(
                                          'Selected Questions: ${(car['selectedQuestions'] as List<dynamic>?)?.join(", ") ?? 'N/A'}'),
                                      Text('Status: ${car['status']}'),
                                    ],
                                  ),
                                ),
                              );
                            },
                          )
                        : const Text('No cars trials available.'),
                  ],
                ),
              ),
            ),
    );
  }
}
