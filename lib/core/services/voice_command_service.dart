import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

/// Voice Command Service using Web Speech API
///
/// Provides:
/// - STT (Speech-to-Text): Microphone input → text
/// - TTS (Text-to-Speech): Text → spoken audio output
class VoiceCommandService {
  JSObject? _recognition;
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
      final hasStandard = web.window.has('SpeechRecognition');
      final hasWebkit = web.window.has('webkitSpeechRecognition');
      return hasStandard || hasWebkit;
    } catch (_) {
      return false;
    }
  }

  /// Check if Speech Synthesis (TTS) is supported.
  static bool get isTtsSupported {
    try {
      return web.window.has('speechSynthesis');
    } catch (_) {
      return false;
    }
  }

  /// Initialize the speech recognition engine.
  void initialize() {
    if (_recognition != null) return;

    try {
      // Try standard API first, then webkit prefix
      if (web.window.has('SpeechRecognition')) {
        _recognition = _createRecognition('SpeechRecognition');
      } else if (web.window.has('webkitSpeechRecognition')) {
        _recognition = _createRecognition('webkitSpeechRecognition');
      }

      if (_recognition == null) return;

      // Configure
      _recognition!.setProperty('continuous'.toJS, false.toJS);
      _recognition!.setProperty('interimResults'.toJS, true.toJS);
      _recognition!.setProperty('lang'.toJS, 'id-ID'.toJS);

      // onresult handler
      _recognition!.setProperty(
        'onresult'.toJS,
        ((JSObject event) {
          _handleResult(event);
        }).toJS,
      );

      // onend handler
      _recognition!.setProperty(
        'onend'.toJS,
        ((JSObject event) {
          _isListening = false;
          _statusController.add(VoiceStatus.idle);
        }).toJS,
      );

      // onerror handler
      _recognition!.setProperty(
        'onerror'.toJS,
        ((JSObject event) {
          _isListening = false;
          final error = (event.getProperty('error'.toJS) as JSString).toDart;
          _statusController.add(VoiceStatus.error);
          if (error != 'aborted' && error != 'no-speech') {
            _resultController.addError('Voice error: $error');
          }
        }).toJS,
      );

      // onstart handler
      _recognition!.setProperty(
        'onstart'.toJS,
        ((JSObject event) {
          _isListening = true;
          _statusController.add(VoiceStatus.listening);
        }).toJS,
      );
    } catch (e) {
      _recognition = null;
    }
  }

  JSObject _createRecognition(String constructorName) {
    final constructor = web.window.getProperty(constructorName.toJS);
    return _callConstructor(constructor);
  }

  /// Start listening for speech input.
  void startListening() {
    if (_recognition == null) {
      initialize();
    }
    if (_recognition == null) return;

    try {
      _statusController.add(VoiceStatus.listening);
      _recognition!.callMethod('start'.toJS);
    } catch (e) {
      _isListening = false;
      _statusController.add(VoiceStatus.error);
    }
  }

  /// Stop listening.
  void stopListening() {
    if (_recognition == null || !_isListening) return;

    try {
      _recognition!.callMethod('stop'.toJS);
    } catch (_) {}
    _isListening = false;
    _statusController.add(VoiceStatus.idle);
  }

  void _handleResult(JSObject event) {
    try {
      final results = event.getProperty('results'.toJS) as JSObject;
      final length = (results.getProperty('length'.toJS) as JSNumber).toDartInt;

      String finalTranscript = '';
      String interimTranscript = '';

      for (int i = 0; i < length; i++) {
        final result = results.callMethod('item'.toJS, i.toJS) as JSObject;
        final isFinal =
            (result.getProperty('isFinal'.toJS) as JSBoolean).toDart;
        final alternative =
            result.callMethod('item'.toJS, 0.toJS) as JSObject;
        final transcript =
            (alternative.getProperty('transcript'.toJS) as JSString).toDart;

        if (isFinal) {
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
      // Cancel any ongoing speech
      _callSynthesisMethod('cancel');

      // Create utterance
      final utterance = _createUtterance(text);
      utterance.setProperty('lang'.toJS, 'id-ID'.toJS);
      utterance.setProperty('rate'.toJS, 1.0.toJS);
      utterance.setProperty('pitch'.toJS, 1.0.toJS);
      utterance.setProperty('volume'.toJS, 1.0.toJS);

      // Speak
      final synthesis =
          web.window.getProperty('speechSynthesis'.toJS) as JSObject;
      synthesis.callMethod('speak'.toJS, utterance);
    } catch (_) {}
  }

  /// Stop any ongoing TTS speech.
  void stopSpeaking() {
    try {
      _callSynthesisMethod('cancel');
    } catch (_) {}
  }

  void _callSynthesisMethod(String method) {
    final synthesis =
        web.window.getProperty('speechSynthesis'.toJS) as JSObject;
    synthesis.callMethod(method.toJS);
  }

  JSObject _createUtterance(String text) {
    final constructor =
        web.window.getProperty('SpeechSynthesisUtterance'.toJS);
    return _callConstructor(constructor, text.toJS);
  }

  void dispose() {
    stopListening();
    stopSpeaking();
    _resultController.close();
    _statusController.close();
  }
}

JSObject _callConstructor(JSAny constructor, [JSAny? arg]) {
  if (arg != null) {
    return (constructor as JSFunction).callAsConstructor(arg) as JSObject;
  }
  return (constructor as JSFunction).callAsConstructor() as JSObject;
}

/// Extension to check if a property exists on window.
extension _WindowHas on web.Window {
  bool has(String property) {
    try {
      final val = getProperty(property.toJS);
      return val != null && !val.isUndefinedOrNull;
    } catch (_) {
      return false;
    }
  }
}

enum VoiceStatus {
  idle,
  listening,
  result,
  error,
}
