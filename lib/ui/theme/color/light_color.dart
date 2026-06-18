part of '../theme.dart';

/// PhotoTalk: the legacy `TwitterColor` and `AppColor` names are kept so the
/// many leaf screens that still reference them keep compiling, but their
/// values now resolve to the warm PhotoTalk palette so the look is
/// consistent across the app without restyling every individual file.
class TwitterColor {
  // Backgrounds now map to the cream background used by the PhotoTalk
  // palette so legacy screens blend with the rest of the app.
  static Color white = const Color(0xFFF8F4ED);
  static Color mystic = const Color(0xFFF8F4ED);

  // Accent (formerly Twitter blue) now maps to PhotoTalk's teal primary.
  static Color dodgeBlue = const Color(0xFF1F6E7E);
  static Color dodgeBlue_50 = const Color(0x801F6E7E);

  // Other legacy values aligned to the new palette.
  static Color bondiBlue = const Color(0xFF155561);
  static Color cerulean = const Color(0xFF1F6E7E);
  static Color spindle = const Color(0xFFE0DCD3);
  static Color black = const Color(0xFF1F2E33);
  static Color woodsmoke = const Color(0xFF1F2E33);
  static Color woodsmoke_50 = const Color(0x801F2E33);
  static Color paleSky = const Color(0xFF5E6B70);
  static Color ceriseRed = const Color(0xFFC4596B);
  static Color paleSky50 = const Color(0x805E6B70);
}

class AppColor {
  // Primary/secondary aligned to PhotoTalk theme.
  static const Color primary = Color(0xFF1F6E7E);
  static const Color secondary = Color(0xFF1F2E33);
  static const Color darkGrey = Color(0xFF5E6B70);
  static const Color lightGrey = Color(0xFF96A0A5);
  static const Color extraLightGrey = Color(0xFFE0DCD3);
  static const Color extraExtraLightGrey = Color(0xFFF8F4ED);
  static const Color white = Color(0xFFF8F4ED);
}
