import 'package:flutter/material.dart';
import 'package:flutter_twitter_clone/ui/page/photoTalk/photoTalkTheme.dart';

class SettingsAppBar extends StatelessWidget implements PreferredSizeWidget {
  const SettingsAppBar({Key? key, required this.title, this.subtitle})
      : super(key: key);
  final String? subtitle;
  final String title;
  final Size appBarHeight = const Size.fromHeight(64.0);
  @override
  Widget build(BuildContext context) {
    return AppBar(
      elevation: 0,
      backgroundColor: PhotoTalkPalette.background,
      foregroundColor: PhotoTalkPalette.textPrimary,
      iconTheme: const IconThemeData(color: PhotoTalkPalette.textPrimary),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(title, style: PhotoTalkText.title),
          if (subtitle != null && subtitle!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                subtitle!,
                style: PhotoTalkText.caption.copyWith(fontSize: 14),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => appBarHeight;
}
