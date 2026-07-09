import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import 'externalMediaOverlay.dart';
import 'photoTalkTheme.dart';

/// Music + Captions Mode — large photo, on-screen caption, real audio
/// playback driven by [audioplayers]. If no [audioUrl] is provided the
/// player shows a calm "no audio attached" state.
///
/// When [externalMediaUrl] is provided, an *Open song link* button opens
/// the URL in a full-screen [ExternalMediaOverlay] webview. Closing the
/// overlay returns to the exact same photo + caption + player state.
class MusicCaptionsPage extends StatefulWidget {
  const MusicCaptionsPage({
    Key? key,
    required this.caption,
    this.imageUrl,
    this.song,
    this.audioUrl,
    this.externalMediaUrl,
  }) : super(key: key);

  final String caption;
  final String? imageUrl;
  final String? song;
  final String? audioUrl;
  final String? externalMediaUrl;

  @override
  State<MusicCaptionsPage> createState() => _MusicCaptionsPageState();
}

class _MusicCaptionsPageState extends State<MusicCaptionsPage> {
  final AudioPlayer _player = AudioPlayer();
  PlayerState _state = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  String? _loadError;

  bool get _hasAudio =>
      widget.audioUrl != null && widget.audioUrl!.isNotEmpty;
  bool get _hasExternal =>
      widget.externalMediaUrl != null &&
          widget.externalMediaUrl!.isNotEmpty;

  Future<void> _openExternal() async {
    if (!_hasExternal) return;
    // Pause any local audio so it doesn't play under the webview.
    if (_state == PlayerState.playing) {
      try {
        await _player.pause();
      } catch (_) {}
    }
    if (!mounted) return;
    await ExternalMediaOverlay.open(
      context,
      url: widget.externalMediaUrl!,
      title: widget.song,
    );
  }

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((s) {
      if (!mounted) return;
      setState(() => _state = s);
    });
    _player.onPositionChanged.listen((p) {
      if (!mounted) return;
      setState(() => _position = p);
    });
    _player.onDurationChanged.listen((d) {
      if (!mounted) return;
      setState(() => _duration = d);
    });
    _player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() => _position = _duration);
    });
    if (_hasAudio) {
      _autoPlay();
    }
  }

  Future<void> _autoPlay() async {
    try {
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.play(UrlSource(widget.audioUrl!));
    } catch (e) {
      if (mounted) setState(() => _loadError = e.toString());
    }
  }

  Future<void> _togglePlay() async {
    if (!_hasAudio) return;
    try {
      if (_state == PlayerState.playing) {
        await _player.pause();
      } else if (_state == PlayerState.paused) {
        await _player.resume();
      } else {
        await _player.play(UrlSource(widget.audioUrl!));
      }
    } catch (e) {
      if (mounted) setState(() => _loadError = e.toString());
    }
  }

  Future<void> _seekRelative(Duration delta) async {
    if (!_hasAudio) return;
    final target = _position + delta;
    final clamped = target < Duration.zero
        ? Duration.zero
        : (_duration > Duration.zero && target > _duration
            ? _duration
            : target);
    await _player.seek(clamped);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final song = widget.song ??
        (_hasAudio
            ? 'A gentle melody'
            : (_hasExternal ? 'External link' : 'No song attached'));
    return Scaffold(
      backgroundColor: PhotoTalkPalette.accentBlue,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Music + Captions',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            // LayoutBuilder lets us cap the photo so that image + caption +
            // player always fit. On tighter heights (landscape tablets,
            // short windows) we scroll instead of overflowing.
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxH = constraints.maxHeight;
                // Reserve room for caption (~80) + player (~220) + paddings.
                final photoSide = (maxH - 320).clamp(140.0, 360.0);
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: maxH),
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 24),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: SizedBox(
                              width: photoSide,
                              height: photoSide,
                              child: widget.imageUrl == null
                                  ? Container(
                                      color: Colors.white24,
                                      child: const Icon(Icons.photo_outlined,
                                          color: Colors.white70, size: 80),
                                    )
                                  : Image.network(
                                      widget.imageUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        color: Colors.white24,
                                        child: const Icon(
                                            Icons.photo_outlined,
                                            color: Colors.white70,
                                            size: 80),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            widget.caption,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        _player_widget(song),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _player_widget(String song) {
    final isPlaying = _state == PlayerState.playing;
    final hasDuration = _duration > Duration.zero;
    final progress = hasDuration
        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                _hasAudio
                    ? Icons.music_note_rounded
                    : (_hasExternal
                        ? Icons.link_rounded
                        : Icons.music_off_rounded),
                color: PhotoTalkPalette.accentBlue,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  song,
                  style: PhotoTalkText.body
                      .copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: PhotoTalkPalette.divider,
              valueColor: const AlwaysStoppedAnimation(
                  PhotoTalkPalette.accentBlue),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_fmt(_position),
                    style: PhotoTalkText.caption.copyWith(fontSize: 12)),
                Text(hasDuration ? _fmt(_duration) : '--:--',
                    style: PhotoTalkText.caption.copyWith(fontSize: 12)),
              ],
            ),
          ),
          if (_loadError != null) ...[
            const SizedBox(height: 8),
            Text(
              "Couldn't play this audio. ${_loadError!}",
              style: PhotoTalkText.caption
                  .copyWith(color: PhotoTalkPalette.accentRose, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                iconSize: 36,
                onPressed:
                    _hasAudio ? () => _seekRelative(const Duration(seconds: -10)) : null,
                icon: const Icon(Icons.replay_10_rounded,
                    color: PhotoTalkPalette.accentBlue),
              ),
              const SizedBox(width: 8),
              Material(
                color: _hasAudio
                    ? PhotoTalkPalette.accentBlue
                    : PhotoTalkPalette.divider,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _hasAudio ? _togglePlay : null,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Icon(
                      isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                iconSize: 36,
                onPressed:
                    _hasAudio ? () => _seekRelative(const Duration(seconds: 10)) : null,
                icon: const Icon(Icons.forward_10_rounded,
                    color: PhotoTalkPalette.accentBlue),
              ),
            ],
          ),
          if (_hasExternal) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openExternal,
                icon: const Icon(Icons.open_in_new_rounded),
                label: Text(_hasAudio
                    ? 'Open song link'
                    : 'Open in YouTube / Spotify'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: PhotoTalkPalette.accentBlue,
                  side: const BorderSide(
                      color: PhotoTalkPalette.accentBlue, width: 1.5),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  textStyle:
                      const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
