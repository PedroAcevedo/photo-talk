import 'package:flutter/material.dart';
import 'package:flutter_twitter_clone/model/feedModel.dart';
import 'package:flutter_twitter_clone/services/companion_service.dart';
import 'package:flutter_twitter_clone/services/snippet_service.dart';
import 'package:flutter_twitter_clone/state/authState.dart';
import 'package:flutter_twitter_clone/state/feedState.dart';
import 'package:provider/provider.dart';

import 'photoTalkTheme.dart';

/// AI Companion view - a soft, supportive conversation grounded in a photo.
/// Now backed by [CompanionService] (OpenAI gpt-4o-mini) with a deterministic
/// fallback when OPENAI_API_KEY isn't set.
///
/// On close, automatically asks GPT to summarize the conversation as a
/// Story Snippet (saved to RTDB) and writes a brief SessionLog for the
/// caregiver recap.
class CompanionPage extends StatefulWidget {
  const CompanionPage({
    Key? key,
    required this.caption,
    this.imageUrl,
    this.who,
    this.where,
    this.why,
    this.song,
    this.tags = const [],
  }) : super(key: key);

  final String caption;
  final String? imageUrl;
  final String? who;
  final String? where;
  final String? why;
  final String? song;
  final List<String> tags;

  @override
  State<CompanionPage> createState() => _CompanionPageState();
}

