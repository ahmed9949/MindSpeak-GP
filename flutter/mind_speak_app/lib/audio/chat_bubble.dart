import 'package:flutter/material.dart';
import 'package:mind_speak_app/models/message.dart';
  
class ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment:
            message.isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: message.isUser
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context).colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            message.text,
            style: TextStyle(
              color: message.isUser
                  ? Theme.of(context).colorScheme.onPrimaryContainer
                  : Theme.of(context).colorScheme.onSecondaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}
