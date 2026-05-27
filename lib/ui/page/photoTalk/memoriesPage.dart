import 'dart:async';

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
/// photo-first memory card. If the database call doesn't come back within
/// a few seconds we stop showing the spinner and surface the empty state
/// (plus a small banner) so the user is never stuck on a loading dot.
class MemoriesPage extends StatefulWidget {
  const MemoriesPage({
    Key? key,
    required this.scaffoldKey,
    this.refreshIndicatorKey,
  }) : super(key: key);

  final GlobalKey<ScaffoldState> scaffoldKey;
  final GlobalKey<RefreshIndicatorState>? refreshIndicatorKey;

  @override
  State<MemoriesPage> createState() => _MemoriesPageState();
}

class _MemoriesPageState extends State<MemoriesPage> {
  Timer? _loadingTimeout;
  bool _timedOut = false;

  @override
  void initState() {
    super.initState();
    // If the feed query hasn't come back within 5s, give up on the spinner.
    _loadingTimeout = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _timedOut = true);
    });
  }

  @override
  void dispose() {
    _loadingTimeout?.cancel();
    super.dispose();
  }

  void _retry(BuildContext context) {
    setState(() => _timedOut = false);
    _loadingTimeout?.cancel();
    _loadingTimeout = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _timedOut = true);
    });
    Provider.of<FeedState>(context, listen: false).getDataFromDatabase();
  }

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
          key: widget.refreshIndicatorKey,
          color: PhotoTalkPalette.primary,
          onRefresh: () async {
            _retry(context);
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
                  onPressed: () => widget.scaffoldKey.currentState?.openDrawer(),
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

        // Real feed data wins immediately and clears any timeout banner.
        if (list != null && list.isNotEmpty) {
          if (_timedOut) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _timedOut = false);
            });
          }
          return SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => _cardFromFeed(context, list[i]),
              childCount: list.length,
            ),
          );
        }

        // Still loading and we haven't timed out yet → small inline spinner.
        if (state.isBusy && !_timedOut) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        // Otherwise: empty state. If we timed out while still busy, add a
        // small banner so the user understands the database isn't reachable.
        return SliverFillRemaining(
          hasScrollBody: false,
          child: _emptyState(context, showOfflineBanner: state.isBusy),
        );
      },
    );
  }

  Widget _emptyState(BuildContext context,
      {bool showOfflineBanner = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
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
              Icons.photo_library_outlined,
              size: 60,
              color: PhotoTalkPalette.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text('No photos today',
              textAlign: TextAlign.center, style: PhotoTalkText.h2),
          const SizedBox(height: 8),
          Text(
            'When family adds a memory, it will appear here.',
            textAlign: TextAlign.center,
            style: PhotoTalkText.caption.copyWith(fontSize: 16),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () =>
                Navigator.of(context).pushNamed('/UploadMemoryPage'),
            icon: const Icon(Icons.add_a_photo_outlined),
            label: const Text('Add a memory'),
            style: ElevatedButton.styleFrom(
              backgroundColor: PhotoTalkPalette.primary,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          if (showOfflineBanner) ...[
            const SizedBox(height: 32),
            _offlineBanner(context),
          ],
        ],
      ),
    );
  }

  Widget _offlineBanner(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: PhotoTalkPalette.accentRose.withOpacity(0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: PhotoTalkPalette.accentRose.withOpacity(0.4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.cloud_off_outlined,
                color: PhotoTalkPalette.accentRose),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Couldn't reach the memories database",
                      style: PhotoTalkText.body
                          .copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    'Check that Realtime Database is enabled in your Firebase project, and that the security rules allow access.',
                    style: PhotoTalkText.caption.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: PhotoTalkPalette.accentRose,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => _retry(context),
                    child: const Text('Try again',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
