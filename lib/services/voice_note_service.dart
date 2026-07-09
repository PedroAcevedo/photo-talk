import 'dart:async';

import 'package:firebase_database/firebase_database.dart';

/// One voice-note entry attached to a memory. Stored at
/// `/voiceNotes/{recipientId}/{memoryKey}` so only care-circle members
/// can even discover that a memory has a voice note attached — the
/// Storage URL is never mixed into the /tweet record.
class VoiceNoteEntry {
  final String memoryKey;
  final String url;
  final int durationSeconds;
  final String uploadedByUid;
  final String uploadedAt;

  const VoiceNoteEntry({
    required this.memoryKey,
    required this.url,
    required this.durationSeconds,
    required this.uploadedByUid,
    required this.uploadedAt,
  });

  Map<String, dynamic> toJson() => {
        'url': url,
        'durationSeconds': durationSeconds,
        'uploadedByUid': uploadedByUid,
        'uploadedAt': uploadedAt,
      };

  static VoiceNoteEntry fromJson(String memoryKey, Map<dynamic, dynamic> map) {
    final rawDur = map['durationSeconds'];
    return VoiceNoteEntry(
      memoryKey: memoryKey,
      url: (map['url'] ?? '').toString(),
      durationSeconds: rawDur is int
          ? rawDur
          : int.tryParse('${rawDur ?? 0}') ?? 0,
      uploadedByUid: (map['uploadedByUid'] ?? '').toString(),
      uploadedAt: (map['uploadedAt'] ??
              DateTime.now().toUtc().toIso8601String())
          .toString(),
    );
  }
}

/// CRUD + live watch for `/voiceNotes/{recipientId}/{memoryKey}`.
class VoiceNoteService {
  VoiceNoteService({FirebaseDatabase? db})
      : _db = db ?? FirebaseDatabase.instance;

  final FirebaseDatabase _db;

  DatabaseReference _bucket(String recipientId) =>
      _db.ref().child('voiceNotes').child(recipientId);

  Future<void> save({
    required String recipientId,
    required String memoryKey,
    required String url,
    required int durationSeconds,
    required String uploadedByUid,
  }) async {
    final entry = VoiceNoteEntry(
      memoryKey: memoryKey,
      url: url,
      durationSeconds: durationSeconds,
      uploadedByUid: uploadedByUid,
      uploadedAt: DateTime.now().toUtc().toIso8601String(),
    );
    await _bucket(recipientId).child(memoryKey).set(entry.toJson());
  }

  Future<void> remove({
    required String recipientId,
    required String memoryKey,
  }) async {
    await _bucket(recipientId).child(memoryKey).remove();
  }

  /// One-shot lookup for a single memory. Returns null when no voice note
  /// exists (or the caller is not in the care circle — rules will fault).
  Future<VoiceNoteEntry?> get(
      String recipientId, String memoryKey) async {
    final event = await _bucket(recipientId).child(memoryKey).once();
    final v = event.snapshot.value;
    if (v == null) return null;
    return VoiceNoteEntry.fromJson(memoryKey, v as Map);
  }

  /// Live map of the recipient's voice notes keyed by memory key.
  /// Emits a fresh snapshot on every add / remove / update.
  Stream<Map<String, VoiceNoteEntry>> watch(String recipientId) {
    return _bucket(recipientId).onValue.map((event) {
      final v = event.snapshot.value;
      if (v == null) return const <String, VoiceNoteEntry>{};
      final map = v as Map<dynamic, dynamic>;
      final out = <String, VoiceNoteEntry>{};
      map.forEach((k, val) {
        if (val is Map) {
          final key = k.toString();
          out[key] = VoiceNoteEntry.fromJson(key, val);
        }
      });
      return out;
    });
  }
}
