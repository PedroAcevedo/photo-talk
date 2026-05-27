part of '../theme.dart';

/// PhotoTalk: the legacy `TwitterColor` and `AppColor` names are kept so the
/// many leaf screens that still reference them keep compiling, but their
/// values now resolve to the warm PhotoTalk palette so the look is
/// consistent across the app without restyling every individual file.
class TwitterColor {
  // Backgrounds (formerly Twitter white / mystic) now map to the warm
  // off-white background used everywhere else.
  static Color white = const Color(0xFFFBF6F0);
  static Color mystic = const Color(0xFFFBF6F0);

  // Accent (formerly Twitter blue) now maps to PhotoTalk's warm primary.
  static Color dodgeBlue = const Color(0xFFD98E5C);
  static Color dodgeBlue_50 = const Color(0x80D98E5C);

  // Other legacy values kept for compatibility.
  static Color bondiBlue = const Color(0xFFB57043);
  static Color cerulean = const Color(0xFFD98E5C);
  static Color spindle = const Color(0xFFE9E1D7);
  static Color black = const Color(0xFF2C2A28);
  static Color woodsmoke = const Color(0xFF2C2A28);
  static Color woodsmoke_50 = const Color(0x802C2A28);
  static Color paleSky = const Color(0xFF6E6A66);
  static Color ceriseRed = const Color(0xFFC97B8C);
  static Color paleSky50 = const Color(0x806E6A66);
}

class AppColor {
  // Primary/secondary aligned to PhotoTalk theme.
  static const Color primary = Color(0xFFD98E5C);
  static const Color secondary = Color(0xFF2C2A28);
  static const Color darkGrey = Color(0xFF6E6A66);
  static const Color lightGrey = Color(0xFF9C9893);
  static const Color extraLightGrey = Color(0xFFE9E1D7);
  static const Color extraExtraLightGrey = Color(0xFFFBF6F0);
  static const Color white = Color(0xFFFBF6F0);
}
