import 'package:flutter/material.dart';

import 'photoTalkTheme.dart';

/// Family Story Snippets - short reflections, themes, and values captured
/// from conversations. Sample data is used for the UI demo; in production
/// these would be persisted alongside FeedModel items.
class SnippetsPage extends StatelessWidget {
  const SnippetsPage({Key? key, required this.scaffoldKey}) : super(key: key);

  final GlobalKey<ScaffoldState> scaffoldKey;

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
          onPressed: () => scaffoldKey.currentState?.openDrawer(),
        ),
        title: Text('Story Snippets', style: PhotoTalkText.title),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Text('Themes', style: PhotoTalkText.h2),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _ThemePill('Humor', color: PhotoTalkPalette.primary),
              _ThemePill('Kindness', color: PhotoTalkPalette.accentGreen),
              _ThemePill('Family',
                  color: PhotoTalkPalette.accentBlue),
              _ThemePill('Hard work',
                  color: PhotoTalkPalette.accentLavender),
              _ThemePill('Togetherness',
                  color: PhotoTalkPalette.accentRose),
            ],
          ),
          const SizedBox(height: 24),
          Text('Recent snippets', style: PhotoTalkText.h2),
          const SizedBox(height: 10),
          _snippetCard(
            quote: '"Mom always packed lemonade for the lake trips."',
            person: 'About Mom',
            theme: 'Family · Joy',
            date: 'Today',
          ),
          _snippetCard(
            quote: '"Dad was so proud of his tomatoes — every single year."',
            person: 'About Dad',
            theme: 'Pride · Home',
            date: 'Yesterday',
          ),
          _snippetCard(
            quote: '"The same Christmas storybook, every year."',
            person: 'About Ellie and Sam',
            theme: 'Celebration · Comfort',
            date: '3 days ago',
          ),
              const SizedBox(height: 24),
              _familyStorylineCard(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _snippetCard({
    required String quote,
    required String person,
    required String theme,
    required String date,
  }) {
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
          Text(quote,
              style: PhotoTalkText.bodyLarge
                  .copyWith(fontStyle: FontStyle.italic)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(person,
                        style: PhotoTalkText.chip
                            .copyWith(color: PhotoTalkPalette.textSecondary)),
                    Text(theme, style: PhotoTalkText.caption),
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
            'Moments add up. See how your family\'s stories, photos, and values are connecting over time.',
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
