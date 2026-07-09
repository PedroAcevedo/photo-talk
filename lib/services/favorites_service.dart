import 'dart:async';

import 'package:firebase_database/firebase_database.dart';

/// Per-care-recipient "favorites" — memories anyone in the care circle
/// marked as important. Stored under /favorites/{recipientId}/{memoryKey}
/// as `{savedAt, savedByUid}`. Content is not duplicated; the tab reads
/// the full memory from the in-memory feed by key.
class FavoriteEntry {
  final String memoryKey;
  final String savedAt;
  final String savedByUid;

  const FavoriteEntry({
    required this.memoryKey,
    required this.savedAt,
    required this.savedByUid,
  });

  Map<String, dynamic> toJson() => {
        'savedAt': savedAt,
        'savedByUid': savedByUid,
      };

  factory FavoriteEntry.fromJson(String key, Map<dynamic, dynamic> map) {
    return FavoriteEntry(
      memoryKey: key,
      savedAt: (map['savedAt'] ?? '').toString(),
      savedByUid: (map['savedByUid'] ?? '').toString(),
    );
  }
}

class FavoritesService {
  FavoritesService({FirebaseDatabase? db})
      : _db = db ?? FirebaseDatabase.instance;

  final FirebaseDatabase _db;

  DatabaseReference _ref(String recipientId) =>
      _db.ref().child('favorites').child(recipientId);

  Future<void> save({
    required String recipientId,
    required String memoryKey,
    required String savedByUid,
  }) async {
    await _ref(recipientId).child(memoryKey).set({
      'savedAt': DateTime.now().toUtc().toIso8601String(),
      'savedByUid': savedByUid,
    });
  }

  Future<void> remove({
    required String recipientId,
    required String memoryKey,
  }) async {
    await _ref(recipientId).child(memoryKey).remove();
  }

  /// One-shot read of the entries under the recipient.
  Future<List<FavoriteEntry>> list(String recipientId) async {
    final event = await _ref(recipientId).once();
    return _parse(event.snapshot.value);
  }

  /// Live stream of the recipient's favorites. Emits on every add/remove.
  Stream<List<FavoriteEntry>> watch(String recipientId) {
    return _ref(recipientId).onValue.map((e) => _parse(e.snapshot.value));
  }

  /// Live stream of just the memory keys — cheap set used by feed cards
  /// to render the heart icon in its "on" state.
  Stream<Set<String>> watchKeys(String recipientId) {
    return watch(recipientId).map((list) => list.map((e) => e.memoryKey).toSet());
  }

  List<FavoriteEntry> _parse(Object? value) {
    if (value == null) return const [];
    final map = value as Map<dynamic, dynamic>;
    final items = map.entries
        .map((e) =>
            FavoriteEntry.fromJson(e.key.toString(), e.value as Map))
        .toList();
    // Newest first.
    items.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return items;
  }
}
