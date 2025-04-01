import 'package:flutter/material.dart';
import 'package:mind_speak_app/Repositories/AdminRepository.dart';
import 'package:mind_speak_app/components/CustomBottomNavigationBar.dart';
import 'package:mind_speak_app/controllers/AdminController.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class AdminDashboardView extends StatelessWidget {
  const AdminDashboardView({super.key});

  void _showImageDialog(BuildContext context, String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No image available')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: _ImageDialogContent(imageUrl: imageUrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AdminController(
        repository: AdminRepository(),
      ),
      child: Consumer<AdminController>(
        builder: (context, controller, _) {
          return Scaffold(
            appBar: _buildAppBar(context),
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatisticsCard(controller),
                    const SizedBox(height: 20),
                    _buildTherapistRequestsSection(context, controller),
                    const SizedBox(height: 20),
                    _buildPaginationControls(controller),
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

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return AppBar(
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
    );
  }

  Widget _buildStatisticsCard(AdminController controller) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(25),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(
              icon: Icons.person,
              title: 'Users',
              count: controller.state.userCount,
              showCount: controller.state.showUsersCount,
              onTap: controller.toggleUsersCount,
              iconColor: Colors.blue,
            ),
            _buildStatItem(
              icon: Icons.medical_services,
              title: 'Therapists',
              count: controller.state.therapistCount,
              showCount: controller.state.showTherapistCount,
              onTap: controller.toggleTherapistCount,
              iconColor: Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String title,
    required int count,
    required bool showCount,
    required VoidCallback onTap,
    required Color iconColor,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Icon(icon, size: 40, color: iconColor),
        ),
        const SizedBox(height: 5),
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        if (showCount)
          Text(
            count.toString(),
            style: const TextStyle(fontSize: 20, color: Colors.black),
          ),
      ],
    );
  }

  Widget _buildTherapistRequestsSection(
    BuildContext context,
    AdminController controller,
  ) {
    return Column(
      children: [
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
          child: _buildTherapistTable(context, controller),
        ),
      ],
    );
  }

  Widget _buildTherapistTable(
    BuildContext context,
    AdminController controller,
  ) {
    if (controller.state.therapistData.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Text('No therapist requests available'),
        ),
      );
    }

    return DataTable(
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
      rows: _buildTherapistRows(context, controller),
    );
  }

  List<DataRow> _buildTherapistRows(
    BuildContext context,
    AdminController controller,
  ) {
    final startIndex =
        (controller.state.currentPage - 1) * AdminController.itemsPerPage;
    final endIndex = startIndex + AdminController.itemsPerPage;

    // Get the items for the current page
    final pageData = controller.state.therapistData
        .skip(startIndex)
        .take(AdminController.itemsPerPage)
        .toList();

    return pageData.map((data) {
      return DataRow(cells: [
        DataCell(Text(data['username'] ?? 'N/A')),
        DataCell(Text(data['email'] ?? 'N/A')),
        DataCell(Text(data['nationalId'] ?? 'N/A')),
        DataCell(Text(data['bio'] ?? 'N/A')),
        DataCell(Text(data['therapistPhoneNumber']?.toString() ?? 'N/A')),
        DataCell(_buildImageButton(
          context,
          data['therapistImage'],
          Colors.green,
        )),
        DataCell(_buildImageButton(
          context,
          data['nationalProof'],
          Colors.blue,
        )),
        DataCell(_buildActionButtons(
          context,
          controller,
          data['therapistId'],
          data['email'],
        )),
      ]);
    }).toList();
  }

  Widget _buildImageButton(
    BuildContext context,
    String imageUrl,
    Color color,
  ) {
    return IconButton(
      icon: Icon(Icons.image, color: color),
      onPressed: () => _showImageDialog(context, imageUrl),
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    AdminController controller,
    String therapistId,
    String email,
  ) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.check, color: Colors.green),
          onPressed: () => controller.approveTherapist(
            context,
            therapistId,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, color: Colors.red),
          onPressed: () => controller.rejectTherapist(
            context,
            therapistId,
            email,
          ),
        ),
      ],
    );
  }

  Widget _buildPaginationControls(AdminController controller) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton(
          onPressed: controller.previousPage,
          child: const Text('Previous', style: TextStyle(fontSize: 16)),
        ),
        Text(
          '${controller.state.currentPage} of ${controller.state.totalPages > 0 ? controller.state.totalPages : 1}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        TextButton(
          onPressed: controller.nextPage,
          child: const Text('Next', style: TextStyle(fontSize: 16)),
        ),
      ],
    );
  }
}

class _ImageDialogContent extends StatelessWidget {
  final String imageUrl;

  const _ImageDialogContent({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
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
    );
  }
}
