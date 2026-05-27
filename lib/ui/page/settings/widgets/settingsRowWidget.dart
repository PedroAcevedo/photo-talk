import 'package:flutter/material.dart';
import 'package:flutter_twitter_clone/ui/page/photoTalk/photoTalkTheme.dart';
import 'package:flutter_twitter_clone/widgets/newWidget/customCheckBox.dart';

class SettingRowWidget extends StatelessWidget {
  const SettingRowWidget(
    this.title, {
    Key? key,
    this.navigateTo,
    this.subtitle,
    this.textColor = PhotoTalkPalette.textPrimary,
    this.onPressed,
    this.vPadding = 4,
    this.showDivider = true,
    this.visibleSwitch,
    this.showCheckBox,
  }) : super(key: key);
  final bool showDivider;
  final bool? showCheckBox, visibleSwitch;
  final String? navigateTo;
  final String? subtitle, title;
  final Color textColor;
  final Function? onPressed;
  final double vPadding;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: PhotoTalkPalette.surface,
      child: Column(
        children: <Widget>[
          ListTile(
            contentPadding:
                EdgeInsets.symmetric(vertical: vPadding, horizontal: 20),
            onTap: () {
              if (onPressed != null) {
                onPressed!();
                return;
              }
              if (navigateTo == null) {
                return;
              }
              Navigator.pushNamed(context, '/$navigateTo');
            },
            title: title == null
                ? null
                : Text(
                    title!,
                    style: PhotoTalkText.body.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
            subtitle: subtitle == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      style: PhotoTalkText.caption,
                    ),
                  ),
            trailing: showCheckBox != null || visibleSwitch != null
                ? CustomCheckBox(
                    isChecked: showCheckBox,
                    visibleSwitch: visibleSwitch,
                  )
                : const Icon(Icons.chevron_right_rounded,
                    color: PhotoTalkPalette.textMuted),
          ),
          if (showDivider)
            const Divider(
              height: 0,
              indent: 20,
              endIndent: 20,
              color: PhotoTalkPalette.divider,
            ),
        ],
      ),
    );
  }
}
