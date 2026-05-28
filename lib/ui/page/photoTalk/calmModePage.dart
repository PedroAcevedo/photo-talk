import 'package:flutter/material.dart';

import 'photoTalkTheme.dart';

/// One slide of content for Calm Mode.
class CalmSlide {
  final String caption;
  final String? subtitle;
  final String? imageUrl;
  const CalmSlide({
    required this.caption,
    this.subtitle,
    this.imageUrl,
  });
}

/// Calm Mode - a slow, passive slideshow with very minimal UI.
/// Tap anywhere to advance. Swipe down to exit.
class CalmModePage extends StatefulWidget {
  const CalmModePage({Key? key, this.slides = const []}) : super(key: key);

  /// Slides to show. If empty, Calm Mode displays a friendly placeholder.
  final List<CalmSlide> slides;

  @override
  State<CalmModePage> createState() => _CalmModePageState();
}

class _CalmModePageState extends State<CalmModePage> {
  int _index = 0;

  void _next() {
    if (widget.slides.isEmpty) return;
    setState(() {
      _index = (_index + 1) % widget.slides.length;
    });
  }

  void _prev() {
    if (widget.slides.isEmpty) return;
    setState(() {
      _index = (_index - 1 + widget.slides.length) % widget.slides.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.slides.isEmpty) {
      return _emptyScaffold(context);
    }
    final m = widget.slides[_index];
    return Scaffold(
      backgroundColor: const Color(0xFF1B1816),
      body: SafeArea(
        child: GestureDetector(
          onTap: _next,
          onVerticalDragEnd: (d) {
            if (d.primaryVelocity != null && d.primaryVelocity! > 200) {
              Navigator.of(context).pop();
            }
          },
          onHorizontalDragEnd: (d) {
            if (d.primaryVelocity == null) return;
            if (d.primaryVelocity! < -200) _next();
            if (d.primaryVelocity! > 200) _prev();
          },
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  child: m.imageUrl == null
                      ? Container(
                          key: ValueKey('blank-$_index'),
                          color: Colors.black)
                      : Image.network(
                          m.imageUrl!,
                          key: ValueKey(m.imageUrl),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.black,
                            alignment: Alignment.center,
                            child: const Icon(Icons.image_not_supported,
                                color: Colors.white54, size: 48),
                          ),
                        ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding:
                      const EdgeInsets.fromLTRB(28, 32, 28, 36),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Color(0xCC000000),
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(m.caption,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                          )),
                      if (m.subtitle != null && m.subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(m.subtitle!,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            )),
                      ],
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: Colors.white70, size: 28),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.spa_outlined,
                          color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text('Calm Mode',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B1816),
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.spa_outlined,
                        color: Colors.white70, size: 64),
                    SizedBox(height: 16),
                    Text(
                      'Calm Mode',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'When family adds memories, they will gently flow through here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close_rounded,
                    color: Colors.white70, size: 28),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
