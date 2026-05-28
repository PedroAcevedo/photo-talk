import 'package:flutter/material.dart';
import 'package:flutter_twitter_clone/services/snippet_service.dart';
import 'package:flutter_twitter_clone/state/authState.dart';
import 'package:provider/provider.dart';

import 'photoTalkTheme.dart';

/// Family Story Snippets — short reflections captured from Companion
/// sessions, persisted in Firebase under /snippets/{userId}/{key}.
class SnippetsPage extends StatefulWidget {
  const SnippetsPage({Key? key, required this.scaffoldKey}) : super(key: key);

  final GlobalKey<ScaffoldState> scaffoldKey;

  @override
  State<SnippetsPage> createState() => _SnippetsPageState();
}

class _SnippetsPageState extends State<SnippetsPage> {
  final SnippetService _service = SnippetService();
  Future<List<StorySnippet>>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final authState = Provider.of<AuthState>(context, listen: false);
    final userId = authState.userModel?.userId;
    if (userId == null) {
      _future = Future.value(<StorySnippet>[]);
    } else {
      _future = _service.recent(userId);
    }
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
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, size: 28),
          onPressed: () => widget.scaffoldKey.currentState?.openDrawer(),
        ),
        title: Text('Story Snippets', style: PhotoTalkText.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => setState(_load),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: PhotoTalkPalette.primary,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: FutureBuilder<List<StorySnippet>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final list = snap.data ?? const <StorySnippet>[];
                final themes = _aggregateThemes(list);
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: [
                    if (themes.isNotEmpty) ...[
                      Text('Themes', style: PhotoTalkText.h2),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: themes
                            .map((t) => _ThemePill(t,
                                color: _colorForTheme(t)))
                            .toList(),
                      ),
                      const SizedBox(height: 24),
                    ],
                    Text(
                      list.isEmpty
                          ? 'No snippets yet'
                          : 'Recent snippets',
                      style: PhotoTalkText.h2,
                    ),
                    const SizedBox(height: 10),
                    if (list.isEmpty)
                      _emptyHint()
                    else
                      for (final s in list) _snippetCard(s),
                    const SizedBox(height: 24),
                    _familyStorylineCard(context),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  List<String> _aggregateThemes(List<StorySnippet> list) {
    final counts = <String, int>{};
    for (final s in list) {
      final t = (s.theme ?? '').trim();
      if (t.isEmpty) continue;
      for (final word in t.split(RegExp(r'[,/]+'))) {
        final w = word.trim();
        if (w.isEmpty) continue;
        counts[w] = (counts[w] ?? 0) + 1;
      }
    }
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(6).map((e) => e.key).toList();
  }

  Color _colorForTheme(String theme) {
    final t = theme.toLowerCase();
    if (t.contains('joy')) return PhotoTalkPalette.primary;
    if (t.contains('calm') || t.contains('comfort')) {
      return PhotoTalkPalette.accentGreen;
    }
    if (t.contains('family') || t.contains('together')) {
      return PhotoTalkPalette.accentBlue;
    }
    if (t.contains('humor')) return PhotoTalkPalette.accentLavender;
    if (t.contains('kindness') || t.contains('tender')) {
      return PhotoTalkPalette.accentRose;
    }
    return PhotoTalkPalette.accentLavender;
  }

  Widget _emptyHint() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: PhotoTalkPalette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PhotoTalkPalette.divider),
      ),
      child: Text(
        'When you chat with the Companion about a photo, short story '
        'snippets will be saved here automatically.',
        style: PhotoTalkText.body
            .copyWith(color: PhotoTalkPalette.textSecondary),
      ),
    );
  }

  Widget _snippetCard(StorySnippet s) {
    final date = _humanDate(s.createdAt);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: PhotoTalkPalette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: PhotoTalkPalette.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.format_quote_rounded,
              color: PhotoTalkPalette.primary, size: 28),
          const SizedBox(height: 6),
          Text(
            '"${s.quote}"',
            style: PhotoTalkText.bodyLarge
                .copyWith(fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (s.person != null && s.person!.isNotEmpty)
                      Text('About ${s.person}',
                          style: PhotoTalkText.chip.copyWith(
                              color: PhotoTalkPalette.textSecondary)),
                    if (s.theme != null && s.theme!.isNotEmpty)
                      Text(s.theme!, style: PhotoTalkText.caption),
                  ],
                ),
              ),
              Text(date,
                  style: PhotoTalkText.caption
                      .copyWith(color: PhotoTalkPalette.textMuted)),
            ],
          ),
        ],
      ),
    );
  }

  String _humanDate(String iso) {
    try {
      final d = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final delta = now.difference(d);
      if (delta.inDays == 0 && now.day == d.day) return 'Today';
      if (delta.inDays <= 1) return 'Yesterday';
      if (delta.inDays < 7) return '${delta.inDays} days ago';
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  Widget _familyStorylineCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: PhotoTalkPalette.accentLavender.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: PhotoTalkPalette.accentLavender.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.account_tree_outlined,
                color: PhotoTalkPalette.accentLavender),
            const SizedBox(width: 8),
            Text('Family Storyline', style: PhotoTalkText.title),
          ]),
          const SizedBox(height: 8),
          Text(
            "Moments add up. See how your family's stories, photos, and "
            "values are connecting over time.",
            style: PhotoTalkText.body,
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Coming soon')),
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: PhotoTalkPalette.accentLavender,
              side: const BorderSide(color: PhotoTalkPalette.accentLavender),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text('Open the storyline'),
          ),
        ],
      ),
    );
  }
}

class _ThemePill extends StatelessWidget {
  const _ThemePill(this.label, {required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }
}
