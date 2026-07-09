import 'package:flutter/material.dart';
import 'package:flutter_twitter_clone/model/feedModel.dart';
import 'package:flutter_twitter_clone/services/favorites_service.dart';
import 'package:flutter_twitter_clone/services/voice_note_service.dart';
import 'package:flutter_twitter_clone/state/authState.dart';
import 'package:flutter_twitter_clone/state/feedState.dart';
import 'package:flutter_twitter_clone/ui/page/photoTalk/companionPage.dart';
import 'package:flutter_twitter_clone/ui/page/photoTalk/musicCaptionsPage.dart';
import 'package:flutter_twitter_clone/ui/page/photoTalk/photoTalkTheme.dart';
import 'package:flutter_twitter_clone/ui/page/photoTalk/widgets/memoryCard.dart';
import 'package:provider/provider.dart';

/// Saved memories — memories any care-circle member has favorited by
/// tapping the heart on a memory card.
///
/// Storage: /favorites/{recipientId}/{memoryKey} = {savedAt, savedByUid}
/// The actual memory content is hydrated from FeedState at render time —
/// we only store references so favorites stay consistent when a memory
/// is edited elsewhere.
class BookmarkPage extends StatefulWidget {
  const BookmarkPage({Key? key}) : super(key: key);

  static Route<T> getRoute<T>() =>
      MaterialPageRoute(builder: (_) => const BookmarkPage());

  @override
  State<BookmarkPage> createState() => _BookmarkPageState();
}

class _BookmarkPageState extends State<BookmarkPage> {
  final FavoritesService _favorites = FavoritesService();
  final VoiceNoteService _voiceNotes = VoiceNoteService();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final feed = context.watch<FeedState>();
    final recipientId = auth.userModel?.linkedRecipientId ??
        auth.userModel?.userId ??
        auth.user?.uid;

    return Scaffold(
      backgroundColor: PhotoTalkPalette.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: PhotoTalkPalette.background,
        foregroundColor: PhotoTalkPalette.textPrimary,
        title: Text('Saved memories', style: PhotoTalkText.title),
      ),
      body: recipientId == null
          ? _emptyState('Sign in to see saved memories.')
          : StreamBuilder<List<FavoriteEntry>>(
              stream: _favorites.watch(recipientId),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final entries = snap.data ?? const <FavoriteEntry>[];
                if (entries.isEmpty) {
                  return _emptyState(
                    "Tap the heart on any memory to save it here. "
                    "Anyone in the care circle can add — everyone sees them.",
                  );
                }
                // Hydrate favorites from the currently loaded feed.
                final feedByKey = {
                  for (final m in (feed.feedList ?? const <FeedModel>[]))
                    if (m.key != null) m.key!: m,
                };
                final memories = <FeedModel>[];
                for (final e in entries) {
                  final m = feedByKey[e.memoryKey];
                  if (m != null) memories.add(m);
                }
                if (memories.isEmpty) {
                  return _emptyState(
                    "You have ${entries.length} saved "
                    "${entries.length == 1 ? 'memory' : 'memories'} but "
                    "we couldn't load them from the feed yet. Pull to refresh.",
                  );
                }
                // Nested watch: voice-note metadata lives at
                // /voiceNotes/{recipientId}/{memoryKey}. This stream also
                // reacts to add/remove/update in real time.
                return StreamBuilder<Map<String, VoiceNoteEntry>>(
                  stream: _voiceNotes.watch(recipientId),
                  builder: (context, vnSnap) {
                    final voiceNoteByKey =
                        vnSnap.data ?? const <String, VoiceNoteEntry>{};
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 680),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: memories.length,
                          itemBuilder: (_, i) => _cardFor(
                            context,
                            memories[i],
                            recipientId: recipientId,
                            currentUid: auth.user?.uid ??
                                auth.userModel?.userId ??
                                '',
                            voiceNoteByKey: voiceNoteByKey,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _cardFor(
    BuildContext context,
    FeedModel m, {
    required String recipientId,
    required String currentUid,
    required Map<String, VoiceNoteEntry> voiceNoteByKey,
  }) {
    final scopedNote = m.key == null ? null : voiceNoteByKey[m.key];
    final desc = m.description ?? '';
    final caption =
        desc.trim().isEmpty ? 'A saved memory' : desc.split('\n').first;
    String? extract(String prefix) {
      for (final line in desc.split('\n').skip(1)) {
        if (line.startsWith(prefix)) return line.substring(prefix.length).trim();
      }
      return null;
    }

    final who = extract('Who:') ?? m.user?.displayName;
    return MemoryCard(
      caption: caption,
      who: who,
      where: extract('Where:'),
      why: extract('Why it matters:'),
      song: m.songTitle,
      hasAudio: (m.audioPath != null && m.audioPath!.isNotEmpty) ||
          (m.externalMediaUrl != null && m.externalMediaUrl!.isNotEmpty),
      imageUrl: m.imagePath,
      imageUrls: m.imagePaths,
      tags: m.tags ?? const [],
      // Prefer the scoped /voiceNotes entry; keep the legacy FeedModel
      // fields as fallback for memories written before the split.
      voiceNoteUrl: scopedNote?.url ?? m.voiceNotePath,
      voiceNoteDurationSeconds:
          scopedNote?.durationSeconds ?? m.voiceNoteDurationSeconds,
      isFavorite: true, // always true on this tab
      onFavoriteToggle: () async {
        if (m.key == null) return;
        await _favorites.remove(
          recipientId: recipientId,
          memoryKey: m.key!,
        );
      },
      onTalk: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CompanionPage(
          caption: caption,
          imageUrl: m.imagePath,
          who: who,
          where: extract('Where:'),
          why: extract('Why it matters:'),
          song: extract('Song:'),
          tags: m.tags ?? const [],
          seededPrompts: m.prompts ?? const [],
        ),
      )),
      onPlayMusic: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => MusicCaptionsPage(
          caption: caption,
          imageUrl: m.imagePath,
          song: m.songTitle,
          audioUrl: m.audioPath,
          externalMediaUrl: m.externalMediaUrl,
        ),
      )),
    );
  }

  Widget _emptyState(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: PhotoTalkPalette.primary.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.favorite_border_rounded,
              size: 60,
              color: PhotoTalkPalette.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text('No saved memories yet',
              style: PhotoTalkText.h2, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: PhotoTalkText.caption.copyWith(fontSize: 16),
          ),
        ],
      ),
    );
  }
}
