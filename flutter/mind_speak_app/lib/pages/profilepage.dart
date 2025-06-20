import 'package:flutter/material.dart';
import 'package:mind_speak_app/controllers/ProfileController.dart';
import 'package:mind_speak_app/pages/login.dart';
import 'package:mind_speak_app/providers/color_provider.dart';
import 'package:mind_speak_app/providers/theme_provider.dart';
import 'package:mind_speak_app/providers/session_provider.dart';
import 'package:provider/provider.dart';

class ProfilePage extends StatefulWidget {
  final ProfileController controller;

  const ProfilePage({
    super.key,
    required this.controller,
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
                'Are you sure you want to delete your account? This will delete all your data and your children\'s data from the system and cannot be undone.'),
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Deleting account... Please wait.'),
        ));
      }

      await widget.controller.deleteParentAccount(userId);

      await sessionProvider.clearSession();

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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error deleting account: \${e.toString()}'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  void _showUpdateDialog(Map<String, dynamic> child) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final colorProvider = Provider.of<ColorProvider>(context, listen: false);

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
          titlePadding: EdgeInsets.zero,
          title: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: themeProvider.isDarkMode
                    ? [Colors.grey[900]!, Colors.black]
                    : [
                        colorProvider.primaryColor,
                        colorProvider.primaryColor
                            .withAlpha((0.9 * 255).toInt()),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Text(
              'Update Child',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
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
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: () => _pickImage(child['id']),
                  icon: const Icon(Icons.image),
                  label: const Text('Update Photo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorProvider.primaryColor,
                    foregroundColor: Colors.white,
                  ),
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
                  'name': nameController.text.trim(),
                  'age': int.parse(ageController.text),
                  'childInterest': interestController.text.trim(),
                });
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colorProvider.primaryColor,
                foregroundColor: Colors.white,
              ),
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
        final colorProvider = Provider.of<ColorProvider>(context);


    return Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          automaticallyImplyLeading: true, // ✅ Enables the back button
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: themeProvider.isDarkMode
    ? [Colors.grey[900]!, Colors.black]
    : [
        colorProvider.primaryColor,
        colorProvider.primaryColor.withAlpha((0.9 * 255).toInt()), // Alpha: 230
      ],


                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
            ),
          ),
          elevation: 5,
          title: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.account_circle_rounded, color: Colors.white, size: 30),
              SizedBox(width: 10),
              Text(
                'Profile Page',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(
                themeProvider.isDarkMode
                    ? Icons.wb_sunny_outlined
                    : Icons.nightlight_round_rounded,
                color: Colors.white,
                size: 30,
              ),
              onPressed: () {
                themeProvider.toggleTheme();
              },
            ),
          ],
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(20),
            ),
          ),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(16.0),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Parent Info Section
                      Text(
                        'Parent Info',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: themeProvider.isDarkMode
                                  ? Colors.white
                                  : Colors.black,
                            ),
                      ),
                      const SizedBox(height: 10),
                      Card(
                        elevation: 6,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          title: Text(
                            'Name: ${parentData?['username'] ?? 'N/A'}',
                            style: const TextStyle(fontSize: 16),
                          ),
                          subtitle: Text(
                            'Email: ${parentData?['email'] ?? 'N/A'}',
                            style: TextStyle(
                                fontSize: 14, color: Colors.grey[600]),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: deleteParentAccount,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          padding: const EdgeInsets.symmetric(
                              vertical: 14, horizontal: 24),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 5,
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.delete, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              'Delete Account',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 30),

                      // Children Section
                      Text(
                        'Children Info',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: themeProvider.isDarkMode
                                  ? Colors.white
                                  : Colors.black,
                            ),
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
                                  elevation: 6,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundImage: child['childPhoto'] !=
                                              null
                                          ? NetworkImage(child['childPhoto'])
                                          : null,
                                      child: child['childPhoto'] == null
                                          ? const Icon(Icons.person)
                                          : null,
                                    ),
                                    title: Text(
                                      child['name'],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
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
                          : const Text(
                              'No children added yet.',
                              style:
                                  TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                      const Divider(height: 30),

                      // Cars Trials Forms Section
                      Text(
                        'Cars Trials Forms',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: themeProvider.isDarkMode
                                  ? Colors.white
                                  : Colors.black,
                            ),
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
                                  elevation: 6,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ExpansionTile(
                                    title: Text(
                                      'Cars Form Trial ${car['trial']}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
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
                          : const Text(
                              'No cars trials available.',
                              style:
                                  TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                    ],
                  ),
                ),
              ));
  }
}
