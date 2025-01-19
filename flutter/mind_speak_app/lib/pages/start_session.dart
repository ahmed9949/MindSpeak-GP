import 'package:flutter/material.dart';
import 'package:mind_speak_app/audio/chat_bubble.dart';
import 'package:mind_speak_app/providers/chatprovider.dart';
import 'package:provider/provider.dart';
import 'package:rive/rive.dart';

class start_session extends StatefulWidget {
  const start_session({super.key});

  @override
  State<start_session> createState() => _StartSessionState();
}

class _StartSessionState extends State<start_session> {
  late OneShotAnimation _talkController;
  late OneShotAnimation _hearController;
  late OneShotAnimation _stopHearController;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupTTSListener();
    });
  }

  void _initializeAnimations() {
    _talkController = OneShotAnimation('Talk', autoplay: false);
    _hearController = OneShotAnimation('hands_hear_start', autoplay: false);
    _stopHearController = OneShotAnimation('hands_hear_stop', autoplay: false);
  }

  void _setupTTSListener() {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    chatProvider.ttsService.isSpeakingStream.listen((isSpeaking) {
      if (!mounted) return;

      if (isSpeaking) {
        _triggerAction(_talkController);
      } else if (chatProvider.isInSession && !chatProvider.isProcessingResponse) {
        _triggerAction(_hearController);
      } else {
        _triggerAction(_stopHearController);
      }
    });

    // Add listener for listening state changes
    chatProvider.addListener(() {
      if (!mounted) return;
      
      if (chatProvider.isListening && !chatProvider.isSpeaking) {
        _triggerAction(_hearController);
      } else if (!chatProvider.isListening && !chatProvider.isSpeaking && !chatProvider.isInSession) {
        _triggerAction(_stopHearController);
      }
    });
  }

  void _triggerAction(OneShotAnimation controller) {
    if (!mounted) return;
    
    setState(() {
      _talkController.isActive = false;
      _hearController.isActive = false;
      _stopHearController.isActive = false;
      controller.isActive = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('AI Voice Assistant'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  chatProvider.chatHistory.clear();
                  chatProvider.endSession();
                  _triggerAction(_stopHearController);
                },
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                flex: 3,
                child: RiveAnimation.asset(
                  'assets/login_screen_character.riv',
                  controllers: [
                    _talkController,
                    _hearController,
                    _stopHearController
                  ],
                  fit: BoxFit.contain,
                ),
              ),
              _buildStatusText(chatProvider),
              _buildChatList(chatProvider),
              _buildControlButtons(chatProvider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusText(ChatProvider chatProvider) {
    String statusText = "Tap to start conversation";
    if (chatProvider.isSpeaking) {
      statusText = "Speaking...";
    } else if (chatProvider.isListening) {
      statusText = "Listening...";
    } else if (chatProvider.isProcessingResponse) {
      statusText = "Processing...";
    }

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Text(
            statusText,
            style: const TextStyle(fontSize: 16.0),
          ),
          if (chatProvider.currentBuffer.isNotEmpty)
            Text(
              'Current: ${chatProvider.currentBuffer}',
              style: const TextStyle(fontSize: 14.0),
            ),
        ],
      ),
    );
  }

  Widget _buildChatList(ChatProvider chatProvider) {
    return Expanded(
      flex: 4,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: ListView.builder(
          controller: _scrollController,
          itemCount: chatProvider.chatHistory.length,
          itemBuilder: (context, index) {
            return ChatBubble(message: chatProvider.chatHistory[index]);
          },
        ),
      ),
    );
  }

  Widget _buildControlButtons(ChatProvider chatProvider) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton.icon(
            onPressed: chatProvider.isInSession
                ? () {
                    chatProvider.endSession();
                    _triggerAction(_stopHearController);
                  }
                : () {
                    chatProvider.startSession();
                    _triggerAction(_hearController);
                  },
            icon: Icon(chatProvider.isInSession ? Icons.call_end : Icons.call),
            label: Text(chatProvider.isInSession ? 'End Call' : 'Start Call'),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  chatProvider.isInSession ? Colors.red : Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}