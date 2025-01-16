import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mind_speak_app/providers/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String? parentId;
  Map<String, dynamic>? parentData;
  List<Map<String, dynamic>> childrenData = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchParentAndChildData();
  }

  Future<void> fetchParentAndChildData() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
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

      childrenData = childSnapshot.docs
          .map((doc) => {...doc.data() as Map<String, dynamic>, 'id': doc.id})
          .toList();

      setState(() {
        parentId = userId;
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> addChild(Map<String, dynamic> childData) async {
    try {
      String childId = const Uuid().v4(); // Generate unique child ID
      await FirebaseFirestore.instance.collection('child').doc(childId).set({
        ...childData,
        'childId': childId,
        'userId': parentId,
        'assigned': false, // Default assigned status is false
        'therapistId': '', // No therapist assigned initially
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Child added successfully!'),
        backgroundColor: Colors.green,
      ));

      fetchParentAndChildData(); // Refresh data
    } catch (e) {
      print('Error adding child: $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Error adding child'),
        backgroundColor: Colors.red,
      ));
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

  Future<void> deleteChild(String childId) async {
    try {
      await FirebaseFirestore.instance
          .collection('child')
          .doc(childId)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Child deleted successfully!'),
        backgroundColor: Colors.green,
      ));

      fetchParentAndChildData(); // Refresh data
    } catch (e) {
      print('Error deleting child: $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Error deleting child'),
        backgroundColor: Colors.red,
      ));
    }
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
              themeProvider.toggleTheme(); // Toggle the theme
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
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
                      subtitle: Text('Email: ${parentData?['email'] ?? 'N/A'}'),
                    ),
                  ),
                  const Divider(height: 30),
                  Text(
                    'Children',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 10),
                  childrenData.isNotEmpty
                      ? Expanded(
                          child: ListView.builder(
                            itemCount: childrenData.length,
                            itemBuilder: (context, index) {
                              final child = childrenData[index];
                              return Dismissible(
                                key: Key(child['id']),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  color: Colors.red,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20.0),
                                  child: const Icon(Icons.delete,
                                      color: Colors.white),
                                ),
                                onDismissed: (_) {
                                  deleteChild(child['id']);
                                },
                                child: Card(
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 8.0),
                                  elevation: 4,
                                  child: ListTile(
                                    title: Text(child['name']),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('Age: ${child['age']}'),
                                        Text(
                                            'Interest: ${child['childInterest']}'),
                                        Text('Assigned: ${child['assigned']}'),
                                      ],
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.edit,
                                          color: Colors.blue),
                                      onPressed: () {
                                        _showUpdateDialog(child);
                                      },
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        )
                      : const Text('No children added yet.'),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddChildDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddChildDialog() {
    TextEditingController nameController = TextEditingController();
    TextEditingController ageController = TextEditingController();
    TextEditingController interestController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Child'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                TextField(
                  controller: ageController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Age'),
                ),
                TextField(
                  controller: interestController,
                  decoration: const InputDecoration(labelText: 'Interest'),
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
                addChild({
                  'name': nameController.text.trim(),
                  'age': age,
                  'childInterest': interestController.text.trim(),
                  'childPhoto': '', // Default empty photo
                });
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _showUpdateDialog(Map<String, dynamic> child) {
    TextEditingController nameController =
        TextEditingController(text: child['name']);
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
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                TextField(
                  controller: ageController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Age'),
                ),
                TextField(
                  controller: interestController,
                  decoration: const InputDecoration(labelText: 'Interest'),
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
                  'name': nameController.text.trim(),
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
}
