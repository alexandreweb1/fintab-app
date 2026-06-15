import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';

/// Referral codes + attribution.
///
/// The app only records WHO referred whom. The actual Pro reward (1 month to
/// the referrer) is granted server-side by the `grantReferralReward` Cloud
/// Function when the invitee activates (first transaction) — so it can't be
/// farmed from the client.
class ReferralService {
  ReferralService._();
  static final ReferralService instance = ReferralService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // No ambiguous characters (0/O, 1/I/L) — easier to read and type.
  static const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  /// Deterministic, stable 8-char code for a uid.
  String codeForUid(String uid) {
    final digest = sha256.convert(utf8.encode(uid)).bytes;
    final sb = StringBuffer();
    for (var i = 0; i < 8; i++) {
      sb.write(_alphabet[digest[i] % _alphabet.length]);
    }
    return sb.toString();
  }

  /// Ensures the user's referral code is persisted (on the user doc + the
  /// public code→uid map) and returns it. Idempotent and cheap.
  Future<String> ensureReferralCode(String uid) async {
    final code = codeForUid(uid);
    try {
      await _db.collection('users').doc(uid).set(
        {'referralCode': code},
        SetOptions(merge: true),
      );
      final ref = _db.collection('referralCodes').doc(code);
      if (!(await ref.get()).exists) {
        await ref.set({'uid': uid});
      }
    } catch (_) {
      // Non-fatal — the code is deterministic, sharing still works.
    }
    return code;
  }

  /// Records that [uid] was referred by the owner of [rawCode].
  /// Returns null on success, or a user-facing error message.
  Future<String?> redeemCode(String uid, String rawCode) async {
    final code = rawCode.trim().toUpperCase();
    if (code.isEmpty) return 'Digite um código.';
    try {
      final snap = await _db.collection('referralCodes').doc(code).get();
      final referrerId = snap.data()?['uid'] as String?;
      if (referrerId == null) return 'Código inválido.';
      if (referrerId == uid) return 'Você não pode usar seu próprio código.';

      final me = await _db.collection('users').doc(uid).get();
      if ((me.data() ?? const {})['referredBy'] != null) {
        return 'Você já resgatou um convite.';
      }

      await _db.collection('users').doc(uid).set(
        {'referredBy': referrerId},
        SetOptions(merge: true),
      );
      return null;
    } catch (_) {
      return 'Não foi possível resgatar agora. Tente novamente.';
    }
  }
}
