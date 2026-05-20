import 'package:flutter/material.dart';
import 'package:flutter_twitter_clone/model/feedModel.dart';
import 'package:flutter_twitter_clone/state/authState.dart';
import 'package:flutter_twitter_clone/state/feedState.dart';
import 'package:provider/provider.dart';

import 'calmModePage.dart';
import 'companionPage.dart';
import 'musicCaptionsPage.dart';
import 'photoTalkTheme.dart';
import 'widgets/memoryCard.dart';

/// "Today's Memories" feed - the primary view for the care recipient.
///
/// Pulls from the existing FeedState (FeedModel) and renders each item as a
/// photo-first memory card. Falls back to sample memories when the feed is
/// empty so the UI is always demonstrable.
class MemoriesPage extends StatelessWidget {
  const MemoriesPage({
    Key? key,
    required this.scaffoldKey,
    this.refreshIndicatorKey,
  }) : super(key: key);

  final GlobalKey<ScaffoldState> scaffoldKey;
  final GlobalKey<RefreshIndicatorState>? refreshIndicatorKey;

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PhotoTalkPalette.background,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: PhotoTalkPalette.primary,
        foregroundColor: Colors.white,
        onPressed: () =>
            Navigator.of(context).pushNamed('/UploadMemoryPage'),
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text(
          'Add a memory',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          key: refreshIndicatorKey,
          color: PhotoTalkPalette.primary,
          onRefresh: () async {
            final feedState = Provider.of<FeedState>(context, listen: false);
            feedState.getDataFromDatabase();
          },
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: false,
                floating: true,
                elevation: 0,
                backgroundColor: PhotoTalkPalette.background,
                leading: IconButton(
                  icon: const Icon(Icons.menu_rounded,
                      color: PhotoTalkPalette.textPrimary, size: 28),
                  onPressed: () => scaffoldKey.currentState?.openDrawer(),
                ),
                title: Row(
                  children: [
                    const Icon(Icons.photo_library_rounded,
                        color: PhotoTalkPalette.primary, size: 26),
                    const SizedBox(width: 8),
                    Text('PhotoTalk',
                        style: PhotoTalkText.title.copyWith(fontSize: 22)),
                  ],
                ),
                actions: [
                  IconButton(
                    tooltip: 'Calm Mode',
                    icon: const Icon(Icons.spa_outlined,
                        color: PhotoTalkPalette.accentGreen, size: 28),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CalmModePage(),
                      ),
                    ),
                  ),
                ],
              ),
              SliverToBoxAdapter(child: _header(context)),
              _memoriesList(context),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final authState = Provider.of<AuthState>(context, listen: false);
    final name = authState.userModel?.displayName?.split(' ').first ?? 'friend';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${_greeting()}, $name', style: PhotoTalkText.h1),
          const SizedBox(height: 4),
          Text(
            "Here are today's memories",
            style: PhotoTalkText.caption.copyWith(fontSize: 16),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _memoriesList(BuildContext context) {
    return Consumer<FeedState>(
      builder: (context, state, _) {
        final authState = Provider.of<AuthState>(context, listen: false);
        final List<FeedModel>? list = state.getTweetList(authState.userModel);

        if (state.isBusy && (list == null || list.isEmpty)) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        // Real feed data
        if (list != null && list.isNotEmpty) {
          return SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => _cardFromFeed(context, list[i]),
              childCount: list.length,
            ),
          );
        }

        // Fall back to sample memories so the view is always alive
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) => _cardFromSample(context, kSampleMemories[i]),
            childCount: kSampleMemories.length,
          ),
        );
      },
    );
  }

  Widget _cardFromFeed(BuildContext context, FeedModel model) {
    final caption = (model.description ?? '').trim().isEmpty
        ? 'A memory worth keeping'
        : model.description!;
    final tags = model.tags ?? const <String>[];
    final who = model.user?.displayName;
    return MemoryCard(
      caption: caption,
      who: who,
      where: null,
      why: null,
      imageUrl: model.imagePath,
      tags: tags,
      onTalk: () => _openCompanion(
        context,
        caption: caption,
        imageUrl: model.imagePath,
      ),
      onPlayMusic: () => _openMusic(
        context,
        caption: caption,
        imageUrl: model.imagePath,
      ),
    );
  }

  Widget _cardFromSample(BuildContext context, SampleMemory m) {
    return MemoryCard(
      caption: m.caption,
      who: m.who,
      where: m.where,
      why: m.why,
      imageUrl: m.imageUrl,
      song: m.song,
      tags: m.tags,
      onTalk: () => _openCompanion(
        context,
        caption: m.caption,
        imageUrl: m.imageUrl,
        why: m.why,
        who: m.who,
      ),
      onPlayMusic: () => _openMusic(
        context,
        caption: m.caption,
        imageUrl: m.imageUrl,
        song: m.song,
      ),
    );
  }

  void _openCompanion(
    BuildContext context, {
    required String caption,
    String? imageUrl,
    String? who,
    String? why,
  }) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CompanionPage(
        caption: caption,
        imageUrl: imageUrl,
        who: who,
        why: why,
      ),
    ));
  }

  void _openMusic(
    BuildContext context, {
    required String caption,
    String? imageUrl,
    String? song,
  }) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MusicCaptionsPage(
        caption: caption,
        imageUrl: imageUrl,
        song: song,
      ),
    ));
  }
}
