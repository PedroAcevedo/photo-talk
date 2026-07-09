import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:flutter/material.dart';

import '../photoTalkTheme.dart';

/// A photo-first memory card.
///
/// Designed for low cognitive load:
///   - Large image up top
///   - Short, readable caption
///   - Optional who/where/why chips
///   - Two oversized action buttons: Talk about it · Play music
class MemoryCard extends StatefulWidget {
  const MemoryCard({
    Key? key,
    required this.caption,
    this.who,
    this.where,
    this.why,
    this.imageUrl,
    this.imageUrls,
    this.song,
    this.hasAudio = false,
    this.tags = const [],
    this.onTalk,
    this.onPlayMusic,
    this.onTap,
    this.isFavorite = false,
    this.onFavoriteToggle,
    this.voiceNoteUrl,
    this.voiceNoteDurationSeconds,
  }) : super(key: key);

  final String caption;
  final String? who;
  final String? where;
  final String? why;
  /// Legacy single-image URL. Used when [imageUrls] is null/empty.
  final String? imageUrl;
  /// One or more image URLs. When length > 1 the card becomes a swipeable
  /// carousel with dot indicators.
  final List<String>? imageUrls;
  final String? song;
  /// True when this memory has an uploaded audio file. Causes the play
  /// button to read "Play music" instead of "Listen".
  final bool hasAudio;
  final List<String> tags;

  final VoidCallback? onTalk;
  final VoidCallback? onPlayMusic;
  final VoidCallback? onTap;
  /// True when this memory is on the recipient's favorites list. Renders
  /// the heart filled.
  final bool isFavorite;
  /// Called when the heart is tapped. When null the heart is hidden.
  final VoidCallback? onFavoriteToggle;
  /// A short spoken message attached to this memory. Played inline via a
  /// compact player row.
  final String? voiceNoteUrl;
  /// Voice-note length in seconds (persisted at upload).
  final int? voiceNoteDurationSeconds;

  @override
  State<MemoryCard> createState() => _MemoryCardState();
}

class _MemoryCardState extends State<MemoryCard> {
  late final PageController _pageCtrl = PageController();
  int _page = 0;

  // Voice-note inline playback.
  final ap.AudioPlayer _voicePlayer = ap.AudioPlayer();
  ap.PlayerState _voiceState = ap.PlayerState.stopped;
  Duration _voicePos = Duration.zero;

