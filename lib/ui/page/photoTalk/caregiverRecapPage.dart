import 'package:flutter/material.dart';

import 'photoTalkTheme.dart';

/// Caregiver Recap - one-screen overview of the most recent session(s).
/// Designed to be skimmable in under a minute.
class CaregiverRecapPage extends StatelessWidget {
  const CaregiverRecapPage({Key? key, required this.scaffoldKey})
      : super(key: key);

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
        title: Text('Caregiver Recap', style: PhotoTalkText.title),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              _summaryHeader(),
          const SizedBox(height: 20),
          _section(
            title: 'Engagement',
            children: [
              _metricRow(Icons.timer_outlined, 'Session length', '14 min'),
              _metricRow(Icons.photo_library_outlined, 'Photos viewed', '6'),
              _metricRow(
                  Icons.chat_bubble_outline, 'Companion turns', '11'),
            ],
          ),
          const SizedBox(height: 16),
          _section(
            title: 'Most engaging',
            children: [
              _engagingItem(
                'Lake George, summer 1978',
                'Spent 5 min · Talked warmly about Mom',
                tone: 'Joyful',
                toneColor: PhotoTalkPalette.accentGreen,
              ),
              _engagingItem(
                "Dad's tomatoes",
                'Spent 3 min · Smiled at the garden',
                tone: 'Calm',
                toneColor: PhotoTalkPalette.accentBlue,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _section(
            title: 'Topics to soften next time',
            children: [
              _avoidItem(
                  'Photos from the 2008 move — felt unsettling.',
                  PhotoTalkPalette.accentRose),
              _avoidItem(
                  'Questions about dates and years — caused pauses.',
                  PhotoTalkPalette.accentRose),
            ],
          ),
          const SizedBox(height: 16),
          _section(
            title: 'Mode that worked best',
            children: [
              _modeChipRow(),
            ],
          ),
          const SizedBox(height: 16),
          _section(
            title: 'New snippets captured',
            children: const [
              _MiniSnippet(
                  '"Mom always packed lemonade for the lake trips."'),
              _MiniSnippet(
                  '"The same Christmas storybook, every year."'),
            ],
          ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: PhotoTalkPalette.accentRose.withOpacity(0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: PhotoTalkPalette.accentRose.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: PhotoTalkPalette.accentRose,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.favorite, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Today's session went well",
                    style: PhotoTalkText.title),
                const SizedBox(height: 4),
                Text(
                  'Calm and engaged throughout. A few moments of pure joy.',
                  style: PhotoTalkText.caption.copyWith(fontSize: 15),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section({required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: PhotoTalkPalette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: PhotoTalkPalette.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: PhotoTalkText.title),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _metricRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: PhotoTalkPalette.textSecondary),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: PhotoTalkText.body)),
          Text(value,
              style: PhotoTalkText.body
                  .copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _engagingItem(String title, String detail,
      {required String tone, required Color toneColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: PhotoTalkText.body
                        .copyWith(fontWeight: FontWeight.w600)),
                Text(detail, style: PhotoTalkText.caption),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: toneColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(tone,
                style: TextStyle(
                    color: toneColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _avoidItem(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: PhotoTalkText.body)),
        ],
      ),
    );
  }

  Widget _modeChipRow() {
    Widget chip(String label, IconData icon, Color color, bool selected) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : PhotoTalkPalette.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: selected ? Colors.white : color),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                  color: selected ? Colors.white : color,
                  fontWeight: FontWeight.w600,
                )),
          ],
        ),
      );
    }

    return Wrap(spacing: 8, runSpacing: 8, children: [
      chip('Calm Mode', Icons.spa_outlined, PhotoTalkPalette.accentGreen,
          true),
      chip('Chat Mode', Icons.chat_bubble_outline,
          PhotoTalkPalette.primary, false),
      chip('Music + Captions', Icons.music_note_rounded,
          PhotoTalkPalette.accentBlue, false),
    ]);
  }
}

class _MiniSnippet extends StatelessWidget {
  const _MiniSnippet(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.format_quote_rounded,
              color: PhotoTalkPalette.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: PhotoTalkText.body
                    .copyWith(fontStyle: FontStyle.italic)),
          ),
        ],
      ),
    );
  }
}
