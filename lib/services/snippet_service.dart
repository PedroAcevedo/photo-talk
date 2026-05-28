import 'package:firebase_database/firebase_database.dart';

/// A Family Story Snippet captured from a Companion session.
class StorySnippet {
  final String? key;
  final String quote;
  final String? theme;
  final String? tone;
  final String? photoCaption;
  final String? photoUrl;
  final String? person; // who in the photo
  final String createdAt;
  final String userId;

  StorySnippet({
    this.key,
    required this.quote,
    this.theme,
    this.tone,
    this.photoCaption,
    this.photoUrl,
    this.person,
    required this.createdAt,
    required this.userId,
  });

  Map<String, dynamic> toJson() => {
        'quote': quote,
        if (theme != null) 'theme': theme,
        if (tone != null) 'tone': tone,
        if (photoCaption != null) 'photoCaption': photoCaption,
        if (photoUrl != null) 'photoUrl': photoUrl,
        if (person != null) 'person': person,
        'createdAt': createdAt,
        'userId': userId,
      };

  static StorySnippet fromJson(String key, Map<dynamic, dynamic> map) {
    return StorySnippet(
      key: key,
      quote: (map['quote'] ?? '').toString(),
      theme: map['theme']?.toString(),
      tone: map['tone']?.toString(),
      photoCaption: map['photoCaption']?.toString(),
      photoUrl: map['photoUrl']?.toString(),
      person: map['person']?.toString(),
      createdAt: (map['createdAt'] ?? DateTime.now().toUtc().toString())
          .toString(),
      userId: (map['userId'] ?? '').toString(),
    );
  }
}

/// Save and read snippets in Firebase Realtime Database under
/// `/snippets/{userId}/{autoKey}`.
class SnippetService {
  SnippetService({FirebaseDatabase? db})
      : _db = db ?? FirebaseDatabase.instance;

  final FirebaseDatabase _db;

  DatabaseReference _userRef(String userId) =>
      _db.ref().child('snippets').child(userId);

  Future<String?> save(StorySnippet snippet) async {
    final ref = _userRef(snippet.userId).push();
    await ref.set(snippet.toJson());
    return ref.key;
  }

  Future<List<StorySnippet>> recent(String userId,
      {int limit = 30}) async {
    final event = await _userRef(userId)
        .orderByChild('createdAt')
        .limitToLast(limit)
        .once();
    final value = event.snapshot.value;
    if (value == null) return [];
    final map = value as Map<dynamic, dynamic>;
    final items = map.entries
        .map((e) => StorySnippet.fromJson(
            e.key.toString(), e.value as Map<dynamic, dynamic>))
        .toList();
    // Newest first.
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }
}

/// One session record for the Caregiver Recap.
class SessionLog {
  final String? key;
  final String userId;
  final String photoCaption;
  final String? photoUrl;
  final int turnCount;
  final int durationSeconds;
  final String? tone; // Joyful / Calm / Reflective / Tender / Mixed
  final String startedAt;

  SessionLog({
    this.key,
    required this.userId,
    required this.photoCaption,
    this.photoUrl,
    required this.turnCount,
    required this.durationSeconds,
    this.tone,
    required this.startedAt,
  });

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'photoCaption': photoCaption,
        if (photoUrl != null) 'photoUrl': photoUrl,
        'turnCount': turnCount,
        'durationSeconds': durationSeconds,
        if (tone != null) 'tone': tone,
        'startedAt': startedAt,
      };

  static SessionLog fromJson(String key, Map<dynamic, dynamic> map) {
    return SessionLog(
      key: key,
      userId: (map['userId'] ?? '').toString(),
      photoCaption: (map['photoCaption'] ?? '').toString(),
      photoUrl: map['photoUrl']?.toString(),
      turnCount: (map['turnCount'] ?? 0) is int
          ? map['turnCount'] as int
          : int.tryParse('${map['turnCount']}') ?? 0,
      durationSeconds: (map['durationSeconds'] ?? 0) is int
          ? map['durationSeconds'] as int
          : int.tryParse('${map['durationSeconds']}') ?? 0,
      tone: map['tone']?.toString(),
      startedAt: (map['startedAt'] ?? DateTime.now().toUtc().toString())
          .toString(),
    );
  }
}

class SessionLogService {
  SessionLogService({FirebaseDatabase? db})
      : _db = db ?? FirebaseDatabase.instance;

  final FirebaseDatabase _db;

  DatabaseReference _userRef(String userId) =>
      _db.ref().child('sessions').child(userId);

  Future<String?> save(SessionLog session) async {
    final ref = _userRef(session.userId).push();
    await ref.set(session.toJson());
    return ref.key;
  }

  Future<List<SessionLog>> recent(String userId, {int limit = 50}) async {
    final event = await _userRef(userId)
        .orderByChild('startedAt')
        .limitToLast(limit)
        .once();
    final value = event.snapshot.value;
    if (value == null) return [];
    final map = value as Map<dynamic, dynamic>;
    final items = map.entries
        .map((e) => SessionLog.fromJson(
            e.key.toString(), e.value as Map<dynamic, dynamic>))
        .toList();
    items.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return items;
  }
}
