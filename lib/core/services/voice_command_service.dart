@JS()
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

// ─────────────────────────────────────────────────────────
// JS Interop types for Web Speech API
// ─────────────────────────────────────────────────────────

/// SpeechRecognition API (standard)
@JS('SpeechRecognition')
extension type _SpeechRecognition._(JSObject _) implements JSObject {
  external factory _SpeechRecognition();
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

/// SpeechRecognition API (webkit prefix for Chrome)
@JS('webkitSpeechRecognition')
extension type _WebkitSpeechRecognition._(JSObject _) implements JSObject {
  external factory _WebkitSpeechRecognition();
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

/// SpeechSynthesisLuwaance
@JS('SpeechSynthesisLuwaance')
extension type _SpeechSynthesisLuwaance._(JSObject _) implements JSObject {
  external factory _SpeechSynthesisLuwaance(JSString text);
  external set lang(JSString value);
  external set rate(JSNumber value);
  external set pitch(JSNumber value);
  external set volume(JSNumber value);
  external set voice(_SpeechSynthesisVoice? value);
  external set onend(JSFunction? value);
}

/// SpeechSynthesisVoice
extension type _SpeechSynthesisVoice._(JSObject _) implements JSObject {
  external String get lang;
  external String get name;
  external bool get localService;
}

/// SpeechSynthesis
extension type _SpeechSynthesis._(JSObject _) implements JSObject {
  external void speak(_SpeechSynthesisLuwaance luwaance);
  external void cancel();
  external JSArray<_SpeechSynthesisVoice> getVoices();
  external set onvoiceschanged(JSFunction? value);
}

// JS global access helpers (for existence checks only)
@JS('SpeechRecognition')
external JSFunction? get _speechRecognitionCtor;

@JS('webkitSpeechRecognition')
external JSFunction? get _webkitSpeechRecognitionCtor;

@JS('speechSynthesis')
external _SpeechSynthesis? get _speechSynthesis;

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
      _SpeechRecognition? rec;

      // Try standard SpeechRecognition first
      try {
        if (_speechRecognitionCtor != null) {
          rec = _SpeechRecognition();
        }
      } catch (_) {}

      // Fall back to webkit prefix (Chrome)
      if (rec == null) {
        try {
          if (_webkitSpeechRecognitionCtor != null) {
            final webkit = _WebkitSpeechRecognition();
            // Both have the same JS API, wrap as _SpeechRecognition
            rec = _SpeechRecognition._(webkit);
          }
        } catch (_) {}
      }

      if (rec == null) return;
      _recognition = rec;

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

  _SpeechSynthesisVoice? _cachedIdVoice;
  bool _voiceSearchDone = false;

  /// Find the best Indonesian voice available.
  _SpeechSynthesisVoice? _findIndonesianVoice() {
    if (_voiceSearchDone) return _cachedIdVoice;

    try {
      final synthesis = _speechSynthesis;
      if (synthesis == null) return null;

      final voices = synthesis.getVoices().toDart;
      if (voices.isEmpty) return null;

      _voiceSearchDone = true;

      // Priority: id-ID exact match > id prefix > ms-MY (Malay, closest)
      for (final v in voices) {
        if (v.lang == 'id-ID') {
          _cachedIdVoice = v;
          return v;
        }
      }
      for (final v in voices) {
        if (v.lang.startsWith('id')) {
          _cachedIdVoice = v;
          return v;
        }
      }
      for (final v in voices) {
        if (v.lang.startsWith('ms')) {
          _cachedIdVoice = v;
          return v;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Speak text using TTS (Text-to-Speech).
  /// [onDone] is called when speech finishes or is cancelled.
  void speak(String text, {void Function()? onDone}) {
    if (!isTtsSupported || text.isEmpty) return;

    try {
      final synthesis = _speechSynthesis!;

      // Cancel any ongoing speech
      synthesis.cancel();

      // Create luwaance
      final luwaance = _SpeechSynthesisLuwaance(text.toJS);
      luwaance.lang = 'id-ID'.toJS;
      luwaance.rate = 1.0.toJS;
      luwaance.pitch = 1.0.toJS;
      luwaance.volume = 1.0.toJS;

      // Set Indonesian voice explicitly if available
      final idVoice = _findIndonesianVoice();
      if (idVoice != null) {
        luwaance.voice = idVoice;
      }

      // Callback when done
      if (onDone != null) {
        luwaance.onend = ((JSObject _) {
          onDone();
        }).toJS;
      }

      synthesis.speak(luwaance);
    } catch (_) {
      onDone?.call();
    }
  }

  /// Pre-load voices (call early, e.g. on app init).
  /// Some browsers load voices async, this ensures they're ready.
  void preloadVoices() {
    if (!isTtsSupported) return;
    try {
      final synthesis = _speechSynthesis!;
      // Try immediate
      _findIndonesianVoice();
      // Also listen for async voice loading
      synthesis.onvoiceschanged = ((JSObject _) {
        _voiceSearchDone = false;
        _findIndonesianVoice();
      }).toJS;
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
