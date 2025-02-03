import 'package:flutter/material.dart';
import 'package:mind_speak_app/controllers/ProfileController.dart';

import 'package:mind_speak_app/pages/login.dart';
import 'package:mind_speak_app/providers/theme_provider.dart';
import 'package:mind_speak_app/providers/session_provider.dart';
import 'package:provider/provider.dart';

class ProfilePage extends StatefulWidget {
  final ProfileController controller;

  const ProfilePage({
    super.key,
    required this.controller, // Make controller required
  });

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

      await widget.controller.fetchParentAndChildData(userId);

      setState(() {
        parentId = widget.controller.parentId;
        parentData = widget.controller.parentData;
        childrenData = widget.controller.childrenData;
        carsData = widget.controller.carsData;
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching data: $e');
      setState(() {
        isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error loading profile data'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> updateChild(
      String childId, Map<String, dynamic> updatedData) async {
    try {
      await widget.controller.updateChild(childId, updatedData);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Child updated successfully!'),
        backgroundColor: Colors.green,
      ));
      fetchParentAndChildData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Error updating child'),
        backgroundColor: Colors.red,
      ));
    }
  }

  Future<void> _pickImage(String childId) async {
    try {
      await widget.controller.updateChildPhoto(childId);
      fetchParentAndChildData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Error uploading photo.'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Future<void> deleteParentAccount() async {
    try {
      bool confirmDelete = await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Confirm Deletion'),
            content: const Text(
                'Are you sure you want to delete your account? This will also delete all associated child data and cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      );

      if (!confirmDelete) return;

      final sessionProvider =
          Provider.of<SessionProvider>(context, listen: false);
      final userId = sessionProvider.userId;

      if (userId == null) {
        throw Exception('User not logged in');
      }

      await widget.controller.deleteParentAccount(userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Account deleted successfully.'),
          backgroundColor: Colors.green,
        ));

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LogIn()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Error deleting account. Please try again later.'),
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
                if (!widget.controller.isValidAge(ageController.text)) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Age must be between 3 and 12'),
                    backgroundColor: Colors.red,
                  ));
                  return;
                }
                updateChild(child['id'], {
                  'age': int.parse(ageController.text),
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
        backgroundColor:
            themeProvider.isDarkMode ? Colors.grey[900] : Colors.blue,
        title: const Center(
          child: Text(
            'Profile Page',
            style: TextStyle(color: Colors.white),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              themeProvider.isDarkMode
                  ? Icons.wb_sunny
                  : Icons.nightlight_round,
              color: Colors.white,
            ),
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
                        title:
                            Text('Name: ${parentData?['username'] ?? 'N/A'}'),
                        subtitle:
                            Text('Email: ${parentData?['email'] ?? 'N/A'}'),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: deleteParentAccount,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 20,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.delete, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              'Delete Account',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 30),
                    Text(
                      'child',
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
                                        ? NetworkImage(child['childPhoto'])
                                        : null,
                                    child: child['childPhoto'] == null
                                        ? const Icon(Icons.person)
                                        : null,
                                  ),
                                  title: Text(child['name']),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Age: ${child['age']}'),
                                      Text(
                                          'Interest: ${child['childInterest']}'),
                                      Text(
                                          'Therapist: ${child['therapistName']}'),
                                    ],
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.edit,
                                        color: Colors.blue),
                                    onPressed: () => _showUpdateDialog(child),
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
                                child: ExpansionTile(
                                  title:
                                      Text('Cars Form Trial ${car['trial']}'),
                                  children: [
                                    ListTile(
                                      title: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text('Child ID: ${car['childId']}'),
                                          Text(
                                              'Total Score: ${car['totalScore']}'),
                                          Text(
                                            'Selected Questions: ${(car['selectedQuestions'] as List<dynamic>?)?.join(", ") ?? 'N/A'}',
                                          ),
                                          Text('Status: ${car['status']}'),
                                        ],
                                      ),
                                    ),
                                  ],
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
