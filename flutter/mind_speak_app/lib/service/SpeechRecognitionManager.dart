import 'package:speech_to_text/speech_to_text.dart' as stt;

class SpeechRecognitionManager {
  static final SpeechRecognitionManager _instance =
      SpeechRecognitionManager._internal();
  factory SpeechRecognitionManager() => _instance;
  SpeechRecognitionManager._internal();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;
  String _currentMode = 'session'; // 'session', 'game', or 'none'

  Future<void> initialize() async {
    if (!_isInitialized) {
      _isInitialized = await _speech.initialize(
        onStatus: _handleSpeechStatus,
        onError: _handleSpeechError,
      );
    }
  }

  void _handleSpeechStatus(String status) {
    if (status == 'notListening' || status == 'done') {
      _isListening = false;
      // Notify listeners that speech recognition has stopped
      _notifyListeners(SpeechEvent(
        type: SpeechEventType.stopped,
        mode: _currentMode,
      ));
    }
  }

  void _handleSpeechError(dynamic error) {
    _isListening = false;
    // Notify listeners about error
    _notifyListeners(SpeechEvent(
      type: SpeechEventType.error,
      mode: _currentMode,
      error: error.toString(),
    ));
  }

  Future<bool> startListening({
    required String mode,
    required Function(String) onResult,
    String localeId = 'ar-EG',
  }) async {
    if (_isListening) {
      // Already listening - must stop first
      await stopListening();
    }

    if (!_isInitialized) {
      await initialize();
    }

    _currentMode = mode;
    _isListening = await _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          onResult(result.recognizedWords);
        }
      },
      listenMode: stt.ListenMode.dictation,
      localeId: localeId,
    );

    // Notify listeners that listening started in specific mode
    _notifyListeners(SpeechEvent(
      type: SpeechEventType.started,
      mode: mode,
    ));

    return _isListening;
  }

  Future<void> stopListening() async {
    if (_isListening) {
      await _speech.stop();
      _isListening = false;
    }
  }

  bool get isListening => _isListening;
  String get currentMode => _currentMode;

  // Event notification system
  final List<Function(SpeechEvent)> _listeners = [];

  void addListener(Function(SpeechEvent) listener) {
    _listeners.add(listener);
  }

  void removeListener(Function(SpeechEvent) listener) {
    _listeners.remove(listener);
  }

  void _notifyListeners(SpeechEvent event) {
    for (final listener in _listeners) {
      listener(event);
    }
  }
}

// Event classes for speech recognition
enum SpeechEventType { started, stopped, error }

class SpeechEvent {
  final SpeechEventType type;
  final String mode;
  final String? error;

  SpeechEvent({required this.type, required this.mode, this.error});
}
