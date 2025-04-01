import 'package:flutter/material.dart';
import 'package:mind_speak_app/controllers/SearchController.dart';
import 'package:mind_speak_app/models/Therapist.dart';
import 'package:mind_speak_app/models/User.dart';
import 'package:mind_speak_app/providers/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:mind_speak_app/providers/session_provider.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late SearchPageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SearchPageController();
    _controller.init();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showTherapistDetails(TherapistModel therapist) {
    // Get associated user information
    UserModel? userInfo =
        _controller.getUserForTherapist(therapist.therapistId);

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
                  if (therapist.therapistImage.isNotEmpty)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        double imageHeight = constraints.maxWidth * 0.6;
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            therapist.therapistImage,
                            height: imageHeight,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: imageHeight,
                                width: double.infinity,
                                color: Colors.grey[300],
                                child: const Icon(Icons.person,
                                    size: 100, color: Colors.grey),
                              );
                            },
                          ),
                        );
                      },
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
                  Text(
                    userInfo?.username ?? 'Unknown',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.email, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          userInfo?.email ?? 'N/A',
                          style: const TextStyle(fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (userInfo != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Row(
                        children: [
                          const Icon(Icons.phone, color: Colors.green),
                          const SizedBox(width: 8),
                          Text(
                            userInfo.phoneNumber.toString(),
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    therapist.bio,
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      final sessionProvider =
                          Provider.of<SessionProvider>(context, listen: false);
                      final result = await _controller.assignTherapistToChild(
                        therapist.therapistId,
                        sessionProvider.userId,
                      );
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(result)),
                      );
                      Navigator.pop(context);
                    },
                    child: const Text('Assign'),
                  ),
                  const SizedBox(height: 8),
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
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Search Therapists',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor:
            themeProvider.isDarkMode ? Colors.grey[900] : Colors.blue,
      ),
      body: SafeArea(
        child: ValueListenableBuilder<bool>(
          valueListenable: _controller.loadingNotifier,
          builder: (context, isLoading, _) {
            if (isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    onChanged: _controller.searchTherapists,
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
                  child: ValueListenableBuilder<List<TherapistModel>>(
                    valueListenable: _controller.filteredTherapistsNotifier,
                    builder: (context, filteredTherapists, _) {
                      return filteredTherapists.isNotEmpty
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
                                // Get user information for this therapist
                                final userInfo = _controller
                                    .getUserForTherapist(therapist.therapistId);

                                return GestureDetector(
                                  onTap: () => _showTherapistDetails(therapist),
                                  child: Card(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    elevation: 4,
                                    child: Column(
                                      children: [
                                        if (therapist.therapistImage.isNotEmpty)
                                          LayoutBuilder(
                                            builder: (context, constraints) {
                                              double imageHeight =
                                                  constraints.maxWidth * 0.75;
                                              return ClipRRect(
                                                borderRadius:
                                                    const BorderRadius.vertical(
                                                  top: Radius.circular(15),
                                                ),
                                                child: Image.network(
                                                  therapist.therapistImage,
                                                  height: imageHeight,
                                                  width: double.infinity,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error,
                                                      stackTrace) {
                                                    return Container(
                                                      height: imageHeight,
                                                      width: double.infinity,
                                                      color: Colors.grey[300],
                                                      child: const Icon(
                                                          Icons.person,
                                                          size: 60,
                                                          color: Colors.grey),
                                                    );
                                                  },
                                                ),
                                              );
                                            },
                                          )
                                        else
                                          Container(
                                            height: 120,
                                            width: double.infinity,
                                            color: Colors.grey[300],
                                            child: const Icon(Icons.person,
                                                size: 60, color: Colors.grey),
                                          ),
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text(
                                            userInfo?.username ?? 'Unknown',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            textAlign: TextAlign.center,
                                            overflow: TextOverflow.ellipsis,
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
                            );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
