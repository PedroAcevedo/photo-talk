import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Result payload streamed by [VoiceService.listen].
class VoiceRecognition {
  final String transcript;
  final bool isFinal;
  const VoiceRecognition({required this.transcript, required this.isFinal});
}

/// One-stop service for the Companion's voice interactions:
///   - speech-to-text via `speech_to_text` (mic → transcript)
///   - text-to-speech via `flutter_tts` (Companion reply → spoken)
///
/// Everything is defensive: if the device has no speech recognizer or the
/// user denies the microphone, calls become no-ops and errors bubble as
/// `VoiceUnavailable` exceptions so the UI can show a gentle message.
class VoiceService {
  VoiceService();

  final SpeechToText _stt = SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _sttReady = false;
  bool _ttsConfigured = false;

  StreamController<VoiceRecognition>? _recognitionCtl;

  bool get isListening => _stt.isListening;
  bool get isReady => _sttReady;

  /// Prepare speech-to-text. Asks the OS for the microphone permission if
  /// needed. Idempotent — safe to call every time the Companion mounts.
  ///
  /// Returns true when the recognizer is usable.
  Future<bool> initSpeech() async {
    if (_sttReady) return true;
    try {
      _sttReady = await _stt.initialize(
        onError: (err) {
          _pushError(err.errorMsg);
        },
        onStatus: (_) {
          // status changes surface via isListening; nothing to do.
        },
        debugLogging: false,
      );
    } catch (e) {
      _sttReady = false;
    }
    return _sttReady;
  }

  /// Stream of partial + final recognitions. The stream emits transcripts
  /// as the user speaks (each event `isFinal: false`), then a single
  /// `isFinal: true` event when the recognizer commits.
  ///
  /// Automatically stops any active TTS so the recognizer doesn't hear
  /// the Companion talking to itself.
  Stream<VoiceRecognition> listen({String localeId = 'en_US'}) async* {
    if (!await initSpeech()) {
      throw const VoiceUnavailable(
        "Speech recognition isn't available on this device.",
      );
    }
    await _tts.stop();

    // Fresh controller for each call so consumers can `await for` cleanly.
    await _recognitionCtl?.close();
    final ctl = StreamController<VoiceRecognition>.broadcast();
    _recognitionCtl = ctl;

    void handler(SpeechRecognitionResult r) {
      if (ctl.isClosed) return;
      ctl.add(VoiceRecognition(
        transcript: r.recognizedWords,
        isFinal: r.finalResult,
      ));
      if (r.finalResult) ctl.close();
    }

    await _stt.listen(
      onResult: handler,
      localeId: localeId,
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.confirmation,
      ),
      // 30 seconds is longer than any dementia-friendly turn we'd want.
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
    );

    yield* ctl.stream;
  }

  Future<void> stopListening() async {
    try {
      if (_stt.isListening) await _stt.stop();
    } catch (_) {}
    await _recognitionCtl?.close();
    _recognitionCtl = null;
  }

  /// Configure TTS once. Slow rate, calm pitch — good match for a
  /// dementia-supportive Companion.
  Future<void> _configureTts() async {
    if (_ttsConfigured) return;
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.42); // slower than default
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
      // Wait for each utterance to finish before returning from speak().
      await _tts.awaitSpeakCompletion(true);
      _ttsConfigured = true;
    } catch (_) {
      // If TTS init fails we quietly become a no-op — voice is optional.
    }
  }

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    await _configureTts();
    try {
      await _tts.speak(text);
    } catch (_) {
      // Speech engine can be busy or missing; swallow so the chat still works.
    }
  }

  Future<void> stopSpeaking() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }

  Future<void> dispose() async {
    await stopListening();
    await stopSpeaking();
    await _recognitionCtl?.close();
    _recognitionCtl = null;
  }

  void _pushError(String message) {
    final ctl = _recognitionCtl;
    if (ctl != null && !ctl.isClosed) {
      ctl.addError(VoiceUnavailable(message));
      ctl.close();
    }
  }
}

class VoiceUnavailable implements Exception {
  final String message;
  const VoiceUnavailable(this.message);
  @override
  String toString() => 'VoiceUnavailable: $message';
}
