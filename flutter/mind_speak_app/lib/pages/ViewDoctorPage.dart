import 'package:flutter/material.dart';
import 'package:mind_speak_app/providers/theme_provider.dart';
import 'package:mind_speak_app/components/CustomBottomNavigationBar.dart';
import 'package:mind_speak_app/service/DoctorRepository.dart';
import 'package:provider/provider.dart';

class ViewDoctors extends StatefulWidget {
  const ViewDoctors({super.key});

  @override
  State<ViewDoctors> createState() => _ViewDoctorsState();
}

class _ViewDoctorsState extends State<ViewDoctors> {
  final DoctorRepository _doctorRepository = DoctorRepository();
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
      List<Map<String, dynamic>> therapists =
          await _doctorRepository.fetchApprovedTherapists();
      setState(() {
        _allTherapist = therapists;
        _foundTherapist = therapists;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching therapists: $e');
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
            onPressed: () {
              themeProvider.toggleTheme(); // Toggle theme
            },
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
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
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _foundTherapist.length,
                          itemBuilder: (context, index) => Card(
                            key: ValueKey(_foundTherapist[index]["id"]),
                            color: Colors.blue,
                            elevation: 4,
                            margin: const EdgeInsets.symmetric(vertical: 10),
                            child: ListTile(
                              leading: CircleAvatar(
                                radius: 30, // Adjust the radius as needed
                                backgroundImage: _foundTherapist[index]
                                                ['therapistImage'] !=
                                            null &&
                                        _foundTherapist[index]['therapistImage']
                                            .isNotEmpty
                                    ? NetworkImage(_foundTherapist[index]
                                        ['therapistImage'])
                                    : null,
                                child: _foundTherapist[index]
                                                ['therapistImage'] ==
                                            null ||
                                        _foundTherapist[index]['therapistImage']
                                            .isEmpty
                                    ? const Icon(Icons.person,
                                        size: 30, color: Colors.white)
                                    : null,
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
                                  Text(
                                    'Bio: ${_foundTherapist[index]['bio'] ?? 'N/A'}',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  Text(
                                    'Phone: ${_foundTherapist[index]['therapistPhoneNumber'] ?? 'N/A'}',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.image,
                                        color: Colors.green),
                                    onPressed: () {
                                      _showImageDialog(
                                          context,
                                          _foundTherapist[index]
                                              ['nationalProof']);
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.image,
                                        color: Colors.blue),
                                    onPressed: () {
                                      _showImageDialog(
                                          context,
                                          _foundTherapist[index]
                                              ['nationalProof']);
                                    },
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
      bottomNavigationBar: const CustomBottomNavigationBar(currentIndex: 1),
    );
  }
}
