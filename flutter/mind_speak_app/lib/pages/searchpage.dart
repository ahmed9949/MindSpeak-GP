import 'package:flutter/material.dart';
import 'package:mind_speak_app/controllers/SearchController.dart';
import 'package:mind_speak_app/models/Therapist.dart';
import 'package:mind_speak_app/models/User.dart';
import 'package:mind_speak_app/providers/color_provider.dart';
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

 void _showTherapistDetails(TherapistModel therapist) async {
  final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
  final colorProvider = Provider.of<ColorProvider>(context, listen: false);

  UserModel? userInfo =
      _controller.getUserForTherapist(therapist.therapistId);

  userInfo ??= await _controller.fetchUserForTherapist(therapist.therapistId);

  if (!mounted) return;

  print('Showing details for therapist: ${therapist.therapistId}');
  print('User info available: ${userInfo != null}');
  if (userInfo != null) {
    print('Username: ${userInfo.username}');
    print('Email: ${userInfo.email}');
  }

  showDialog(
    context: context,
    builder: (context) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: themeProvider.isDarkMode
    ? [Colors.grey[900]!, Colors.black]
    : [
        colorProvider.primaryColor,
        colorProvider.primaryColor.withAlpha(230), // 0.9 * 255 = 229.5 ≈ 230
      ],

              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: SingleChildScrollView(
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
                    child: const Icon(Icons.person, size: 100, color: Colors.grey),
                  ),
                const SizedBox(height: 16),
                Text(
                  userInfo?.username ?? 'Unknown',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.email, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        userInfo?.email ?? 'N/A',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                        ),
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
                        const Icon(Icons.phone, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          userInfo.phoneNumber.toString(),
                          style: const TextStyle(fontSize: 16, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  therapist.bio,
                  style: const TextStyle(fontSize: 16, color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: colorProvider.primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: colorProvider.primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
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
    final isDark = themeProvider.isDarkMode;
    final colorProvider = Provider.of<ColorProvider>(context);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: themeProvider.isDarkMode
    ? [Colors.grey[900]!, Colors.black]
    : [
        colorProvider.primaryColor,
        colorProvider.primaryColor.withAlpha(230), // Equivalent to 0.9 opacity
      ],

              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(20),
            ),
          ),
        ),
        title: const Text(
          'Search Therapists',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
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
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[850] : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: isDark
    ? Colors.black45
    : Colors.grey.withAlpha(51),

                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: TextField(
                      onChanged: _controller.searchTherapists,
                      style: TextStyle(
                          color: isDark ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        hintText: 'Search therapist by name',
                        hintStyle: TextStyle(
                            color: isDark ? Colors.grey[400] : Colors.grey),
                        prefixIcon: Icon(Icons.search,
                            color: isDark ? Colors.white : Colors.grey),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ValueListenableBuilder<List<TherapistModel>>(
                    valueListenable: _controller.filteredTherapistsNotifier,
                    builder: (context, filteredTherapists, _) {
                      if (filteredTherapists.isEmpty) {
                        return const Center(
                          child: Text(
                            'No therapists found.',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        );
                      }

                      return GridView.builder(
                        padding: const EdgeInsets.all(16.0),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.75,
                        ),
                        itemCount: filteredTherapists.length,
                        itemBuilder: (context, index) {
                          final therapist = filteredTherapists[index];
                          final userInfo = _controller
                              .getUserForTherapist(therapist.therapistId);

                          return GestureDetector(
                            onTap: () => _showTherapistDetails(therapist),
                            child: Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              color: isDark ? Colors.grey[850] : Colors.white,
                              elevation: 5,
                              shadowColor: Colors.black26,
                              child: Column(
                                children: [
                                  if (therapist.therapistImage.isNotEmpty)
                                    ClipRRect(
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(15),
                                      ),
                                      child: Image.network(
                                        therapist.therapistImage,
                                        height: 120,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return Container(
                                            height: 120,
                                            color: Colors.grey[300],
                                            child: const Icon(Icons.person,
                                                size: 60, color: Colors.grey),
                                          );
                                        },
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
                                  const SizedBox(height: 10),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8.0),
                                    child: Text(
                                      userInfo?.username ?? 'Unknown',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8.0),
                                    child: Text(
                                      therapist.bio.isNotEmpty
                                          ? therapist.bio
                                          : 'No bio available',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark
                                            ? Colors.grey[300]
                                            : Colors.grey[700],
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
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
