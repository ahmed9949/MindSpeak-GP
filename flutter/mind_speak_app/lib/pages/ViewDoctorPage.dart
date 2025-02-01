import 'package:flutter/material.dart';
import 'package:mind_speak_app/controllers/View_Doctor_Controller.dart';
import 'package:mind_speak_app/providers/theme_provider.dart';
import 'package:mind_speak_app/components/CustomBottomNavigationBar.dart';

import 'package:provider/provider.dart';

class ViewDoctors extends StatefulWidget {
  const ViewDoctors({super.key});

  @override
  State<ViewDoctors> createState() => _ViewDoctorsState();
}

class _ViewDoctorsState extends State<ViewDoctors> {
  final ViewDoctorsController _controller = ViewDoctorsController();

  @override
  void initState() {
    super.initState();
    _controller.fetchApprovedTherapists(() {
      setState(() {});
    });
  }

  void _showImageDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              imageUrl.isNotEmpty
                  ? Image.network(imageUrl)
                  : const Center(
                      child: Text('No image available'),
                    ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      },
    );
  }

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
            onPressed: themeProvider.toggleTheme,
          ),
        ],
        centerTitle: true,
        backgroundColor:
            themeProvider.isDarkMode ? Colors.black : Colors.lightBlue,
        title: const Text(
          "View Therapists",
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: _controller.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  TextField(
                    onChanged: (value) =>
                        _controller.searchTherapists(value, () {
                      setState(() {});
                    }),
                    decoration: const InputDecoration(
                      labelText: 'Search',
                      suffixIcon: Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _controller.filteredTherapists.isNotEmpty
                      ? ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _controller.filteredTherapists.length,
                          itemBuilder: (context, index) {
                            final therapist =
                                _controller.filteredTherapists[index];
                            return Card(
                              key: ValueKey(therapist["id"]),
                              color: Colors.blue,
                              elevation: 4,
                              margin: const EdgeInsets.symmetric(vertical: 10),
                              child: ListTile(
                                leading: CircleAvatar(
                                  radius: 30,
                                  backgroundImage:
                                      therapist['therapistImage'].isNotEmpty
                                          ? NetworkImage(
                                              therapist['therapistImage'])
                                          : null,
                                  child: therapist['therapistImage'].isEmpty
                                      ? const Icon(Icons.person,
                                          size: 30, color: Colors.white)
                                      : null,
                                ),
                                title: Text(
                                  therapist['name'],
                                  style: const TextStyle(color: Colors.white),
                                ),
                                subtitle: Text(
                                  'Email: ${therapist['email']}',
                                  style: const TextStyle(color: Colors.white),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.image,
                                      color: Colors.blue),
                                  onPressed: () {
                                    _showImageDialog(
                                        context, therapist['nationalProof']);
                                  },
                                ),
                              ),
                            );
                          },
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
      bottomNavigationBar: const CustomBottomNavigationBar(currentIndex: 1),
    );
  }
}
