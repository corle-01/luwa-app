@JS()
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

// ─────────────────────────────────────────────────────────
// JS Interop types for Web Speech API
// ─────────────────────────────────────────────────────────

/// SpeechRecognition API (standard + webkit prefix)
extension type _SpeechRecognition._(JSObject _) implements JSObject {
  external set continuous(JSBoolean value);
  external set interimResults(JSBoolean value);
  external set lang(JSString value);
  external set onresult(JSFunction? value);
  external set onend(JSFunction? value);
  external set onerror(JSFunction? value);
  external set onstart(JSFunction? value);
  external void start();
  external void stop();
  external void abort();
}

/// SpeechRecognitionEvent
extension type _SpeechRecognitionEvent._(JSObject _) implements JSObject {
  external _SpeechRecognitionResultList get results;
}

/// SpeechRecognitionResultList
extension type _SpeechRecognitionResultList._(JSObject _) implements JSObject {
  external int get length;
  external _SpeechRecognitionResult item(int index);
}

/// SpeechRecognitionResult
extension type _SpeechRecognitionResult._(JSObject _) implements JSObject {
  external bool get isFinal;
  external _SpeechRecognitionAlternative item(int index);
}

/// SpeechRecognitionAlternative
extension type _SpeechRecognitionAlternative._(JSObject _) implements JSObject {
  external String get transcript;
}

/// SpeechRecognitionErrorEvent
extension type _SpeechRecognitionErrorEvent._(JSObject _) implements JSObject {
  external String get error;
}

/// SpeechSynthesisUtterance
extension type _SpeechSynthesisUtterance._(JSObject _) implements JSObject {
  external set lang(JSString value);
  external set rate(JSNumber value);
  external set pitch(JSNumber value);
  external set volume(JSNumber value);
}

/// SpeechSynthesis
extension type _SpeechSynthesis._(JSObject _) implements JSObject {
  external void speak(_SpeechSynthesisUtterance utterance);
  external void cancel();
}

// JS global access helpers
@JS('SpeechRecognition')
external JSFunction? get _speechRecognitionCtor;

@JS('webkitSpeechRecognition')
external JSFunction? get _webkitSpeechRecognitionCtor;

@JS('speechSynthesis')
external _SpeechSynthesis? get _speechSynthesis;

@JS('SpeechSynthesisUtterance')
external JSFunction get _speechSynthesisUtteranceCtor;

// ─────────────────────────────────────────────────────────
// Voice Command Service
// ─────────────────────────────────────────────────────────

/// Voice Command Service using Web Speech API
///
/// Provides:
/// - STT (Speech-to-Text): Microphone input → text
/// - TTS (Text-to-Speech): Text → spoken audio output
class VoiceCommandService {
  _SpeechRecognition? _recognition;
  bool _isListening = false;
  final _resultController = StreamController<String>.broadcast();
  final _statusController = StreamController<VoiceStatus>.broadcast();

  /// Stream of recognized speech text.
  Stream<String> get onResult => _resultController.stream;

  /// Stream of voice status changes.
  Stream<VoiceStatus> get onStatus => _statusController.stream;

  /// Whether the service is currently listening.
  bool get isListening => _isListening;

  /// Check if Speech Recognition is supported in this browser.
  static bool get isSupported {
    try {
      return _speechRecognitionCtor != null ||
          _webkitSpeechRecognitionCtor != null;
    } catch (_) {
      return false;
    }
  }

  /// Check if Speech Synthesis (TTS) is supported.
  static bool get isTtsSupported {
    try {
      return _speechSynthesis != null;
    } catch (_) {
      return false;
    }
  }

  /// Initialize the speech recognition engine.
  void initialize() {
    if (_recognition != null) return;

    try {
      JSFunction? ctor;
      try {
        ctor = _speechRecognitionCtor;
      } catch (_) {}
      if (ctor == null) {
        try {
          ctor = _webkitSpeechRecognitionCtor;
        } catch (_) {}
      }

      if (ctor == null) return;

      _recognition =
          ctor.callAsConstructor<_SpeechRecognition>();

      // Configure
      _recognition!.continuous = false.toJS;
      _recognition!.interimResults = true.toJS;
      _recognition!.lang = 'id-ID'.toJS;

      // onresult handler
      _recognition!.onresult = ((JSObject event) {
        _handleResult(
            _SpeechRecognitionEvent._(event));
      }).toJS;

      // onend handler
      _recognition!.onend = ((JSObject event) {
        _isListening = false;
        _statusController.add(VoiceStatus.idle);
      }).toJS;

      // onerror handler
      _recognition!.onerror = ((JSObject event) {
        _isListening = false;
        final errorEvent = _SpeechRecognitionErrorEvent._(event);
        _statusController.add(VoiceStatus.error);
        if (errorEvent.error != 'aborted' &&
            errorEvent.error != 'no-speech') {
          _resultController
              .addError('Voice error: ${errorEvent.error}');
        }
      }).toJS;

      // onstart handler
      _recognition!.onstart = ((JSObject event) {
        _isListening = true;
        _statusController.add(VoiceStatus.listening);
      }).toJS;
    } catch (e) {
      _recognition = null;
    }
  }

  /// Start listening for speech input.
  void startListening() {
    if (_recognition == null) {
      initialize();
    }
    if (_recognition == null) return;

    try {
      _statusController.add(VoiceStatus.listening);
      _recognition!.start();
    } catch (e) {
      _isListening = false;
      _statusController.add(VoiceStatus.error);
    }
  }

  /// Stop listening.
  void stopListening() {
    if (_recognition == null || !_isListening) return;

    try {
      _recognition!.stop();
    } catch (_) {}
    _isListening = false;
    _statusController.add(VoiceStatus.idle);
  }

  void _handleResult(_SpeechRecognitionEvent event) {
    try {
      final results = event.results;
      final length = results.length;

      String finalTranscript = '';
      String interimTranscript = '';

      for (int i = 0; i < length; i++) {
        final result = results.item(i);
        final transcript = result.item(0).transcript;

        if (result.isFinal) {
          finalTranscript += transcript;
        } else {
          interimTranscript += transcript;
        }
      }

      if (finalTranscript.isNotEmpty) {
        _resultController.add(finalTranscript);
        _statusController.add(VoiceStatus.result);
      } else if (interimTranscript.isNotEmpty) {
        _statusController.add(VoiceStatus.listening);
      }
    } catch (e) {
      // Silently handle parsing errors
    }
  }

  /// Speak text using TTS (Text-to-Speech).
  void speak(String text) {
    if (!isTtsSupported || text.isEmpty) return;

    try {
      final synthesis = _speechSynthesis!;

      // Cancel any ongoing speech
      synthesis.cancel();

      // Create utterance
      final utterance = _speechSynthesisUtteranceCtor
          .callAsConstructor<_SpeechSynthesisUtterance>(text.toJS);
      utterance.lang = 'id-ID'.toJS;
      utterance.rate = 1.0.toJS;
      utterance.pitch = 1.0.toJS;
      utterance.volume = 1.0.toJS;

      // Speak
      synthesis.speak(utterance);
    } catch (_) {}
  }

  /// Stop any ongoing TTS speech.
  void stopSpeaking() {
    try {
      _speechSynthesis?.cancel();
    } catch (_) {}
  }

  void dispose() {
    stopListening();
    stopSpeaking();
    _resultController.close();
    _statusController.close();
  }
}

enum VoiceStatus {
  idle,
  listening,
  result,
  error,
}