  @override
  void initState() {
    super.initState();
    _voicePlayer.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _voiceState = s);
    });
    _voicePlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _voicePos = p);
    });
    _voicePlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _voicePos = Duration.zero);
    });
  }

  bool get _hasVoiceNote =>
      widget.voiceNoteUrl != null && widget.voiceNoteUrl!.isNotEmpty;

  Future<void> _toggleVoiceNote() async {
    if (!_hasVoiceNote) return;
    try {
      if (_voiceState == ap.PlayerState.playing) {
        await _voicePlayer.pause();
      } else if (_voiceState == ap.PlayerState.paused) {
        await _voicePlayer.resume();
      } else {
        await _voicePlayer.play(ap.UrlSource(widget.voiceNoteUrl!));
      }
    } catch (_) {
      // Playback errors are non-fatal; the card just goes back to idle.
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _voicePlayer.dispose();
    super.dispose();
  }

  List<String> get _allImages {
    final list = widget.imageUrls;
    if (list != null && list.isNotEmpty) {
      return list.where((u) => u.isNotEmpty).toList();
    }
    if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) {
      return [widget.imageUrl!];
    }
    return const [];
  }

  // ---- forwarders so existing helper methods keep working ----
  String get caption => widget.caption;
  String? get who => widget.who;
  String? get where => widget.where;
  String? get why => widget.why;
  String? get song => widget.song;
  bool get hasAudio => widget.hasAudio;
  List<String> get tags => widget.tags;
  VoidCallback? get onTalk => widget.onTalk;
  VoidCallback? get onPlayMusic => widget.onPlayMusic;
  VoidCallback? get onTap => widget.onTap;
  bool get isFavorite => widget.isFavorite;
  VoidCallback? get onFavoriteToggle => widget.onFavoriteToggle;
  String? get imageUrl =>
      _allImages.isNotEmpty ? _allImages.first : null;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Material(
        color: PhotoTalkPalette.surface,
        elevation: 2,
        shadowColor: Colors.black12,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _photo(),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                child: Text(caption, style: PhotoTalkText.h2),
              ),
              _chips(),
              if (why != null && why!.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
                  child: Text(why!, style: PhotoTalkText.bodyLarge),
                ),
              if (song != null && song!.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                  child: Row(
                    children: [
                      const Icon(Icons.music_note_rounded,
                          color: PhotoTalkPalette.accentBlue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          song!,
                          style: PhotoTalkText.caption.copyWith(
                              color: PhotoTalkPalette.accentBlue,
                              fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              if (_hasVoiceNote) _voiceNoteRow(),
              const Divider(height: 1, color: PhotoTalkPalette.divider),
              _actions(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _photo() {
    return Stack(
      children: [
        _photoBody(),
        if (onFavoriteToggle != null)
          Positioned(
            top: 10,
            left: 12,
            child: _favoriteButton(),
          ),
      ],
    );
  }

  Widget _favoriteButton() {
    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onFavoriteToggle,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            isFavorite ? Icons.favorite : Icons.favorite_border,
            color: isFavorite
                ? PhotoTalkPalette.accentRose
                : Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _photoBody() {
    final radius = const BorderRadius.vertical(top: Radius.circular(20));
    final images = _allImages;
    if (images.isEmpty) {
      return ClipRRect(
        borderRadius: radius,
        child: Container(
          height: 220,
          width: double.infinity,
          color: PhotoTalkPalette.background,
          child: const Center(
            child: Icon(Icons.photo_outlined,
                size: 64, color: PhotoTalkPalette.textMuted),
          ),
        ),
      );
    }
    if (images.length == 1) {
      return ClipRRect(
        borderRadius: radius,
        child: SizedBox(
          height: 320,
          width: double.infinity,
          child: _networkImage(images.first),
        ),
      );
    }
    // Multi-photo: swipeable carousel with dots and a counter chip.
    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        height: 320,
        width: double.infinity,
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageCtrl,
              itemCount: images.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (_, i) => _networkImage(images[i]),
            ),
            Positioned(
              top: 10,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_page + 1} / ${images.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(images.length, (i) {
                  final active = i == _page;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: active ? Colors.white : Colors.white60,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _networkImage(String url) {
    return SizedBox(
      width: double.infinity,
      child: Image.network(
        url,
        fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              color: PhotoTalkPalette.background,
              alignment: Alignment.center,
              child: const CircularProgressIndicator(strokeWidth: 2),
            );
          },
          errorBuilder: (context, error, stack) {
            // Reveal the underlying failure so it's diagnosable from the UI.
            final detail = _summarizeImageError(error);
            return Container(
              color: PhotoTalkPalette.background,
              padding: const EdgeInsets.all(16),
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.image_not_supported_outlined,
                      size: 48, color: PhotoTalkPalette.accentRose),
                  const SizedBox(height: 8),
                  Text(
                    'Image could not load',
                    textAlign: TextAlign.center,
                    style: PhotoTalkText.body
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (detail != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      detail,
                      textAlign: TextAlign.center,
                      style: PhotoTalkText.caption.copyWith(fontSize: 12),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      );
  }

  String? _summarizeImageError(Object error) {
    final s = error.toString();
    // Flutter formats HttpException as "HttpException: ...statusCode: 403..."
    final codeMatch = RegExp(r'statusCode:\s*(\d+)').firstMatch(s);
    if (codeMatch != null) {
      final code = codeMatch.group(1);
      switch (code) {
        case '403':
          return 'HTTP 403 — Storage rules deny read access.';
        case '404':
          return 'HTTP 404 — file not found in Storage.';
        case '401':
          return 'HTTP 401 — not authenticated for this Storage object.';
        default:
          return 'HTTP $code while fetching the image.';
      }
    }
    if (s.contains('Failed host lookup') || s.contains('SocketException')) {
      return 'Network unreachable.';
    }
    if (s.contains('XMLHttpRequest') || s.contains('CORS')) {
      return 'Blocked by browser (likely a CORS rule on the Storage bucket).';
    }
    // Trim very long messages so the card stays readable.
    return s.length > 120 ? '${s.substring(0, 117)}…' : s;
  }

  Widget _chips() {
    final items = <Widget>[];
    if (who != null && who!.trim().isNotEmpty) {
      items.add(_chip(Icons.people_alt_outlined, who!));
    }
    if (where != null && where!.trim().isNotEmpty) {
      items.add(_chip(Icons.place_outlined, where!));
    }
    for (final tag in tags) {
      items.add(_chip(Icons.favorite_border, tag));
    }
    if (items.isEmpty) return const SizedBox(height: 4);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: items,
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: PhotoTalkPalette.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: PhotoTalkPalette.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: PhotoTalkPalette.textSecondary),
          const SizedBox(width: 6),
          Text(label, style: PhotoTalkText.chip),
        ],
      ),
    );
  }

  Widget _voiceNoteRow() {
    final isPlaying = _voiceState == ap.PlayerState.playing;
    final total = widget.voiceNoteDurationSeconds ?? 0;
    final progress = total > 0
        ? (_voicePos.inSeconds / total).clamp(0.0, 1.0)
        : 0.0;
    String fmt(int sec) {
      final m = (sec ~/ 60).toString().padLeft(2, '0');
      final s = (sec % 60).toString().padLeft(2, '0');
      return '$m:$s';
    }

    final elapsed = fmt(_voicePos.inSeconds);
    final durationText = total > 0 ? fmt(total) : '--:--';
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: PhotoTalkPalette.accentBlue.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: PhotoTalkPalette.accentBlue.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: _toggleVoiceNote,
              iconSize: 32,
              color: PhotoTalkPalette.accentBlue,
              icon: Icon(isPlaying
                  ? Icons.pause_circle_filled
                  : Icons.play_circle_fill),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Voice note from family',
                      style: PhotoTalkText.body
                          .copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      minHeight: 5,
                      value: progress,
                      backgroundColor: PhotoTalkPalette.divider,
                      valueColor: const AlwaysStoppedAnimation(
                          PhotoTalkPalette.accentBlue),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text('$elapsed / $durationText',
                style: PhotoTalkText.caption.copyWith(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _actions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: _primaryAction(
              icon: Icons.chat_bubble_outline,
              label: 'Talk about it',
              color: PhotoTalkPalette.primary,
              onPressed: onTalk,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _primaryAction(
              icon: hasAudio
                  ? Icons.play_circle_outline
                  : Icons.menu_book_outlined,
              label: hasAudio
                  ? 'Play music'
                  : (song != null ? 'View song' : 'Captions'),
              color: PhotoTalkPalette.accentBlue,
              onPressed: onPlayMusic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _primaryAction({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 22),
        label: Text(label,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: color,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