class _CompanionPageState extends State<CompanionPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<_Message> _messages = [];

  final CompanionService _service = CompanionService();
  final SnippetService _snippets = SnippetService();
  final SessionLogService _sessionLogs = SessionLogService();

  late final CompanionPhotoContext _photo;
  late final DateTime _sessionStart;
  bool _awaitingReply = false;
  bool _sessionEnded = false;

  @override
  void initState() {
    super.initState();
    _sessionStart = DateTime.now();
    _photo = CompanionPhotoContext(
      caption: widget.caption,
      who: widget.who,
      where: widget.where,
      why: widget.why,
      song: widget.song,
      tags: widget.tags,
      imageUrl: widget.imageUrl,
    );
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() => _awaitingReply = true);
    final opening = await _service.openingPrompt(_photo);
    if (!mounted) return;
    setState(() {
      _messages.add(_Message.companion(opening));
      _awaitingReply = false;
    });
    _scrollToEnd();
  }

  static const List<String> _gentlePrompts = [
    "How does this picture make you feel?",
    "What's something you enjoy about it?",
    "Is there a sound or smell you remember?",
    "Would you like to tell me a little about this?",
  ];

  Future<void> _send([String? overrideText]) async {
    if (_awaitingReply) return;
    final text = (overrideText ?? _controller.text).trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(_Message.you(text));
      _controller.clear();
      _awaitingReply = true;
    });
    _scrollToEnd();

    final history = _messages
        .where((m) => !m.isPending)
        .map((m) => m.fromYou
            ? CompanionMessage.user(m.text)
            : CompanionMessage.assistant(m.text))
        .toList();
    // The user message we just appended is the last entry; the
    // service expects history + a separate userMessage, so drop the tail.
    final priorHistory =
        history.isNotEmpty ? history.sublist(0, history.length - 1) : history;

    final reply = await _service.respond(
      photo: _photo,
      history: priorHistory,
      userMessage: text,
    );
    if (!mounted) return;
    setState(() {
      _messages.add(_Message.companion(reply));
      _awaitingReply = false;
    });
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent + 200,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Save a snippet now (explicit "Save snippet" button). Returns null on
  /// failure; caller decides whether to show a toast.
  Future<String?> _saveSnippet({bool silent = false}) async {
    final authState = Provider.of<AuthState>(context, listen: false);
    final userId = authState.userModel?.userId;
    if (userId == null) return null;

    final history = _messages
        .where((m) => !m.isPending)
        .map((m) => m.fromYou
            ? CompanionMessage.user(m.text)
            : CompanionMessage.assistant(m.text))
        .toList();
    if (history.isEmpty) return null;

    final summary = await _service.summarizeSnippet(
      photo: _photo,
      history: history,
    );

    // If GPT couldn't summarize (no key, or empty), fall back to the
    // person's first non-trivial line as the quote.
    String quote;
    String? theme;
    String? tone;
    if (summary != null) {
      quote = summary['quote'] ?? '';
      theme = summary['theme'];
      tone = summary['tone'];
    } else {
      final firstUser = history.firstWhere(
        (m) => m.role == 'user' && m.content.trim().length >= 3,
        orElse: () => const CompanionMessage.user(''),
      );
      quote = firstUser.content.trim();
      if (quote.isEmpty) return null;
    }
    if (quote.isEmpty) return null;

    final snippet = StorySnippet(
      quote: quote,
      theme: theme,
      tone: tone,
      photoCaption: widget.caption,
      photoUrl: widget.imageUrl,
      person: widget.who,
      createdAt: DateTime.now().toUtc().toIso8601String(),
      userId: userId,
    );
    final key = await _snippets.save(snippet);
    if (!silent && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: PhotoTalkPalette.accentGreen,
          content: Text('Saved to your Story Snippets.',
              style: TextStyle(color: Colors.white)),
        ),
      );
    }
    return key;
  }

  Future<void> _endSession() async {
    if (_sessionEnded) return;
    _sessionEnded = true;
    final authState = Provider.of<AuthState>(context, listen: false);
    final userId = authState.userModel?.userId;
    if (userId == null) return;

    final history = _messages
        .where((m) => !m.isPending)
        .map((m) => m.fromYou
            ? CompanionMessage.user(m.text)
            : CompanionMessage.assistant(m.text))
        .toList();
    final userTurnCount =
        history.where((m) => m.role == 'user').length;

    // Only auto-save a snippet if the person actually engaged.
    String? tone;
    if (userTurnCount >= 1) {
      final summary = await _service.summarizeSnippet(
        photo: _photo,
        history: history,
      );
      if (summary != null) {
        tone = summary['tone'];
        final quote = summary['quote'] ?? '';
        if (quote.isNotEmpty) {
          await _snippets.save(StorySnippet(
            quote: quote,
            theme: summary['theme'],
            tone: tone,
            photoCaption: widget.caption,
            photoUrl: widget.imageUrl,
            person: widget.who,
            createdAt: DateTime.now().toUtc().toIso8601String(),
            userId: userId,
          ));
        }
      }
    }

    final duration = DateTime.now().difference(_sessionStart).inSeconds;
    await _sessionLogs.save(SessionLog(
      userId: userId,
      photoCaption: widget.caption,
      photoUrl: widget.imageUrl,
      turnCount: userTurnCount,
      durationSeconds: duration,
      tone: tone,
      startedAt: _sessionStart.toUtc().toIso8601String(),
    ));
  }

  @override
  void dispose() {
    // Fire-and-forget the session close.
    // ignore: discarded_futures
    _endSession();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PhotoTalkPalette.background,
      appBar: AppBar(
        backgroundColor: PhotoTalkPalette.background,
        elevation: 0,
        foregroundColor: PhotoTalkPalette.textPrimary,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: PhotoTalkPalette.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.favorite,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Text('Companion', style: PhotoTalkText.title),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _awaitingReply
                ? null
                : () async => await _saveSnippet(),
            icon: const Icon(Icons.bookmark_add_outlined,
                color: PhotoTalkPalette.primary),
            label: const Text('Save snippet',
                style: TextStyle(
                  color: PhotoTalkPalette.primary,
                  fontWeight: FontWeight.w600,
                )),
          ),
          IconButton(
            tooltip: "End session gently",
            onPressed: () async {
              await _endSession();
              if (mounted) Navigator.of(context).pop();
            },
            icon: const Icon(Icons.pause_circle_outline,
                color: PhotoTalkPalette.textSecondary),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            children: [
              _photoStrip(),
              Expanded(
                child: ListView.builder(
                  controller: _scroll,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount:
                      _messages.length + (_awaitingReply ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i == _messages.length) {
                      return _bubble(_Message.pending());
                    }
                    return _bubble(_messages[i]);
                  },
                ),
              ),
              _suggestionStrip(),
              _inputBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _photoStrip() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 72,
              height: 72,
              child: widget.imageUrl == null
                  ? Container(
                      color: PhotoTalkPalette.surface,
                      child: const Icon(Icons.photo_outlined,
                          color: PhotoTalkPalette.textMuted),
                    )
                  : Image.network(
                      widget.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: PhotoTalkPalette.surface,
                        child: const Icon(Icons.photo_outlined,
                            color: PhotoTalkPalette.textMuted),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.caption,
                    style: PhotoTalkText.bodyLarge,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                if (widget.who != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(widget.who!,
                        style: PhotoTalkText.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(_Message m) {
    final isYou = m.fromYou;
    return Align(
      alignment: isYou ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isYou ? PhotoTalkPalette.primary : PhotoTalkPalette.surface,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isYou ? 18 : 4),
              bottomRight: Radius.circular(isYou ? 4 : 18),
            ),
            border: isYou
                ? null
                : Border.all(color: PhotoTalkPalette.divider),
          ),
          child: m.isPending
              ? const SizedBox(
                  width: 28,
                  height: 18,
                  child: _TypingDots(),
                )
              : Text(
                  m.text,
                  style: PhotoTalkText.bodyLarge.copyWith(
                    color: isYou ? Colors.white : PhotoTalkPalette.textPrimary,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _suggestionStrip() {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _gentlePrompts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final prompt = _gentlePrompts[i];
          return ActionChip(
            backgroundColor: PhotoTalkPalette.surface,
            side: const BorderSide(color: PhotoTalkPalette.divider),
            label: Text(prompt, style: PhotoTalkText.chip),
            onPressed: () => _send(prompt),
          );
        },
      ),
    );
  }

  Widget _inputBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
          children: [
            IconButton(
              iconSize: 32,
              color: PhotoTalkPalette.primary,
              icon: const Icon(Icons.mic_none_rounded),
              onPressed: () {
                // Placeholder for voice input.
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Voice input is coming soon.'),
                  ),
                );
              },
            ),
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 4,
                style: PhotoTalkText.body,
                decoration: InputDecoration(
                  hintText: 'Share a thought...',
                  hintStyle: PhotoTalkText.caption.copyWith(fontSize: 16),
                  filled: true,
                  fillColor: PhotoTalkPalette.surface,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide:
                        const BorderSide(color: PhotoTalkPalette.divider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide:
                        const BorderSide(color: PhotoTalkPalette.divider),
                  ),
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: PhotoTalkPalette.primary,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => _send(),
                child: const Padding(
                  padding: EdgeInsets.all(14),
                  child: Icon(Icons.send_rounded, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        double opacityFor(int i) {
          final phase = (_ctrl.value + i * 0.33) % 1.0;
          return phase < 0.5 ? 0.3 + phase : 0.8 - (phase - 0.5);
        }

        Widget dot(int i) => Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: PhotoTalkPalette.textSecondary
                    .withOpacity(opacityFor(i).clamp(0.0, 1.0)),
                shape: BoxShape.circle,
              ),
            );
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [dot(0), dot(1), dot(2)],
        );
      },
    );
  }
}

