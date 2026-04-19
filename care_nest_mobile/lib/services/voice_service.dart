import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';

class VoiceService {
  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;
  VoiceService._internal();

  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  
  bool _isSpeechInitialized = false;
  bool _isSpeaking = false;
  final Set<String> _spokenItems = {};
  final List<String> _speechQueue = [];

  Future<void> init() async {
    await Permission.microphone.request();
    _isSpeechInitialized = await _speech.initialize();
    
    // Configure TTS for high-quality clinical speech
    await _tts.setSpeechRate(0.5); // Clear, deliberate speed for triage
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    // Completion Handler: Triggers the next item in the queue when speech ends
    _tts.setCompletionHandler(() {
      _isSpeaking = false;
      _pumpQueue();
    });

    _tts.setErrorHandler((msg) {
      _isSpeaking = false;
      _pumpQueue();
    });
  }

  /// Detects the script of the text and returns the appropriate locale ID.
  String getLocaleForText(String text) {
    if (text.isEmpty) return 'en-IN';
    if (RegExp(r'[\u0C00-\u0C7F]').hasMatch(text)) return 'te-IN';
    if (RegExp(r'[\u0900-\u097F]').hasMatch(text)) return 'hi-IN';
    return 'en-IN';
  }

  /// Starts listening for clinical observations.
  Future<void> startListening({
    required Function(String) onResult,
    required String localeId,
  }) async {
    if (!_isSpeechInitialized) return;
    await _speech.listen(
      onResult: (result) => onResult(result.recognizedWords),
      localeId: localeId,
      cancelOnError: true,
      partialResults: true,
      listenMode: ListenMode.deviceDefault,
    );
  }

  Future<void> stopListening() async {
    await _speech.stop();
  }

  /// Extracts fully formed checklist items and adds them to the speech queue.
  /// Uses a newline anchor to ensure we don't speak partial sentences.
  Future<void> processStreamingText(String text, {bool isFinal = false}) async {
    final locale = getLocaleForText(text);
    await _tts.setLanguage(locale.split('-')[0]);

    // Regex now REQUIRES a newline at the end unless isFinal is true
    // This prevents "call", "call emergency", "call emergency services" stutters
    final regex = isFinal 
        ? RegExp(r'- \[[x ]\] (.*?)(?=\n|$)')
        : RegExp(r'- \[[x ]\] (.*?)\n');
        
    final matches = regex.allMatches(text);

    for (final match in matches) {
      final itemText = match.group(1)?.trim();
      if (itemText != null && itemText.isNotEmpty && !_spokenItems.contains(itemText)) {
        _spokenItems.add(itemText);
        _speechQueue.add(itemText);
        _pumpQueue();
      }
    }
  }

  /// Sequential consumer: speaks the next available item in the queue.
  void _pumpQueue() {
    if (_isSpeaking || _speechQueue.isEmpty) return;

    _isSpeaking = true;
    final String nextItem = _speechQueue.removeAt(0);
    _tts.speak(nextItem);
  }

  /// Clears the turn state.
  void resetTurn() {
    _spokenItems.clear();
    _speechQueue.clear();
    _isSpeaking = false;
    _tts.stop();
  }
  
  void stopSpeaking() {
    _speechQueue.clear();
    _isSpeaking = false;
    _tts.stop();
  }
}
