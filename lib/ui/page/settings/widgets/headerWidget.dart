import 'package:flutter/material.dart';
import 'package:flutter_twitter_clone/ui/page/photoTalk/photoTalkTheme.dart';

class HeaderWidget extends StatelessWidget {
  final String? title;
  final bool secondHeader;
  const HeaderWidget(this.title, {Key? key, this.secondHeader = false})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: secondHeader
          ? const EdgeInsets.only(left: 20, right: 20, bottom: 8, top: 28)
          : const EdgeInsets.fromLTRB(20, 16, 20, 8),
      color: PhotoTalkPalette.background,
      alignment: Alignment.centerLeft,
      child: Text(
        (title ?? '').toUpperCase(),
        style: PhotoTalkText.chip.copyWith(
          color: PhotoTalkPalette.textSecondary,
          fontSize: 13,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
