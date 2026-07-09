import 'package:flutter/material.dart';
import 'package:flutter_twitter_clone/model/feedModel.dart';
import 'package:flutter_twitter_clone/services/snippet_service.dart';
import 'package:flutter_twitter_clone/state/authState.dart';
import 'package:flutter_twitter_clone/state/feedState.dart';
import 'package:provider/provider.dart';

import 'photoTalkTheme.dart';
import 'widgets/generic_avatar.dart';

/// Family Storyline — the "story-as-a-gift" people map.
///
/// Aggregates the care recipient's Story Snippets (which carry `person`,
/// `quote`, `theme`, `photoUrl`) plus the memories in the feed (which
/// carry a `Who:` line in the description) into a list of *people*.
///
/// Tap a person to see all quotes captured about them and every photo
/// they appear in, grouped by memory.
class FamilyStorylinePage extends StatefulWidget {
  const FamilyStorylinePage({Key? key}) : super(key: key);

  static Route<T> getRoute<T>() {
    return MaterialPageRoute(builder: (_) => const FamilyStorylinePage());
  }

  @override
  State<FamilyStorylinePage> createState() => _FamilyStorylinePageState();
}

class _FamilyStorylinePageState extends State<FamilyStorylinePage> {
  final SnippetService _snippets = SnippetService();
  Future<_StorylineData>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final auth = Provider.of<AuthState>(context, listen: false);
    final feed = Provider.of<FeedState>(context, listen: false);
    final recipientId = auth.userModel?.linkedRecipientId ??
        auth.userModel?.userId ??
        auth.user?.uid;
    if (recipientId == null) {
      _future = Future.value(_StorylineData.empty());
      return;
    }
    _future = _loadFor(recipientId, feed);
  }

  Future<_StorylineData> _loadFor(
      String recipientId, FeedState feed) async {
    final snippets = await _snippets.recent(recipientId, limit: 100);
    // Only include memories that live under this recipient.
    final memories = (feed.feedList ?? const <FeedModel>[])
        .where((m) =>
            (m.careRecipientId == null || m.careRecipientId!.isEmpty)
                ? m.userId == recipientId
                : m.careRecipientId == recipientId)
        .toList();
    return _StorylineData.build(snippets: snippets, memories: memories);
  }

  Future<void> _refresh() async {
    setState(_load);
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PhotoTalkPalette.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: PhotoTalkPalette.background,
        foregroundColor: PhotoTalkPalette.textPrimary,
        title: Text('Family Storyline', style: PhotoTalkText.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => setState(_load),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: PhotoTalkPalette.primary,
        onRefresh: _refresh,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: FutureBuilder<_StorylineData>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final data = snap.data ?? _StorylineData.empty();
                if (data.people.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    children: [_empty()],
                  );
                }
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: [
                    _header(data),
                    const SizedBox(height: 20),
                    for (final p in data.people) _personCard(context, p),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // ---- pieces --------------------------------------------------------

  Widget _header(_StorylineData data) {
    final people = data.people.length;
    final quotes = data.people.fold<int>(0, (a, p) => a + p.quotes.length);
    final photos = data.people.fold<int>(0, (a, p) => a + p.photos.length);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: PhotoTalkPalette.accentLavender.withOpacity(0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: PhotoTalkPalette.accentLavender.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.account_tree_outlined,
                color: PhotoTalkPalette.accentLavender),
            const SizedBox(width: 8),
            Text('Your family in stories', style: PhotoTalkText.title),
          ]),
          const SizedBox(height: 8),
          Text(
            'Moments accumulate here. As family adds memories and the '
            'Companion captures snippets, people appear alongside their '
            'photos and the words that live between them.',
            style: PhotoTalkText.body,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _headerStat('$people', 'people'),
              const SizedBox(width: 24),
              _headerStat('$quotes', 'quotes'),
              const SizedBox(width: 24),
              _headerStat('$photos', 'photos'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerStat(String n, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(n,
            style: PhotoTalkText.h2.copyWith(
                color: PhotoTalkPalette.accentLavender, fontSize: 26)),
        Text(label, style: PhotoTalkText.caption),
      ],
    );
  }

  Widget _empty() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: PhotoTalkPalette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: PhotoTalkPalette.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.account_tree_outlined,
                color: PhotoTalkPalette.accentLavender, size: 28),
            const SizedBox(width: 8),
            Text('Your storyline is empty for now',
                style: PhotoTalkText.title),
          ]),
          const SizedBox(height: 8),
          Text(
            'When family members upload a memory and note who is in the '
            'photo — or when the Companion captures a snippet about '
            'someone — that person will appear here with their photos '
            'and the words shared about them.',
            style: PhotoTalkText.body,
          ),
        ],
      ),
    );
  }

  Widget _personCard(BuildContext context, _Person p) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: PhotoTalkPalette.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => _PersonDetailPage(person: p),
          )),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: PhotoTalkPalette.divider),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _personAvatar(p),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.displayName, style: PhotoTalkText.title),
                      const SizedBox(height: 4),
                      Text(
                        _summaryLine(p),
                        style: PhotoTalkText.caption.copyWith(fontSize: 14),
                      ),
                      if (p.themes.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: p.themes
                              .take(4)
                              .map((t) => _themePill(t))
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: PhotoTalkPalette.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _personAvatar(_Person p) {
    // Use the person's first photo as the avatar if we have one; otherwise
    // fall back to the generic avatar so every card has weight.
    final firstPhoto =
        p.photos.isNotEmpty ? p.photos.first.imageUrl : null;
    if (firstPhoto == null) {
      return const GenericAvatar(size: 56);
    }
    return ClipOval(
      child: SizedBox(
        width: 56,
        height: 56,
        child: Image.network(
          firstPhoto,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const GenericAvatar(size: 56),
        ),
      ),
    );
  }

  String _summaryLine(_Person p) {
    final parts = <String>[];
    if (p.photos.isNotEmpty) {
      parts.add('${p.photos.length} '
          '${p.photos.length == 1 ? "photo" : "photos"}');
    }
    if (p.quotes.isNotEmpty) {
      parts.add('${p.quotes.length} '
          '${p.quotes.length == 1 ? "quote" : "quotes"}');
    }
    return parts.isEmpty ? 'No moments yet' : parts.join(' · ');
  }

  Widget _themePill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: PhotoTalkPalette.accentLavender.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: PhotoTalkPalette.accentLavender.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: PhotoTalkPalette.accentLavender,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

/// Per-person detail: quotes on top, photos below.
class _PersonDetailPage extends StatelessWidget {
  const _PersonDetailPage({required this.person});
  final _Person person;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PhotoTalkPalette.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: PhotoTalkPalette.background,
        foregroundColor: PhotoTalkPalette.textPrimary,
        title: Text(person.displayName, style: PhotoTalkText.title),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              _header(),
              const SizedBox(height: 20),
              if (person.quotes.isNotEmpty) ...[
                Text('Words shared', style: PhotoTalkText.h2),
                const SizedBox(height: 10),
                for (final s in person.quotes) _quoteCard(s),
                const SizedBox(height: 24),
              ],
              if (person.photos.isNotEmpty) ...[
                Text('Photos', style: PhotoTalkText.h2),
                const SizedBox(height: 10),
                _photoGrid(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: PhotoTalkPalette.accentLavender.withOpacity(0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: PhotoTalkPalette.accentLavender.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.people_alt_outlined,
              color: PhotoTalkPalette.accentLavender, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(person.displayName, style: PhotoTalkText.title),
                const SizedBox(height: 4),
                Text(
                  '${person.photos.length} photo${person.photos.length == 1 ? "" : "s"} · '
                  '${person.quotes.length} quote${person.quotes.length == 1 ? "" : "s"}',
                  style: PhotoTalkText.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _quoteCard(StorySnippet s) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PhotoTalkPalette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PhotoTalkPalette.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.format_quote_rounded,
              color: PhotoTalkPalette.primary),
          const SizedBox(height: 4),
          Text(
            '"${s.quote}"',
            style: PhotoTalkText.bodyLarge
                .copyWith(fontStyle: FontStyle.italic),
          ),
          if ((s.theme ?? '').isNotEmpty || (s.photoCaption ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                [
                  if ((s.photoCaption ?? '').isNotEmpty)
                    'From "${s.photoCaption}"',
                  if ((s.theme ?? '').isNotEmpty) s.theme!,
                ].join(' · '),
                style: PhotoTalkText.caption,
              ),
            ),
        ],
      ),
    );
  }

  Widget _photoGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: person.photos
          .map(
            (ph) => ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                ph.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: PhotoTalkPalette.background,
                  alignment: Alignment.center,
                  child: const Icon(Icons.photo_outlined,
                      color: PhotoTalkPalette.textMuted),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

// ---- data model ------------------------------------------------------

class _StorylineData {
  final List<_Person> people;
  const _StorylineData({required this.people});
  factory _StorylineData.empty() => const _StorylineData(people: []);

  static _StorylineData build({
    required List<StorySnippet> snippets,
    required List<FeedModel> memories,
  }) {
    // Normalize "person names" so casing and whitespace don't split someone.
    String norm(String raw) => raw.trim().toLowerCase();

    final map = <String, _Person>{};

    _Person entryFor(String raw) {
      final key = norm(raw);
      return map.putIfAbsent(
        key,
        () => _Person(
          displayName: raw.trim(),
          themes: <String>{},
          quotes: <StorySnippet>[],
          photos: <_PersonPhoto>[],
        ),
      );
    }

    // 1) Snippet-driven people.
    for (final s in snippets) {
      final raw = (s.person ?? '').trim();
      if (raw.isEmpty) continue;
      // A snippet may list multiple people separated by commas.
      for (final chunk in raw.split(RegExp(r'[,&]|\band\b'))) {
        final name = chunk.trim();
        if (name.isEmpty) continue;
        final p = entryFor(name);
        p.quotes.add(s);
        if ((s.theme ?? '').trim().isNotEmpty) {
          for (final w in s.theme!.split(RegExp(r'[,/]'))) {
            final t = w.trim();
            if (t.isNotEmpty) p.themes.add(t);
          }
        }
        if ((s.photoUrl ?? '').isNotEmpty) {
          // Attach snippet photo to the person if not already there.
          if (!p.photos.any((ph) => ph.imageUrl == s.photoUrl)) {
            p.photos.add(_PersonPhoto(
              imageUrl: s.photoUrl!,
              caption: s.photoCaption ?? '',
            ));
          }
        }
      }
    }

    // 2) Memory-driven people (Who: line in the description).
    for (final m in memories) {
      final who = _extractWho(m.description ?? '');
      if (who == null) continue;
      final imageUrls = _imageUrlsOf(m);
      final caption = _captionOf(m.description ?? '');
      for (final chunk in who.split(RegExp(r'[,&]|\band\b'))) {
        final name = chunk.trim();
        if (name.isEmpty) continue;
        final p = entryFor(name);
        for (final url in imageUrls) {
          if (!p.photos.any((ph) => ph.imageUrl == url)) {
            p.photos.add(_PersonPhoto(
              imageUrl: url,
              caption: caption,
            ));
          }
        }
      }
    }

    // Sort by total signal (photos + quotes), descending.
    final ordered = map.values.toList()
      ..sort((a, b) =>
          (b.photos.length + b.quotes.length)
              .compareTo(a.photos.length + a.quotes.length));
    return _StorylineData(people: ordered);
  }

  static String? _extractWho(String description) {
    if (description.isEmpty) return null;
    for (final line in description.split('\n')) {
      if (line.startsWith('Who:')) {
        final s = line.substring('Who:'.length).trim();
        return s.isEmpty ? null : s;
      }
    }
    return null;
  }

  static String _captionOf(String description) {
    if (description.isEmpty) return '';
    return description.split('\n').first;
  }

  static List<String> _imageUrlsOf(FeedModel m) {
    final list = m.imagePaths;
    if (list != null && list.isNotEmpty) {
      return list.where((u) => u.isNotEmpty).toList();
    }
    if (m.imagePath != null && m.imagePath!.isNotEmpty) {
      return [m.imagePath!];
    }
    return const [];
  }
}

class _Person {
  final String displayName;
  final Set<String> themes;
  final List<StorySnippet> quotes;
  final List<_PersonPhoto> photos;

  _Person({
    required this.displayName,
    required this.themes,
    required this.quotes,
    required this.photos,
  });
}

class _PersonPhoto {
  final String imageUrl;
  final String caption;
  const _PersonPhoto({required this.imageUrl, required this.caption});
}
