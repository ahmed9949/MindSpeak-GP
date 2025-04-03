import 'package:flutter/material.dart';
import 'package:mind_speak_app/models/Therapist.dart';
import 'package:provider/provider.dart';
import 'package:mind_speak_app/controllers/ViewTherapistController.dart';
import 'package:mind_speak_app/providers/theme_provider.dart';
import 'package:mind_speak_app/components/CustomBottomNavigationBar.dart';

class ViewTherapist extends StatefulWidget {
  const ViewTherapist({super.key});

  @override
  State<ViewTherapist> createState() => _ViewTherapistState();
}

class _ViewTherapistState extends State<ViewTherapist> {
  late final ViewTherapistController _controller = ViewTherapistController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();

    _loadTherapists();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTherapists() async {
    await _controller.fetchApprovedTherapists(() {
      if (mounted) setState(() {});
    });
  }

  Widget _buildTherapistCard(Map<String, dynamic> therapistData, int index) {
    TherapistModel? therapist = _controller.getTherapist(index);

    return Card(
      key: ValueKey(therapist?.therapistId ?? 'unknown-$index'),
      color: Colors.blue,
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: ListTile(
        leading: _buildTherapistAvatar(_controller.getTherapistImage(index)),
        title: Text(
          _controller.getTherapistName(index),
          style: const TextStyle(color: Colors.white),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Email: ${_controller.getTherapistEmail(index)}',
              style: const TextStyle(color: Colors.white),
            ),
            Text(
              'Phone: ${_controller.getTherapistPhoneNumber(index)}',
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.image, color: Colors.white),
          onPressed: () {
            if (therapist != null) {
              _showImageDialog(context, therapist.nationalProof);
            }
          },
        ),
        isThreeLine: true,
        onTap: () => _showTherapistDetails(index),
      ),
    );
  }

  Widget _buildTherapistAvatar(String imageUrl) {
    return CircleAvatar(
      radius: 30,
      backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
      child: imageUrl.isEmpty
          ? const Icon(Icons.person, size: 30, color: Colors.white)
          : null,
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: (value) => _controller.searchTherapists(value, () {
        setState(() {});
      }),
      decoration: InputDecoration(
        labelText: 'Search',
        suffixIcon: const Icon(Icons.search),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _showImageDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (imageUrl.isNotEmpty)
              Image.network(
                imageUrl,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const CircularProgressIndicator();
                },
                errorBuilder: (context, error, stackTrace) =>
                    const Text('Error loading image'),
              )
            else
              const Text('No image available'),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  void _showTherapistDetails(int index) {
    final therapist = _controller.getTherapist(index);
    final user = _controller.getUser(index);

    if (therapist != null) {
      showModalBottomSheet(
        context: context,
        builder: (context) => Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Therapist Details',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('Name: ${user?.username ?? 'Unknown'}'),
              Text('Email: ${user?.email ?? 'N/A'}'),
              Text('Phone: ${user?.phoneNumber.toString() ?? 'N/A'}'),
              Text('Bio: ${therapist.bio}'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: Icon(
              themeProvider.isDarkMode
                  ? Icons.wb_sunny
                  : Icons.nightlight_round,
            ),
            onPressed: themeProvider.toggleTheme,
          ),
        ],
        centerTitle: true,
        backgroundColor:
            themeProvider.isDarkMode ? Colors.black : Colors.lightBlue,
        title: const Text("View Therapists",
            style: TextStyle(color: Colors.white)),
      ),
      body: RefreshIndicator(
        onRefresh: _loadTherapists,
        child: _controller.isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    _buildSearchField(),
                    const SizedBox(height: 20),
                    if (_controller.filteredTherapistData.isNotEmpty)
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _controller.filteredTherapistData.length,
                        itemBuilder: (context, index) => _buildTherapistCard(
                            _controller.filteredTherapistData[index], index),
                      )
                    else
                      const Center(
                        child: Text(
                          'No approved therapists found.',
                          style: TextStyle(fontSize: 20),
                        ),
                      ),
                  ],
                ),
              ),
      ),
      bottomNavigationBar: const CustomBottomNavigationBar(currentIndex: 1),
    );
  }
}
