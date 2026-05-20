import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'photoTalkTheme.dart';

/// Music + Captions Mode - large photo, on-screen caption,
/// and a simple, fake "now playing" control. The audio backend is
/// intentionally out of scope for this view-only pass.
class MusicCaptionsPage extends StatefulWidget {
  const MusicCaptionsPage({
    Key? key,
    required this.caption,
    this.imageUrl,
    this.song,
  }) : super(key: key);

  final String caption;
  final String? imageUrl;
  final String? song;

  @override
  State<MusicCaptionsPage> createState() => _MusicCaptionsPageState();
}

class _MusicCaptionsPageState extends State<MusicCaptionsPage> {
  bool _playing = true;

  @override
  Widget build(BuildContext context) {
    final song = widget.song ?? 'A gentle melody';
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
        child: Column(
          children: [
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: widget.imageUrl == null
                      ? Container(
                          color: Colors.white24,
                          child: const Icon(Icons.photo_outlined,
                              color: Colors.white70, size: 80),
                        )
                      : CachedNetworkImage(
                          imageUrl: widget.imageUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            color: Colors.white24,
                            child: const Icon(Icons.photo_outlined,
                                color: Colors.white70, size: 80),
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                widget.caption,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ),
            const Spacer(),
            _player(song),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _player(String song) {
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
              const Icon(Icons.music_note_rounded,
                  color: PhotoTalkPalette.accentBlue),
              const SizedBox(width: 10),
              Expanded(
                child: Text(song,
                    style: PhotoTalkText.body
                        .copyWith(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Static "progress" line for visual completeness.
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: const LinearProgressIndicator(
              value: 0.35,
              minHeight: 6,
              backgroundColor: PhotoTalkPalette.divider,
              valueColor: AlwaysStoppedAnimation(PhotoTalkPalette.accentBlue),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                iconSize: 36,
                onPressed: () {},
                icon: const Icon(Icons.skip_previous_rounded,
                    color: PhotoTalkPalette.accentBlue),
              ),
              const SizedBox(width: 8),
              Material(
                color: PhotoTalkPalette.accentBlue,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => setState(() => _playing = !_playing),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Icon(
                      _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                iconSize: 36,
                onPressed: () {},
                icon: const Icon(Icons.skip_next_rounded,
                    color: PhotoTalkPalette.accentBlue),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
