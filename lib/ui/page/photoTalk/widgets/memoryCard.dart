import 'package:cached_network_image/cached_network_image.dart';
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
          height: 260,
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
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: CachedNetworkImage(
          imageUrl: imageUrl!,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(
            color: PhotoTalkPalette.background,
            alignment: Alignment.center,
            child: const CircularProgressIndicator(strokeWidth: 2),
          ),
          errorWidget: (_, __, ___) => Container(
            color: PhotoTalkPalette.background,
            alignment: Alignment.center,
            child: const Icon(Icons.photo_outlined,
                size: 64, color: PhotoTalkPalette.textMuted),
          ),
        ),
      ),
    );
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
              icon: Icons.play_circle_outline,
              label: song == null ? 'Listen' : 'Play music',
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