class _Message {
  final String text;
  final bool fromYou;
  final bool isPending;
  _Message.you(this.text)
      : fromYou = true,
        isPending = false;
  _Message.companion(this.text)
      : fromYou = false,
        isPending = false;
  _Message.pending()
      : text = '',
        fromYou = false,
        isPending = true;
}

/// Companion tab landing page — uses the user's real memories.
class CompanionHomePage extends StatelessWidget {
  const CompanionHomePage({Key? key, required this.scaffoldKey})
      : super(key: key);

  final GlobalKey<ScaffoldState> scaffoldKey;

  @override
  Widget build(BuildContext context) {
    final feedState = context.watch<FeedState>();
    final authState = context.watch<AuthState>();
    final list = feedState.getTweetList(authState.userModel) ?? const [];

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
        title: Text('Companion', style: PhotoTalkText.title),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _hero(context, firstMemory: list.isNotEmpty ? list.first : null),
              const SizedBox(height: 24),
              Text('Recent memories', style: PhotoTalkText.h2),
              const SizedBox(height: 12),
              if (list.isEmpty)
                _emptyHint()
              else
                for (final m in list) _recentTile(context, m),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hero(BuildContext context, {FeedModel? firstMemory}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PhotoTalkPalette.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.favorite, color: Colors.white, size: 32),
          const SizedBox(height: 12),
          const Text(
            "I'm here to chat about your photos and memories.",
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              foregroundColor: PhotoTalkPalette.primary,
              backgroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: firstMemory == null
                ? null
                : () => _openCompanion(context, firstMemory),
            child: const Text("Let's begin",
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
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
        'When family members add memories, you can come here to chat about them with the Companion.',
        style: PhotoTalkText.body
            .copyWith(color: PhotoTalkPalette.textSecondary),
      ),
    );
  }

  Widget _recentTile(BuildContext context, FeedModel m) {
    final caption = (m.description ?? '').trim().isEmpty
        ? 'A memory worth keeping'
        : m.description!.split('\n').first;
    final who = m.user?.displayName;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: PhotoTalkPalette.surface,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: PhotoTalkPalette.divider),
          ),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 56,
              height: 56,
              child: m.imagePath == null
                  ? Container(color: PhotoTalkPalette.background)
                  : Image.network(
                      m.imagePath!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Container(color: PhotoTalkPalette.background),
                    ),
            ),
          ),
          title: Text(caption,
              style: PhotoTalkText.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          subtitle: who == null ? null : Text(who, style: PhotoTalkText.caption),
          trailing: const Icon(Icons.chevron_right,
              color: PhotoTalkPalette.textSecondary),
          onTap: () => _openCompanion(context, m),
        ),
      ),
    );
  }

  void _openCompanion(BuildContext context, FeedModel m) {
    final lines = (m.description ?? '').split('\n');
    final caption = lines.isNotEmpty ? lines.first : 'A memory';
    String? extract(String prefix) {
      for (final l in lines.skip(1)) {
        if (l.startsWith(prefix)) return l.substring(prefix.length).trim();
      }
      return null;
    }

    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CompanionPage(
        caption: caption,
        imageUrl: m.imagePath,
        who: extract('Who:'),
        where: extract('Where:'),
        why: extract('Why it matters:'),
        song: extract('Song:'),
        tags: m.tags ?? const [],
      ),
    ));
  }
}
