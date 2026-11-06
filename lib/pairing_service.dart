import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PairRole { monitor, receiver }

class SavedPairing {
  final PairRole role;
  final String code;
  SavedPairing(this.role, this.code);
}

class PairingException implements Exception {
  final String message;
  PairingException(this.message);

  @override
  String toString() => message;
}

class PairingService {
  PairingService._();
  static final instance = PairingService._();

  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  static const _roleKey = 'pair_role';
  static const _codeKey = 'pair_code';

  // Each phone signs in anonymously. The id stays the same until the app's
  // data is cleared or the app is uninstalled.
  Future<String> _uid() async {
    final user = _auth.currentUser ?? (await _auth.signInAnonymously()).user;
    if (user == null) {
      throw PairingException('Could not sign in. Check your internet.');
    }
    return user.uid;
  }

  DocumentReference<Map<String, dynamic>> _ref(String code) =>
      _db.collection('pairings').doc(code);

  // MONITOR phone: makes a fresh 6-digit code and waits for the other phone.
  Future<String> createPairing() async {
    final uid = await _uid();
    final rng = Random.secure();

    for (var i = 0; i < 8; i++) {
      final code = (100000 + rng.nextInt(900000)).toString();
      final ref = _ref(code);
      if ((await ref.get()).exists) continue; // code already taken, try again

      await ref.set({
        'monitorUid': uid,
        'receiverUid': null,
        'paired': false,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(
            DateTime.now().add(const Duration(minutes: 10))),
      });
      await _save(PairRole.monitor, code);
      return code;
    }
    throw PairingException('Could not create a pairing code. Try again.');
  }

  // RECEIVER phone: enters the code shown on the monitor phone.
  Future<void> joinPairing(String rawCode) async {
    final code = rawCode.trim();
    if (code.length != 6) {
      throw PairingException('The code has 6 numbers.');
    }
    final uid = await _uid();
    final ref = _ref(code);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        throw PairingException('Code not found. Check the numbers and try again.');
      }
      final data = snap.data()!;
      final receiver = data['receiverUid'];

      if (receiver != null && receiver != uid) {
        throw PairingException('This code is already used by another phone.');
      }
      if (receiver == null) {
        final expires = (data['expiresAt'] as Timestamp).toDate();
        if (DateTime.now().isAfter(expires)) {
          throw PairingException(
              'This code has expired. Ask the monitor phone for a new one.');
        }
      }

      tx.update(ref, {
        'receiverUid': uid,
        'paired': true,
        'pairedAt': FieldValue.serverTimestamp(),
      });
    });

    await _save(PairRole.receiver, code);
  }

  // Live updates of the pairing record (shows "paired" the moment it happens).
  Stream<DocumentSnapshot<Map<String, dynamic>>> watch(String code) =>
      _ref(code).snapshots();

  // Ends the pairing for both phones and forgets it on this phone.
  Future<void> unpair() async {
    final saved = await loadSaved();
    if (saved != null) {
      try {
        await _ref(saved.code).delete();
      } catch (_) {
        // Already gone or no internet; still clear this phone below.
      }
    }
    await clearLocal();
  }

  // Forgets the pairing on this phone only (does not touch Firebase).
  Future<void> clearLocal() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_roleKey);
    await p.remove(_codeKey);
  }

  Future<void> _save(PairRole role, String code) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_roleKey, role.name);
    await p.setString(_codeKey, code);
  }

  Future<SavedPairing?> loadSaved() async {
    final p = await SharedPreferences.getInstance();
    final role = p.getString(_roleKey);
    final code = p.getString(_codeKey);
    if (role == null || code == null) return null;
    return SavedPairing(
      role == PairRole.monitor.name ? PairRole.monitor : PairRole.receiver,
      code,
    );
  }
}