import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'photoTalkTheme.dart';

/// Calm Mode - a slow, passive slideshow with very minimal UI.
/// Tap anywhere to advance. Swipe down to exit.
class CalmModePage extends StatefulWidget {
  const CalmModePage({Key? key}) : super(key: key);

  @override
  State<CalmModePage> createState() => _CalmModePageState();
}

class _CalmModePageState extends State<CalmModePage> {
  int _index = 0;

  void _next() {
    setState(() {
      _index = (_index + 1) % kSampleMemories.length;
    });
  }

  void _prev() {
    setState(() {
      _index = (_index - 1 + kSampleMemories.length) % kSampleMemories.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final m = kSampleMemories[_index];
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
                      : CachedNetworkImage(
                          key: ValueKey(m.imageUrl),
                          imageUrl: m.imageUrl!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
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
                      const SizedBox(height: 6),
                      Text(m.where,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          )),
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
}
