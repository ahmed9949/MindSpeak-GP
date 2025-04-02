import 'package:flutter/material.dart';
import 'package:mind_speak_app/controllers/progresscontroller.dart';
import 'package:mind_speak_app/models/progressquestion.dart';
import 'package:provider/provider.dart';

class DashboardView extends StatelessWidget {
  final TextEditingController _questionController = TextEditingController();
  final List<String> _difficultyLevels = ['low', 'mid', 'high'];

  DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context); // Navigate back to the previous page
          },
        ),
        title: const Text('Progress Questions'),
        centerTitle: true,
      ),
      body: Consumer<ProgressController>(
        builder: (context, controller, child) {
          if (controller.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (controller.progressList.isEmpty) {
            return const Center(child: Text('No progress questions available'));
          }
          return ListView.builder(
            itemCount: controller.progressList.length,
            itemBuilder: (context, index) {
              final progress = controller.progressList[index];
              return ListTile(
                title: Text(progress.question),
                subtitle: Text('Difficulty: ${progress.difficulty}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showEditDialog(context, progress),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => controller.deleteProgress(progress.id),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    String selectedDifficulty = _difficultyLevels[0];
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add Progress'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _questionController,
                    decoration: const InputDecoration(labelText: 'Question'),
                  ),
                  DropdownButton<String>(
                    value: selectedDifficulty,
                    items: _difficultyLevels
                        .map((level) => DropdownMenuItem(
                              value: level,
                              child: Text(level),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedDifficulty = value!;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    context.read<ProgressController>().addProgress(
                          _questionController.text,
                          selectedDifficulty,
                        );
                    _questionController.clear();
                    Navigator.pop(context);
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditDialog(BuildContext context, ProgressModel progress) {
    _questionController.text = progress.question;
    String selectedDifficulty = progress.difficulty;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Edit Progress'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _questionController,
                    decoration: const InputDecoration(labelText: 'Question'),
                  ),
                  DropdownButton<String>(
                    value: selectedDifficulty,
                    items: _difficultyLevels
                        .map((level) => DropdownMenuItem(
                              value: level,
                              child: Text(level),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedDifficulty = value!;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    final updatedProgress = ProgressModel(
                      id: progress.id,
                      question: _questionController.text,
                      difficulty: selectedDifficulty,
                    );
                    context
                        .read<ProgressController>()
                        .updateProgress(updatedProgress);
                    _questionController.clear();
                    Navigator.pop(context);
                  },
                  child: const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
