import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../photoTalkTheme.dart';

/// A pickled voice note ready to be uploaded to Firebase Storage.
class RecordedVoiceNote {
  final Uint8List bytes;
  final int durationSeconds;
  final String mime;
  final String extension;

  const RecordedVoiceNote({
    required this.bytes,
    required this.durationSeconds,
    required this.mime,
    required this.extension,
  });
}

/// Inline mic + stopwatch + preview player for the Add-a-memory form.
///
/// Flow:
///   idle → tap mic → recording (stopwatch runs) → tap stop → preview
///   (play/pause + duration + delete + re-record).
///
/// The parent hears about the final recording through [onRecorded] (a
/// non-null value means a note is attached; null means the user removed
/// their recording).
class VoiceNoteRecorder extends StatefulWidget {
  const VoiceNoteRecorder({
    Key? key,
    required this.onRecorded,
    this.initialUrl,
    this.initialDurationSeconds,
  }) : super(key: key);

  final ValueChanged<RecordedVoiceNote?> onRecorded;

  /// If the caller already has a saved voice note (edit flow), pass its
  /// URL here — the widget renders in "already saved" mode and lets the
  /// user replace it.
  final String? initialUrl;
  final int? initialDurationSeconds;

  @override
  State<VoiceNoteRecorder> createState() => _VoiceNoteRecorderState();
}

enum _RecorderPhase { idle, recording, preview }

class _VoiceNoteRecorderState extends State<VoiceNoteRecorder> {
  final AudioRecorder _recorder = AudioRecorder();
  final ap.AudioPlayer _player = ap.AudioPlayer();

  _RecorderPhase _phase = _RecorderPhase.idle;

  // Recording bookkeeping
  Timer? _tick;
  DateTime? _recordStart;
  int _elapsedSeconds = 0;
  String? _recordPath;
  String? _recordExt;

  // Preview bookkeeping
  RecordedVoiceNote? _preview;
  ap.PlayerState _playerState = ap.PlayerState.stopped;
  Duration _playbackPos = Duration.zero;

