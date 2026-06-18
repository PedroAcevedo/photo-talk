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
    // Caregiver/family see the recap for their linked care recipient.
    final userId = auth.userModel?.linkedRecipientId ??
        auth.userModel?.userId ??
        auth.user?.uid;
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
                    title: 'Activity over the last 7 days',
                    children: [
                      _TrendChart(buckets: d.weekBuckets),
                      const SizedBox(height: 6),
                      Text(
                        'Sessions per day. Tap a memory in Today\'s Memories to start one.',
                        style: PhotoTalkText.caption,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _section(
                    title: 'Topics to soften',
                    children: d.topicsToSoften.isEmpty
                        ? [
                            _placeholder(
                                'No topics flagged from recent sessions.')
                          ]
                        : d.topicsToSoften
                            .map((t) => _SoftenItem(t))
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

  /// Last 7 days of session counts (index 0 = today, 6 = six days ago).
  /// Counts only sessions where the person actually engaged (turnCount > 0)
  /// so an accidental open doesn't inflate the chart.
  List<_DayBucket> get weekBuckets {
    final now = DateTime.now().toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final buckets = List.generate(7, (i) {
      final day = today.subtract(Duration(days: i));
      return _DayBucket(day: day, count: 0);
    });
    for (final s in sessions) {
      try {
        final d = DateTime.parse(s.startedAt).toLocal();
        final day = DateTime(d.year, d.month, d.day);
        final offset = today.difference(day).inDays;
        if (offset >= 0 && offset < 7 && s.turnCount > 0) {
          buckets[offset] = buckets[offset].increment();
        }
      } catch (_) {
        // ignore malformed timestamps
      }
    }
    // Oldest on the left → newest on the right (chart reads naturally).
    return buckets.reversed.toList();
  }

  /// Photo captions whose recent sessions skewed mixed or distressing.
  /// Heuristic: tone == 'Mixed' OR (turnCount low AND duration short).
  List<String> get topicsToSoften {
    final flagged = <String>{};
    for (final s in sessions) {
      final caption = s.photoCaption.trim();
      if (caption.isEmpty) continue;
      final tone = (s.tone ?? '').toLowerCase();
      final shortAndQuiet = s.turnCount > 0 &&
          s.turnCount <= 2 &&
          s.durationSeconds <= 60;
      if (tone == 'mixed' || shortAndQuiet) {
        flagged.add(caption);
      }
      if (flagged.length >= 3) break;
    }
    return flagged.toList();
  }
}

class _DayBucket {
  final DateTime day;
  final int count;
  const _DayBucket({required this.day, required this.count});
  _DayBucket increment() => _DayBucket(day: day, count: count + 1);

  String get shortLabel {
    const labels = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
    return labels[day.weekday - 1];
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.buckets});
  final List<_DayBucket> buckets;

  @override
  Widget build(BuildContext context) {
    final maxCount =
        buckets.fold<int>(0, (a, b) => b.count > a ? b.count : a);
    if (maxCount == 0) {
      // Brand-new account: nothing to plot. Replace the row of dead bars
      // with a calm placeholder so it doesn't look like the chart broke.
      return Container(
        height: 120,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: PhotoTalkPalette.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: PhotoTalkPalette.divider),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.show_chart_rounded,
                color: PhotoTalkPalette.textMuted, size: 32),
            const SizedBox(height: 8),
            Text(
              'No Companion sessions in the last 7 days yet.',
              textAlign: TextAlign.center,
              style: PhotoTalkText.caption
                  .copyWith(color: PhotoTalkPalette.textSecondary),
            ),
          ],
        ),
      );
    }
    return SizedBox(
      height: 120,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: buckets.map((b) {
          final fraction = maxCount == 0 ? 0.0 : b.count / maxCount;
          final isToday =
              b.day.day == DateTime.now().day && b.day.month == DateTime.now().month;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Bar.
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor: fraction == 0 ? 0.04 : fraction,
                        child: Container(
                          decoration: BoxDecoration(
                            color: b.count == 0
                                ? PhotoTalkPalette.divider
                                : (isToday
                                    ? PhotoTalkPalette.primary
                                    : PhotoTalkPalette.accentBlue),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Count above the day label so caregivers can read at a glance.
                  Text('${b.count}',
                      style: PhotoTalkText.caption
                          .copyWith(fontSize: 12, fontWeight: FontWeight.w600)),
                  Text(b.shortLabel,
                      style: PhotoTalkText.caption.copyWith(fontSize: 12)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SoftenItem extends StatelessWidget {
  const _SoftenItem(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline,
              color: PhotoTalkPalette.accentRose),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: PhotoTalkText.body,
            ),
          ),
        ],
      ),
    );
  }
}
