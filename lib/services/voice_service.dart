import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter/foundation.dart';

class VoiceService {
  static final stt.SpeechToText _speech = stt.SpeechToText();
  static bool _isInitialized = false;
  static bool _isAvailable = false;

  static Future<bool> initialize() async {
    if (_isInitialized) return _isAvailable;
    
    _isAvailable = await _speech.initialize(
      onError: (error) {
        debugPrint('Speech recognition error: $error');
      },
      onStatus: (status) {
        debugPrint('Speech recognition status: $status');
      },
    );
    
    _isInitialized = true;
    return _isAvailable;
  }

  static bool get isAvailable => _isAvailable && _isInitialized;

  static Future<String?> listen({
    required Function(String) onResult,
    Function(String)? onPartialResult,
    Function()? onDone,
    Function(String)? onError,
  }) async {
    if (!_isAvailable) {
      await initialize();
      if (!_isAvailable) {
        onError?.call('Speech recognition not available');
        return null;
      }
    }

    String? finalResult;

    await _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          finalResult = result.recognizedWords;
          onResult(result.recognizedWords);
          _speech.stop();
        } else {
          onPartialResult?.call(result.recognizedWords);
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
      localeId: 'en_US',
      onSoundLevelChange: null,
      listenMode: stt.ListenMode.confirmation,
    );

    return finalResult;
  }

  static Future<void> stop() async {
    if (_speech.isListening) {
      await _speech.stop();
    }
  }

  static bool get isListening => _speech.isListening;

  static Future<void> cancel() async {
    if (_speech.isListening) {
      await _speech.cancel();
    }
  }
}