  // Errors surface to the UI here.
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialUrl != null && widget.initialUrl!.isNotEmpty) {
      _phase = _RecorderPhase.preview;
      _elapsedSeconds = widget.initialDurationSeconds ?? 0;
      // No local bytes; playback still works because AudioPlayer will
      // stream from the URL. onRecorded stays as-is (null == unchanged).
    }
    _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _playerState = s);
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _playbackPos = p);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playbackPos = Duration.zero);
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    setState(() => _error = null);
    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        setState(() => _error =
            "Microphone permission is needed to record a voice note.");
        return;
      }
      // Pick a container we can actually upload. AAC in an M4A container
      // is well-supported across Android + iOS + web.
      const config = RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 96000,
        sampleRate: 44100,
        numChannels: 1,
      );
      String path;
      if (kIsWeb) {
        // On web the plugin writes to a blob URL; the path is opaque.
        path = 'voice_note.m4a';
      } else {
        final dir = await getTemporaryDirectory();
        path =
            '${dir.path}/pt_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      }
      await _recorder.start(config, path: path);
      _recordPath = path;
      _recordExt = 'm4a';
      _recordStart = DateTime.now();
      _elapsedSeconds = 0;
      _tick?.cancel();
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {
          _elapsedSeconds =
              DateTime.now().difference(_recordStart!).inSeconds;
        });
        // Hard cap so we never blow up Firebase Storage cost. 3 min is
        // long enough for a family message.
        if (_elapsedSeconds >= 180) _stopRecording();
      });
      setState(() => _phase = _RecorderPhase.recording);
    } catch (e) {
      setState(() {
        _error = "Couldn't start recording: $e";
        _phase = _RecorderPhase.idle;
      });
    }
  }

  Future<void> _stopRecording() async {
    _tick?.cancel();
    try {
      final resultPath = await _recorder.stop();
      Uint8List bytes = Uint8List(0);
      if (resultPath != null && resultPath.isNotEmpty) {
        if (kIsWeb) {
          // On web, `record` returns a blob: URL that we need to fetch.
          // The audio bytes go through the browser's fetch API.
          // ignore: unused_local_variable
          final response = await _fetchBlobBytes(resultPath);
          bytes = response;
        } else {
          final f = File(resultPath);
          bytes = await f.readAsBytes();
        }
      }
      final note = RecordedVoiceNote(
        bytes: bytes,
        durationSeconds: _elapsedSeconds,
        mime: 'audio/mp4',
        extension: _recordExt ?? 'm4a',
      );
      setState(() {
        _preview = note;
        _phase = _RecorderPhase.preview;
      });
      widget.onRecorded(note);
    } catch (e) {
      setState(() {
        _error = "Couldn't finish recording: $e";
        _phase = _RecorderPhase.idle;
      });
    }
  }

  Future<Uint8List> _fetchBlobBytes(String url) async {
    // Guarded so this file still compiles on non-web builds without the
    // HttpRequest API.
    if (!kIsWeb) return Uint8List(0);
    try {
      // ignore: avoid_web_libraries_in_flutter
      // We only reach this on kIsWeb; the analyzer may still warn.
      final response = await HttpClient()
          .getUrl(Uri.parse(url))
          .then((r) => r.close());
      final builder = BytesBuilder();
      await for (final chunk in response) {
        builder.add(chunk);
      }
      return builder.toBytes();
    } catch (_) {
      return Uint8List(0);
    }
  }

  Future<void> _togglePlayback() async {
    if (_phase != _RecorderPhase.preview) return;
    try {
      if (_playerState == ap.PlayerState.playing) {
        await _player.pause();
        return;
      }
      if (_playerState == ap.PlayerState.paused) {
        await _player.resume();
        return;
      }
      // Fresh start.
      if (_preview != null && !kIsWeb && _recordPath != null) {
        await _player.play(ap.DeviceFileSource(_recordPath!));
      } else if (_preview != null && kIsWeb) {
        await _player.play(ap.BytesSource(_preview!.bytes));
      } else if (widget.initialUrl != null) {
        await _player.play(ap.UrlSource(widget.initialUrl!));
      }
    } catch (e) {
      setState(() => _error = "Couldn't play preview: $e");
    }
  }

  Future<void> _discard() async {
    await _player.stop();
    setState(() {
      _preview = null;
      _phase = _RecorderPhase.idle;
      _elapsedSeconds = 0;
      _recordPath = null;
    });
    widget.onRecorded(null);
  }

  String _fmtSeconds(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$m:$ss';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PhotoTalkPalette.accentBlue.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: PhotoTalkPalette.accentBlue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.record_voice_over_outlined,
                  color: PhotoTalkPalette.accentBlue, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _titleForPhase(),
                      style: PhotoTalkText.body
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      _subtitleForPhase(),
                      style: PhotoTalkText.caption,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _actionForPhase(),
            ],
          ),
          if (_phase == _RecorderPhase.preview) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                IconButton(
                  onPressed: _togglePlayback,
                  iconSize: 32,
                  color: PhotoTalkPalette.accentBlue,
                  icon: Icon(_playerState == ap.PlayerState.playing
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_fill),
                ),
                Expanded(
                  child: LinearProgressIndicator(
                    minHeight: 6,
                    value: _elapsedSeconds > 0
                        ? (_playbackPos.inSeconds / _elapsedSeconds)
                            .clamp(0.0, 1.0)
                        : 0,
                    backgroundColor: PhotoTalkPalette.divider,
                    valueColor: const AlwaysStoppedAnimation(
                        PhotoTalkPalette.accentBlue),
                  ),
                ),
                const SizedBox(width: 10),
                Text(_fmtSeconds(_elapsedSeconds),
                    style: PhotoTalkText.caption),
                IconButton(
                  tooltip: 'Delete and re-record',
                  onPressed: _discard,
                  icon: const Icon(Icons.delete_outline,
                      color: PhotoTalkPalette.accentRose),
                ),
              ],
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: PhotoTalkText.caption
                  .copyWith(color: PhotoTalkPalette.accentRose),
            ),
          ],
        ],
      ),
    );
  }

  String _titleForPhase() {
    switch (_phase) {
      case _RecorderPhase.idle:
        return 'Record a voice note';
      case _RecorderPhase.recording:
        return 'Recording… ${_fmtSeconds(_elapsedSeconds)}';
      case _RecorderPhase.preview:
        return 'Voice note attached';
    }
  }

  String _subtitleForPhase() {
    switch (_phase) {
      case _RecorderPhase.idle:
        return 'A short spoken message to go with this memory (up to 3 minutes).';
      case _RecorderPhase.recording:
        return 'Tap the square to stop.';
      case _RecorderPhase.preview:
        return 'Preview here. It will play on the memory card in the feed.';
    }
  }

  Widget _actionForPhase() {
    switch (_phase) {
      case _RecorderPhase.idle:
        return Material(
          color: PhotoTalkPalette.accentBlue,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _startRecording,
            child: const Padding(
              padding: EdgeInsets.all(10),
              child: Icon(Icons.mic_rounded, color: Colors.white, size: 22),
            ),
          ),
        );
      case _RecorderPhase.recording:
        return Material(
          color: PhotoTalkPalette.accentRose,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _stopRecording,
            child: const Padding(
              padding: EdgeInsets.all(10),
              child: Icon(Icons.stop_rounded, color: Colors.white, size: 22),
            ),
          ),
        );
      case _RecorderPhase.preview:
        return TextButton(
          onPressed: () async {
            await _discard();
            await _startRecording();
          },
          style: TextButton.styleFrom(
            foregroundColor: PhotoTalkPalette.accentBlue,
          ),
          child: const Text('Re-record',
              style: TextStyle(fontWeight: FontWeight.w600)),
        );
    }
  }
}
