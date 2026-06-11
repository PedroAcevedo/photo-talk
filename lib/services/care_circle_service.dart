import 'dart:math';

import 'package:firebase_database/firebase_database.dart';

/// Care-circle helpers: short shareable join codes that pair family /
/// caregiver accounts to a specific care recipient.
class CareCircleService {
  CareCircleService({FirebaseDatabase? db})
      : _db = db ?? FirebaseDatabase.instance;

  final FirebaseDatabase _db;

  /// Six-character code, only easy-to-read letters/digits.
  static String generateJoinCode() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    return List.generate(6, (_) => alphabet[rng.nextInt(alphabet.length)])
        .join();
  }

  DatabaseReference _codeRef(String code) =>
      _db.ref().child('joinCodes').child(code.toUpperCase());

  /// Reserve [code] for [userId] in /joinCodes. Returns true on success;
  /// false if the code was already reserved.
  Future<bool> reserveCode(String code, String userId) async {
    final ref = _codeRef(code);
    final event = await ref.once();
    if (event.snapshot.value != null) return false;
    await ref.set({'userId': userId, 'createdAt': DateTime.now().toUtc().toIso8601String()});
    return true;
  }

  /// Look up the care recipient userId reserved under [code]. Returns
  /// null when no such code exists.
  Future<String?> resolveCode(String code) async {
    final ref = _codeRef(code);
    final event = await ref.once();
    final value = event.snapshot.value;
    if (value == null) return null;
    if (value is Map) return value['userId']?.toString();
    return null;
  }
}
