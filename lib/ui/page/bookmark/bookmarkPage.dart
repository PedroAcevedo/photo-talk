import 'package:flutter/material.dart';
import 'package:flutter_twitter_clone/model/feedModel.dart';
import 'package:flutter_twitter_clone/state/bookmarkState.dart';
import 'package:flutter_twitter_clone/ui/page/photoTalk/companionPage.dart';
import 'package:flutter_twitter_clone/ui/page/photoTalk/musicCaptionsPage.dart';
import 'package:flutter_twitter_clone/ui/page/photoTalk/photoTalkTheme.dart';
import 'package:flutter_twitter_clone/ui/page/photoTalk/widgets/memoryCard.dart';
import 'package:provider/provider.dart';

/// Saved Memories — the PhotoTalk-styled replacement for the bookmark page.
/// Reuses the existing BookmarkState which already loads bookmarked items
/// from Firebase, but renders them as photo-first memory cards.
class BookmarkPage extends StatelessWidget {
  const BookmarkPage({Key? key}) : super(key: key);

  static Route<T> getRoute<T>() {
    return MaterialPageRoute(
      builder: (_) {
        return ChangeNotifierProvider(
          create: (_) => BookmarkState(),
          child: const BookmarkPage(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PhotoTalkPalette.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: PhotoTalkPalette.background,
        foregroundColor: PhotoTalkPalette.textPrimary,
        title: Text('Saved memories', style: PhotoTalkText.title),
      ),
      body: const _BookmarkBody(),
    );
  }
}

class _BookmarkBody extends StatelessWidget {
  const _BookmarkBody({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final state = context.watch<BookmarkState>();
    final list = state.tweetList;

    if (state.isbusy) {
      return const Center(child: CircularProgressIndicator());
    }
    if (list == null || list.isEmpty) {
      return _emptyState(context);
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: list.length,
          itemBuilder: (_, i) => _cardFor(context, list[i]),
        ),
      ),
    );
  }

  Widget _cardFor(BuildContext context, FeedModel m) {
    final caption = (m.description ?? '').trim().isEmpty
        ? 'A saved memory'
        : m.description!.split('\n').first;
    return MemoryCard(
      caption: caption,
      who: m.user?.displayName,
      song: m.songTitle,
      hasAudio: m.audioPath != null && m.audioPath!.isNotEmpty,
      imageUrl: m.imagePath,
      imageUrls: m.imagePaths,
      tags: m.tags ?? const [],
      onTalk: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CompanionPage(
          caption: caption,
          imageUrl: m.imagePath,
          who: m.user?.displayName,
        ),
      )),
      onPlayMusic: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => MusicCaptionsPage(
          caption: caption,
          imageUrl: m.imagePath,
          song: m.songTitle,
          audioUrl: m.audioPath,
        ),
      )),
    );
  }

  Widget _emptyState(BuildContext context) {
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
              Icons.bookmark_outline_rounded,
              size: 60,
              color: PhotoTalkPalette.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text('No saved memories yet',
              style: PhotoTalkText.h2, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            'Memories you save will live here, ready to revisit.',
            textAlign: TextAlign.center,
            style: PhotoTalkText.caption.copyWith(fontSize: 16),
          ),
        ],
      ),
    );
  }
}
