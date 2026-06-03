import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// User profile stream — watches /users/{uid} in Firestore
// ─────────────────────────────────────────────────────────────────────────────

final userProfileStreamProvider =
    StreamProvider<Map<String, dynamic>?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(null);
  return ref
      .watch(firestoreProvider)
      .collection('users')
      .doc(user.id)
      .snapshots()
      .map((s) => s.data());
});

// ─────────────────────────────────────────────────────────────────────────────
// Effective user ID — master's UID if this user is a collaborator, own UID otherwise
// ─────────────────────────────────────────────────────────────────────────────

final effectiveUserIdProvider = Provider<String>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return '';
  final profileAsync = ref.watch(userProfileStreamProvider);
  // While the profile is still loading, return empty so queries don't fire
  // with the wrong userId (own ID instead of master's ID).
  if (profileAsync.isLoading) return '';
  final profile = profileAsync.value;
  return (profile?['masterUserId'] as String?) ?? user.id;
});

// ─────────────────────────────────────────────────────────────────────────────
// Is master — true when the user owns their data (not a collaborator)
// ─────────────────────────────────────────────────────────────────────────────

final isMasterProvider = Provider<bool>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return true;
  final effectiveId = ref.watch(effectiveUserIdProvider);
  return user.id == effectiveId;
});
