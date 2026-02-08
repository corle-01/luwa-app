import 'dart:js_interop';

/// KDS sound notification service using Web Audio API.
///
/// Generates a pleasant two-tone chime programmatically - no audio files needed.
/// Only imported on web builds.
class KdsSoundService {
  _AudioContext? _ctx;
  bool _muted = false;

  bool get isMuted => _muted;

  void toggleMute() {
    _muted = !_muted;
  }

  void setMuted(bool value) {
    _muted = value;
  }

  /// Play a two-tone notification chime when new orders arrive.
  /// Uses Web Audio API OscillatorNode to generate tones programmatically.
  void playNewOrderSound() {
    if (_muted) return;

    try {
      _ctx ??= _AudioContext();
      final ctx = _ctx!;

      // First tone: 880 Hz (A5) for 150ms
      _playTone(ctx, 880, 0.0, 0.15, 0.3);
      // Second tone: 1100 Hz (C#6) for 200ms, starts after 180ms
      _playTone(ctx, 1100, 0.18, 0.2, 0.3);
    } catch (e) {
      // Silently fail - sound is non-critical for KDS functionality
    }
  }

  /// Play a single tone using an OscillatorNode.
  void _playTone(
    _AudioContext ctx,
    double frequency,
    double startDelay,
    double duration,
    double volume,
  ) {
    final oscillator = ctx.createOscillator();
    final gainNode = ctx.createGain();

    // Set oscillator properties
    oscillator.type = 'sine'.toJS;
    oscillator.frequency.value = frequency;

    // Set gain (volume) with envelope for smooth sound
    final now = ctx.currentTime;
    final startTime = now + startDelay;
    final endTime = startTime + duration;

    gainNode.gain.setValueAtTime(0.0, startTime);
    gainNode.gain.linearRampToValueAtTime(volume, startTime + 0.02);
    gainNode.gain.linearRampToValueAtTime(0.0, endTime);

    // Connect: oscillator -> gain -> destination (speakers)
    oscillator.connect(gainNode);
    gainNode.connect(ctx.destination);

    oscillator.start(startTime);
    oscillator.stop(endTime + 0.05);
  }

  void dispose() {
    try {
      _ctx?.close();
    } catch (_) {}
    _ctx = null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Web Audio API JS interop bindings via dart:js_interop extension types
// ─────────────────────────────────────────────────────────────────────────────

@JS('AudioContext')
extension type _AudioContext._(JSObject _) implements JSObject {
  external _AudioContext();
  external double get currentTime;
  external _AudioDestinationNode get destination;
  external _OscillatorNode createOscillator();
  external _GainNode createGain();
  external void close();
}

extension type _AudioDestinationNode._(JSObject _) implements JSObject {}

extension type _OscillatorNode._(JSObject _) implements JSObject {
  external set type(JSString value);
  external _AudioParam get frequency;
  external void connect(JSObject destination);
  external void start(double when);
  external void stop(double when);
}

extension type _GainNode._(JSObject _) implements JSObject {
  external _AudioParam get gain;
  external void connect(JSObject destination);
}

extension type _AudioParam._(JSObject _) implements JSObject {
  external set value(double v);
  external void setValueAtTime(double value, double startTime);
  external void linearRampToValueAtTime(double value, double endTime);
}
