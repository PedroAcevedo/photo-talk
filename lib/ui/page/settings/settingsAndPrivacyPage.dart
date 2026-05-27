import 'package:flutter/material.dart';
import 'package:flutter_twitter_clone/ui/page/photoTalk/photoTalkTheme.dart';
import 'package:flutter_twitter_clone/ui/page/settings/widgets/headerWidget.dart';

import 'widgets/settingsRowWidget.dart';

class SettingsAndPrivacyPage extends StatelessWidget {
  const SettingsAndPrivacyPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PhotoTalkPalette.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: PhotoTalkPalette.background,
        foregroundColor: PhotoTalkPalette.textPrimary,
        title: Text('Privacy and access', style: PhotoTalkText.title),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: const <Widget>[
          HeaderWidget('Account'),
          SettingRowWidget(
            "Account details",
            navigateTo: 'AccountSettingsPage',
          ),
          SettingRowWidget("Privacy and access",
              navigateTo: 'PrivacyAndSaftyPage'),
          SettingRowWidget("Notifications",
              navigateTo: 'NotificationPage', showDivider: false),
          HeaderWidget('General', secondHeader: true),
          SettingRowWidget("Display and sound",
              navigateTo: 'DisplayAndSoundPage'),
          SettingRowWidget("Data usage", navigateTo: 'DataUsagePage'),
          SettingRowWidget("Accessibility",
              navigateTo: 'AccessibilityPage'),
          SettingRowWidget(
            "About PhotoTalk",
            navigateTo: "AboutPage",
            showDivider: false,
          ),
          SizedBox(height: 16),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Text(
              'These settings affect PhotoTalk on this device.',
              style: PhotoTalkText.caption,
            ),
          ),
        ],
      ),
    );
  }
}
