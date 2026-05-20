import 'package:flutter/material.dart';

/// PhotoTalk uses a warm, low-contrast, dementia-friendly palette.
/// Big touch targets, readable text, gentle colors.
class PhotoTalkPalette {
  PhotoTalkPalette._();

  // Warm, calm primary - a soft terracotta/amber that reads well at low vision.
  static const Color primary = Color(0xFFD98E5C);
  static const Color primaryDark = Color(0xFFB57043);

  // Background: warm off-white that's softer than pure white.
  static const Color background = Color(0xFFFBF6F0);
  static const Color surface = Color(0xFFFFFFFF);

  // Accents
  static const Color accentGreen = Color(0xFF6BAA75); // calm/nature
  static const Color accentBlue = Color(0xFF6B8FAA); // music
  static const Color accentLavender = Color(0xFFA08BB8); // snippets
  static const Color accentRose = Color(0xFFC97B8C); // caregiver

  // Text
  static const Color textPrimary = Color(0xFF2C2A28);
  static const Color textSecondary = Color(0xFF6E6A66);
  static const Color textMuted = Color(0xFF9C9893);

  // Soft dividers
  static const Color divider = Color(0xFFE9E1D7);
}

class PhotoTalkText {
  PhotoTalkText._();

  static const TextStyle h1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: PhotoTalkPalette.textPrimary,
    height: 1.2,
  );

  static const TextStyle h2 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: PhotoTalkPalette.textPrimary,
    height: 1.25,
  );

  static const TextStyle title = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: PhotoTalkPalette.textPrimary,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: PhotoTalkPalette.textPrimary,
    height: 1.4,
  );

  static const TextStyle body = TextStyle(
    fontSize: 16,
    color: PhotoTalkPalette.textPrimary,
    height: 1.4,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 14,
    color: PhotoTalkPalette.textSecondary,
    height: 1.3,
  );

  static const TextStyle chip = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: PhotoTalkPalette.textPrimary,
  );
}

/// A small sample memory the views can fall back to when no real
/// data is available, so views are demonstrable without Firebase wiring.
class SampleMemory {
  final String caption;
  final String who;
  final String where;
  final String why;
  final String? imageUrl;
  final String? song;
  final List<String> tags;

  const SampleMemory({
    required this.caption,
    required this.who,
    required this.where,
    required this.why,
    this.imageUrl,
    this.song,
    this.tags = const [],
  });
}

const List<SampleMemory> kSampleMemories = [
  SampleMemory(
    caption: 'A sunny afternoon at the lake house',
    who: 'Mom, Dad, and Aunt Rose',
    where: 'Lake George, summer 1978',
    why: 'We used to spend every July here. Mom always packed lemonade.',
    imageUrl:
        'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?w=800',
    song: 'Here Comes the Sun — The Beatles',
    tags: ['joy', 'family', 'summer'],
  ),
  SampleMemory(
    caption: 'Dad in the garden with the tomatoes',
    who: 'Dad',
    where: 'The backyard on Elm Street',
    why: 'He was so proud of these tomatoes. He grew them every year.',
    imageUrl:
        'https://images.unsplash.com/photo-1416879595882-3373a0480b5b?w=800',
    song: null,
    tags: ['nature', 'pride', 'home'],
  ),
  SampleMemory(
    caption: 'Christmas morning with the grandkids',
    who: 'Ellie and Sam',
    where: 'The living room, 2015',
    why: 'You read the same storybook to them every Christmas.',
    imageUrl:
        'https://images.unsplash.com/photo-1481653125770-b78c206c59d4?w=800',
    song: 'Have Yourself a Merry Little Christmas',
    tags: ['celebration', 'family', 'comfort'],
  ),
];
