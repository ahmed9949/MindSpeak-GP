import 'package:flutter/material.dart';
import 'package:mind_speak_app/components/doctor_profile.dart';
import 'package:mind_speak_app/components/contact_info_card.dart';
import 'package:mind_speak_app/components/editable_fields.dart';
import 'package:mind_speak_app/pages/login.dart';
import 'package:mind_speak_app/service/doctor_dashboard_service.dart';

class DoctorDetailsPage extends StatefulWidget {
  final String sessionId;
  final Map<String, dynamic> userInfo;
  final Map<String, dynamic> therapistInfo;

  const DoctorDetailsPage({
    super.key,
    required this.sessionId,
    required this.userInfo,
    required this.therapistInfo,
  });

  @override
  _DoctorDetailsPageState createState() => _DoctorDetailsPageState();
}

class _DoctorDetailsPageState extends State<DoctorDetailsPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController bioController = TextEditingController();
  late DoctorDashboardService _doctorServices;
  Map<String, dynamic>? userInfo;
  Map<String, dynamic>? therapistInfo;

  @override
  void initState() {
    super.initState();
    _doctorServices = DoctorDashboardService();

    userInfo = Map<String, dynamic>.from(widget.userInfo);
    therapistInfo = Map<String, dynamic>.from(widget.therapistInfo);

    nameController.text = userInfo!['username'] ?? '';
    emailController.text = userInfo!['email'] ?? '';
    phoneController.text = userInfo!['phoneNumber']?.toString() ?? '';
    bioController.text = therapistInfo!['bio'] ?? '';
  }

  Future<void> refreshData() async {
    final newUserInfo =
        await _doctorServices.refreshUserData(userInfo!['userid']);
    final newTherapistInfo = await _doctorServices
        .refreshTherapistData(therapistInfo!['therapistid']);

    setState(() {
      userInfo = newUserInfo;
      therapistInfo = newTherapistInfo;
      nameController.text = newUserInfo['username'] ?? '';
      emailController.text = newUserInfo['email'] ?? '';
      phoneController.text = newUserInfo['phoneNumber']?.toString() ?? '';
      bioController.text = newTherapistInfo['bio'] ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (userInfo == null || therapistInfo == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Details'),
        backgroundColor: Colors.blue,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DoctorProfile(
              key: ValueKey(DateTime.now().millisecondsSinceEpoch),
              name: userInfo!['username'] ?? 'Doctor Name',
              bio: therapistInfo!['bio'] ?? 'bio',
              therapistImage: therapistInfo!['therapistimage'],
            ),
            ContactInfoCard(
              title: 'Email',
              subtitle: userInfo!['email'],
              icon: Icons.email,
            ),
            ContactInfoCard(
              title: 'Phone',
              subtitle: userInfo!['phoneNumber']?.toString(),
              icon: Icons.phone,
            ),
            const SizedBox(height: 16),
            const Text(
              'Edit Profile',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    EditableField(
                      controller: nameController,
                      label: 'Name',
                    ),
                    const SizedBox(height: 16),
                    EditableField(
                      controller: emailController,
                      label: 'Email',
                      inputType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    EditableField(
                      controller: phoneController,
                      label: 'Phone Number',
                      inputType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    EditableField(
                      controller: bioController,
                      label: 'Bio',
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton.icon(
                onPressed: () async {
                  String name = nameController.text;
                  String email = emailController.text;
                  String bio = bioController.text;
                  String phoneNumber = phoneController.text;

                  if (phoneNumber.length != 11 ||
                      int.tryParse(phoneNumber) == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Please enter a valid phone number.')),
                    );
                    return;
                  }

                  Map<String, dynamic> updatedUserInfo = {
                    'username': name,
                    'email': email,
                    'phoneNumber': int.parse(phoneNumber),
                  };

                  Map<String, dynamic> updatedTherapistInfo = {
                    'bio': bio,
                  };

                  await _doctorServices.updateUserInfo(
                      userInfo!['userid'], updatedUserInfo);
                  await _doctorServices.updateTherapistInfo(
                      therapistInfo!['therapistid'], updatedTherapistInfo);

                  await refreshData();

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Details updated successfully!')),
                  );
                },
                icon: const Icon(Icons.save, color: Colors.blue),
                label: const Text('Save Changes',
                    style: TextStyle(color: Colors.black)),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Delete Account',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text(
                      'Warning: Deleting your account is permanent. You will lose all your data.',
                      style: TextStyle(fontSize: 16, color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () async {
                        bool confirmDelete = await showDialog(
                          context: context,
                          builder: (BuildContext context) => AlertDialog(
                            title: const Text('Confirm Deletion'),
                            content: const Text(
                                'Are you sure you want to delete your account? This action cannot be undone.'),
                            actions: <Widget>[
                              TextButton(
                                child: const Text('Cancel'),
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                              ),
                              TextButton(
                                child: const Text('Delete'),
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                              ),
                            ],
                          ),
                        );

                        if (confirmDelete) {
                          await _doctorServices.deleteAccount(
                            userInfo!['userid'],
                            therapistInfo!['therapistid'],
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Account deleted successfully')),
                          );
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LogIn(),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.delete, color: Colors.white),
                      label: const Text('Delete Account',
                          style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
