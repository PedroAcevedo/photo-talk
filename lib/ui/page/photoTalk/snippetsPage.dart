import 'package:firebase_core/firebase_core.dart';
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
  String? _activeUserId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final authState = Provider.of<AuthState>(context, listen: false);
    // Use the profile model's userId if loaded; otherwise fall back to the
    // raw Firebase Auth UID so reads start even before the profile fetch.
    final userId =
        authState.userModel?.userId ?? authState.user?.uid;
    _activeUserId = userId;
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

                // If the read errored (most often permission-denied or
                // no databaseURL), show the actual reason so it's clear
                // what to fix in Firebase.
                if (snap.hasError) {
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    children: [
                      _errorBanner(snap.error!),
                      const SizedBox(height: 16),
                      _diagnosticsCard(),
                    ],
                  );
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
                    if (list.isEmpty) ...[
                      _emptyHint(),
                      const SizedBox(height: 16),
                      _diagnosticsCard(),
                    ] else
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

  Widget _errorBanner(Object error) {
    String headline = "Couldn't read snippets from Firebase";
    String detail = error.toString();
    if (error is FirebaseException) {
      headline = 'Firebase ${error.plugin} error: ${error.code}';
      detail = error.message ?? detail;
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PhotoTalkPalette.accentRose.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: PhotoTalkPalette.accentRose.withOpacity(0.4)),
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
                Text(headline,
                    style: PhotoTalkText.body
                        .copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(detail, style: PhotoTalkText.caption.copyWith(fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _diagnosticsCard() {
    // Helps verify exactly which database path the app is asking for.
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PhotoTalkPalette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PhotoTalkPalette.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.info_outline,
                color: PhotoTalkPalette.textSecondary, size: 18),
            const SizedBox(width: 6),
            Text('Where this tab reads from',
                style: PhotoTalkText.chip.copyWith(
                    color: PhotoTalkPalette.textSecondary, fontSize: 13)),
          ]),
          const SizedBox(height: 6),
          SelectableText(
            _activeUserId == null
                ? '/snippets/<NO USER>'
                : '/snippets/$_activeUserId',
            style: PhotoTalkText.caption
                .copyWith(fontFamily: 'monospace', fontSize: 13),
          ),
        ],
      ),
    );
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
