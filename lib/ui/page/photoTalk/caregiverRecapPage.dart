import 'package:flutter/material.dart';
import 'package:flutter_twitter_clone/services/snippet_service.dart';
import 'package:flutter_twitter_clone/state/authState.dart';
import 'package:provider/provider.dart';

import 'photoTalkTheme.dart';

/// Caregiver Recap - one-screen overview of recent Companion sessions
/// and snippets, read live from Firebase.
class CaregiverRecapPage extends StatefulWidget {
  const CaregiverRecapPage({Key? key, required this.scaffoldKey})
      : super(key: key);

  final GlobalKey<ScaffoldState> scaffoldKey;

  @override
  State<CaregiverRecapPage> createState() => _CaregiverRecapPageState();
}

class _CaregiverRecapPageState extends State<CaregiverRecapPage> {
  final SessionLogService _sessions = SessionLogService();
  final SnippetService _snippets = SnippetService();

  Future<_RecapData>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final auth = Provider.of<AuthState>(context, listen: false);
    final userId = auth.userModel?.userId;
    if (userId == null) {
      _future = Future.value(_RecapData.empty());
    } else {
      _future = _loadRecap(userId);
    }
  }

  Future<_RecapData> _loadRecap(String userId) async {
    final sessions = await _sessions.recent(userId);
    final snippets = await _snippets.recent(userId, limit: 6);
    return _RecapData(sessions: sessions, snippets: snippets);
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
        title: Text('Caregiver Recap', style: PhotoTalkText.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => setState(_load),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: FutureBuilder<_RecapData>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final d = snap.data ?? _RecapData.empty();
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  _summaryHeader(d),
                  const SizedBox(height: 20),
                  _section(title: "Today's engagement", children: [
                    _metricRow(Icons.timer_outlined, 'Total time',
                        _humanDuration(d.todaySeconds)),
                    _metricRow(Icons.photo_library_outlined, 'Photos viewed',
                        '${d.todaySessions.length}'),
                    _metricRow(Icons.chat_bubble_outline,
                        'Conversation turns', '${d.todayTurns}'),
                  ]),
                  const SizedBox(height: 16),
                  _section(
                    title: 'Most engaging',
                    children: d.topEngaging.isEmpty
                        ? [_placeholder('No sessions yet today.')]
                        : d.topEngaging
                            .map((s) => _engagingItem(
                                  s.photoCaption.isEmpty
                                      ? 'A memory'
                                      : s.photoCaption,
                                  '${_humanDuration(s.durationSeconds)} · ${s.turnCount} turns',
                                  tone: s.tone ?? 'Calm',
                                  toneColor: _toneColor(s.tone),
                                ))
                            .toList(),
                  ),
                  const SizedBox(height: 16),
                  _section(
                    title: 'New snippets captured',
                    children: d.snippets.isEmpty
                        ? [_placeholder('No snippets yet today.')]
                        : d.snippets
                            .take(4)
                            .map((s) => _MiniSnippet('"${s.quote}"'))
                            .toList(),
                  ),
                  const SizedBox(height: 16),
                  _section(
                    title: 'Mode that worked best',
                    children: const [_ModeChipRowStatic()],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _summaryHeader(_RecapData d) {
    final hasActivity = d.todaySessions.isNotEmpty;
    final headline = hasActivity
        ? "Today's session went well"
        : 'No sessions yet today';
    final subtitle = hasActivity
        ? '${d.todaySessions.length} memor${d.todaySessions.length == 1 ? "y" : "ies"} viewed · ${d.todayTurns} turns'
        : 'Open Today\'s Memories and tap "Talk about it" to start one.';
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
                Text(headline, style: PhotoTalkText.title),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: PhotoTalkText.caption.copyWith(fontSize: 15)),
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

  Widget _placeholder(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(text,
          style: PhotoTalkText.body
              .copyWith(color: PhotoTalkPalette.textSecondary)),
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

  Color _toneColor(String? tone) {
    switch ((tone ?? '').toLowerCase()) {
      case 'joyful':
        return PhotoTalkPalette.primary;
      case 'calm':
        return PhotoTalkPalette.accentGreen;
      case 'reflective':
        return PhotoTalkPalette.accentBlue;
      case 'tender':
        return PhotoTalkPalette.accentLavender;
      case 'mixed':
        return PhotoTalkPalette.accentRose;
      default:
        return PhotoTalkPalette.accentGreen;
    }
  }

  String _humanDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final m = seconds ~/ 60;
    return '${m} min';
  }
}

class _ModeChipRowStatic extends StatelessWidget {
  const _ModeChipRowStatic();

  Widget _chip(String label, IconData icon, Color color, bool selected) {
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

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 8, runSpacing: 8, children: [
      _chip('Calm Mode', Icons.spa_outlined, PhotoTalkPalette.accentGreen,
          true),
      _chip('Chat Mode', Icons.chat_bubble_outline,
          PhotoTalkPalette.primary, false),
      _chip('Music + Captions', Icons.music_note_rounded,
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

class _RecapData {
  final List<SessionLog> sessions;
  final List<StorySnippet> snippets;

  _RecapData({required this.sessions, required this.snippets});

  factory _RecapData.empty() => _RecapData(sessions: [], snippets: []);

  List<SessionLog> get todaySessions {
    final today = DateTime.now().toLocal();
    return sessions.where((s) {
      try {
        final d = DateTime.parse(s.startedAt).toLocal();
        return d.year == today.year &&
            d.month == today.month &&
            d.day == today.day;
      } catch (_) {
        return false;
      }
    }).toList();
  }

  int get todaySeconds =>
      todaySessions.fold<int>(0, (acc, s) => acc + s.durationSeconds);

  int get todayTurns =>
      todaySessions.fold<int>(0, (acc, s) => acc + s.turnCount);

  /// Top sessions today by turn count (proxy for engagement).
  List<SessionLog> get topEngaging {
    final list = [...todaySessions];
    list.sort((a, b) => b.turnCount.compareTo(a.turnCount));
    return list.take(3).toList();
  }
}
