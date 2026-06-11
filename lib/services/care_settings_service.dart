import 'dart:async';

import 'package:firebase_database/firebase_database.dart';

/// Per-care-recipient toggles that anyone in the care circle (recipient
/// themselves, plus linked family or caregiver) can read and write.
/// Stored under /careSettings/{recipientId}.
class CareSettings {
  final bool aiDisabled;
  final String? defaultMode; // 'calm' | 'chat' | 'music'

  const CareSettings({
    this.aiDisabled = false,
    this.defaultMode,
  });

  Map<String, dynamic> toJson() => {
        'aiDisabled': aiDisabled,
        if (defaultMode != null) 'defaultMode': defaultMode,
      };

  static CareSettings fromJson(Map<dynamic, dynamic>? map) {
    if (map == null) return const CareSettings();
    return CareSettings(
      aiDisabled: map['aiDisabled'] == true,
      defaultMode: map['defaultMode']?.toString(),
    );
  }

  CareSettings copyWith({bool? aiDisabled, String? defaultMode}) =>
      CareSettings(
        aiDisabled: aiDisabled ?? this.aiDisabled,
        defaultMode: defaultMode ?? this.defaultMode,
      );
}

class CareSettingsService {
  CareSettingsService({FirebaseDatabase? db})
      : _db = db ?? FirebaseDatabase.instance;

  final FirebaseDatabase _db;

  DatabaseReference _ref(String recipientId) =>
      _db.ref().child('careSettings').child(recipientId);

  /// One-shot read.
  Future<CareSettings> read(String recipientId) async {
    final event = await _ref(recipientId).once();
    return CareSettings.fromJson(event.snapshot.value as Map?);
  }

  /// Live updates. Useful for the Companion screen — if a caregiver
  /// toggles AI off on another device, the recipient's session ends.
  Stream<CareSettings> watch(String recipientId) {
    return _ref(recipientId).onValue.map(
          (e) => CareSettings.fromJson(e.snapshot.value as Map?),
        );
  }

  Future<void> setAiDisabled(String recipientId, bool value) async {
    await _ref(recipientId).update({'aiDisabled': value});
  }

  Future<void> setDefaultMode(String recipientId, String? mode) async {
    await _ref(recipientId).update({'defaultMode': mode});
  }
}
