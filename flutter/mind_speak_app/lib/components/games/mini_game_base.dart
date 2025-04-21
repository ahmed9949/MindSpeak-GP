import 'package:flutter/material.dart';
import 'package:mind_speak_app/service/avatarservice/chatgptttsservice.dart';

/// Base class for all mini-games
/// This provides a common interface for the game manager to interact with various game types
abstract class MiniGameBase extends StatefulWidget {
  final ChatGptTtsService ttsService;
  final Function(int) onCorrect;
  final Function() onWrong;

  const MiniGameBase({
    super.key,
    required this.ttsService,
    required this.onCorrect,
    required this.onWrong,
  });
}
