import 'package:flutter/material.dart';

import '../photoTalkTheme.dart';

/// A single neutral avatar used across PhotoTalk in place of real
/// profile photos. Same shape and color for every account so the UI
/// feels uniform and no one's avatar becomes "the photo."
class GenericAvatar extends StatelessWidget {
  const GenericAvatar({
    Key? key,
    this.size = 56,
    this.background,
    this.iconColor,
  }) : super(key: key);

  final double size;
  final Color? background;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final bg = background ?? PhotoTalkPalette.primary.withOpacity(0.12);
    final fg = iconColor ?? PhotoTalkPalette.primary;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.person_rounded,
        size: size * 0.6,
        color: fg,
      ),
    );
  }
}
