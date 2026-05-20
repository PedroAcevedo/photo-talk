import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'photoTalkTheme.dart';

/// AI Companion view - a soft, supportive conversation grounded in a photo.
/// Follows dementia-supportive conversational principles: no quizzes, no
/// recall pressure, gentle prompts that focus on feelings and meaning.
class CompanionPage extends StatefulWidget {
  const CompanionPage({
    Key? key,
    required this.caption,
    this.imageUrl,
    this.who,
    this.why,
  }) : super(key: key);

  final String caption;
  final String? imageUrl;
  final String? who;
  final String? why;

  @override
  State<CompanionPage> createState() => _CompanionPageState();
}

class _CompanionPageState extends State<CompanionPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<_Message> _messages = [];

  @override
  void initState() {
    super.initState();
    _messages.add(_Message.companion(_openingPrompt()));
  }

  String _openingPrompt() {
    if (widget.who != null && widget.who!.isNotEmpty) {
      return "What a lovely picture. ${widget.who} looks so happy here. "
          "What do you notice in this moment?";
    }
    return "What a lovely picture. There's no rush — what stands out to you here?";
  }

  static const List<String> _gentlePrompts = [
    "How does this picture make you feel?",
    "What's something you enjoy about it?",
    "Is there a sound or smell you remember?",
    "Would you like to tell me a little about this?",
  ];

  void _send([String? overrideText]) {
    final text = (overrideText ?? _controller.text).trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(_Message.you(text));
      _controller.clear();
    });
    _scrollToEnd();
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() {
        _messages.add(_Message.companion(_supportiveReply(text)));
      });
      _scrollToEnd();
    });
  }

  String _supportiveReply(String userText) {
    // Gentle, validating reply. Not a quiz, not a correction.
    final lower = userText.toLowerCase();
    if (lower.contains('happy') ||
        lower.contains('love') ||
        lower.contains('glad')) {
      return "That's such a warm thing to share. It sounds like a moment "
          "you truly enjoy.";
    }
    if (lower.contains('sad') ||
        lower.contains('miss') ||
        lower.contains('hard')) {
      return "I hear you. Those feelings make sense. We can sit with this "
          "as long as you'd like.";
    }
    if (lower.length < 8) {
      return "Thank you for telling me. Take your time — there's no rush.";
    }
    return "That's a beautiful thing to remember. Tell me anything else "
        "you'd like to share.";
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

  @override
  void dispose() {
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
      ),
      body: Column(
        children: [
          _photoStrip(),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _messages.length,
              itemBuilder: (_, i) => _bubble(_messages[i]),
            ),
          ),
          _suggestionStrip(),
          _inputBar(),
        ],
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
                  : CachedNetworkImage(
                      imageUrl: widget.imageUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
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
          child: Text(
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

class _Message {
  final String text;
  final bool fromYou;
  _Message.you(this.text) : fromYou = true;
  _Message.companion(this.text) : fromYou = false;
}

/// A simple, list-of-recent-conversations entry point for the Companion tab.
class CompanionHomePage extends StatelessWidget {
  const CompanionHomePage({Key? key, required this.scaffoldKey})
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
        title: Text('Companion', style: PhotoTalkText.title),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _hero(context),
          const SizedBox(height: 24),
          Text('Recent conversations', style: PhotoTalkText.h2),
          const SizedBox(height: 12),
          for (final m in kSampleMemories)
            _recentTile(context, m),
        ],
      ),
    );
  }

  Widget _hero(BuildContext context) {
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
            onPressed: () {
              final m = kSampleMemories.first;
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => CompanionPage(
                  caption: m.caption,
                  imageUrl: m.imageUrl,
                  who: m.who,
                  why: m.why,
                ),
              ));
            },
            child: const Text("Let's begin",
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _recentTile(BuildContext context, SampleMemory m) {
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
              child: m.imageUrl == null
                  ? Container(color: PhotoTalkPalette.background)
                  : CachedNetworkImage(
                      imageUrl: m.imageUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) =>
                          Container(color: PhotoTalkPalette.background),
                    ),
            ),
          ),
          title: Text(m.caption, style: PhotoTalkText.title),
          subtitle: Text(m.who, style: PhotoTalkText.caption),
          trailing: const Icon(Icons.chevron_right,
              color: PhotoTalkPalette.textSecondary),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => CompanionPage(
              caption: m.caption,
              imageUrl: m.imageUrl,
              who: m.who,
              why: m.why,
            ),
          )),
        ),
      ),
    );
  }
}
