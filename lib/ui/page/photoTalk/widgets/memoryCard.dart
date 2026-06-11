import 'package:flutter/material.dart';

import '../photoTalkTheme.dart';

/// A photo-first memory card.
///
/// Designed for low cognitive load:
///   - Large image up top
///   - Short, readable caption
///   - Optional who/where/why chips
///   - Two oversized action buttons: Talk about it · Play music
class MemoryCard extends StatelessWidget {
  const MemoryCard({
    Key? key,
    required this.caption,
    this.who,
    this.where,
    this.why,
    this.imageUrl,
    this.song,
    this.hasAudio = false,
    this.tags = const [],
    this.onTalk,
    this.onPlayMusic,
    this.onTap,
  }) : super(key: key);

  final String caption;
  final String? who;
  final String? where;
  final String? why;
  final String? imageUrl;
  final String? song;
  /// True when this memory has an uploaded audio file. Causes the play
  /// button to read "Play music" instead of "Listen".
  final bool hasAudio;
  final List<String> tags;

  final VoidCallback? onTalk;
  final VoidCallback? onPlayMusic;
  final VoidCallback? onTap;

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
              const Divider(height: 1, color: PhotoTalkPalette.divider),
              _actions(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _photo() {
    final radius = const BorderRadius.vertical(top: Radius.circular(20));
    if (imageUrl == null || imageUrl!.isEmpty) {
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
    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        // Cap the photo height so the card never grows taller than ~320px
        // of image on phones and tablets. Keeps caption + actions in view.
        height: 320,
        width: double.infinity,
        child: Image.network(
          imageUrl!,
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
