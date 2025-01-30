import 'package:flutter/material.dart';
import 'package:mind_speak_app/components/CustomBottomNavigationBar.dart';
import 'package:mind_speak_app/controllers/AdminController.dart';
import 'package:mind_speak_app/providers/theme_provider.dart';
import 'package:provider/provider.dart';

class DashBoard extends StatelessWidget {
  const DashBoard({super.key});

  void _showImageDialog(BuildContext context, String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No image available')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.8,
                    height: MediaQuery.of(context).size.height * 0.6,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AdminController(),
      child: Consumer<AdminController>(
        builder: (context, controller, child) {
          final themeProvider = Provider.of<ThemeProvider>(context);

          return Scaffold(
            appBar: AppBar(
              actions: [
                IconButton(
                  icon: Icon(themeProvider.isDarkMode
                      ? Icons.wb_sunny
                      : Icons.nightlight_round),
                  onPressed: themeProvider.toggleTheme,
                ),
              ],
              centerTitle: true,
              backgroundColor: Colors.blue,
              title: const Text(
                "Admin Dashboard",
                style: TextStyle(color: Colors.white),
              ),
            ),
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      elevation: 5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                GestureDetector(
                                  onTap: controller.toggleUsersCount,
                                  child: const Icon(Icons.person,
                                      size: 40, color: Colors.blue),
                                ),
                                const SizedBox(height: 5),
                                const Text("Users",
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                                if (controller.showUsersCount)
                                  Text("${controller.userCount}",
                                      style: const TextStyle(
                                          fontSize: 20, color: Colors.black)),
                              ],
                            ),
                            Column(
                              children: [
                                GestureDetector(
                                  onTap: controller.toggleTherapistCount,
                                  child: const Icon(Icons.medical_services,
                                      size: 40, color: Colors.green),
                                ),
                                const SizedBox(height: 5),
                                const Text("Therapists",
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                                if (controller.showTherapistCount)
                                  Text("${controller.therapistCount}",
                                      style: const TextStyle(
                                          fontSize: 20, color: Colors.black)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Center(
                      child: Text(
                        'Therapist Requests',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: controller.therapists.isNotEmpty
                          ? DataTable(
                              columns: const [
                                DataColumn(label: Text('Name')),
                                DataColumn(label: Text('Email')),
                                DataColumn(label: Text('National ID')),
                                DataColumn(label: Text('Bio')),
                                DataColumn(label: Text('Phone Number')),
                                DataColumn(label: Text('Therapist Image')),
                                DataColumn(label: Text('National Proof')),
                                DataColumn(label: Text('Actions')),
                              ],
                              rows: controller.therapists
                                  .skip((controller.currentPage - 1) *
                                      controller.itemsPerPage)
                                  .take(controller.itemsPerPage)
                                  .map((therapist) => DataRow(cells: [
                                        DataCell(Text(therapist['username'])),
                                        DataCell(Text(therapist['email'])),
                                        DataCell(Text(therapist['nationalid'])),
                                        DataCell(
                                            Text(therapist['bio'] ?? 'N/A')),
                                        DataCell(Text(
                                            therapist['therapistPhoneNumber'] ??
                                                'N/A')),
                                        DataCell(
                                          IconButton(
                                            icon: const Icon(Icons.image,
                                                color: Colors.green),
                                            onPressed: () {
                                              _showImageDialog(context,
                                                  therapist['therapistImage']);
                                            },
                                          ),
                                        ),
                                        DataCell(
                                          IconButton(
                                            icon: const Icon(Icons.image,
                                                color: Colors.blue),
                                            onPressed: () {
                                              _showImageDialog(context,
                                                  therapist['nationalProof']);
                                            },
                                          ),
                                        ),
                                        DataCell(Row(
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.check,
                                                  color: Colors.green),
                                              onPressed: () =>
                                                  controller.approveTherapist(
                                                      context,
                                                      therapist['userid']),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.close,
                                                  color: Colors.red),
                                              onPressed: () =>
                                                  controller.rejectTherapist(
                                                      context,
                                                      therapist['userid'],
                                                      therapist['email']),
                                            ),
                                          ],
                                        )),
                                      ]))
                                  .toList(),
                            )
                          : const Center(
                              child: Text('No therapist requests available'),
                            ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: controller.previousPage,
                          child: const Text(
                            'Previous',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                        Text(
                          '${controller.currentPage} of ${controller.totalPages > 0 ? controller.totalPages : 1}',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        TextButton(
                          onPressed: controller.nextPage,
                          child: const Text(
                            'Next',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            bottomNavigationBar:
                const CustomBottomNavigationBar(currentIndex: 0),
          );
        },
      ),
    );
  }
}
