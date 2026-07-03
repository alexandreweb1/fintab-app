import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import 'effective_user_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Workspace migration (P1) — owner-driven, idempotent, no data loss.
//
// On first launch of a workspace-capable build, the OWNER (never a
// collaborator):
//   1. ensures the default "Pessoal" workspace exists (deterministic doc id →
//      concurrent devices can't create duplicates), seeding any legacy
//      account-wide collaborators as editor members;
//   2. records defaultWorkspaceId/captureWorkspaceId on users/{uid};
//   3. backfills workspaceId onto every legacy ledger doc (paginated, skips
//      docs that already have it);
//   4. stamps legacy invitations with workspaceId + role;
//   5. only THEN sets workspaceMigrationV1 = true (interrupted runs resume).
//
// Reads stay on the legacy userId path until P2 flips them, and the client
// treats a missing workspaceId as "default workspace", so nothing ever
// disappears mid-migration.
// ─────────────────────────────────────────────────────────────────────────────

const _ledgerCollections = [
  'transactions',
  'categories',
  'budgets',
  'wallets',
  'goals',
  'recurring_transactions',
  'category_rules',
  'bills',
];

bool _migrationRunning = false;

/// Watched from MainScreen; re-evaluations are cheap no-ops once migrated.
final workspaceMigrationProvider = FutureProvider<void>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return;
  final profileAsync = ref.watch(userProfileStreamProvider);
  if (profileAsync.isLoading) return;
  final profile = profileAsync.value;
  if (profile == null) return;
  if (profile['masterUserId'] != null) return; // collaborator: never migrates
  if (profile['workspaceMigrationV1'] == true) return; // already done
  if (_migrationRunning) return;

  _migrationRunning = true;
  try {
    final fs = ref.read(firestoreProvider);
    final uid = user.id;

    // ── 1. Ensure the default workspace (deterministic id → idempotent). ──
    final wid = 'ws_${uid}_default';
    final wsRef = fs.collection('workspaces').doc(wid);
    final wsSnap = await wsRef.get();
    if (!wsSnap.exists) {
      // Legacy account-wide collaborators become editor members of "Pessoal".
      final accepted = await fs
          .collection('invitations')
          .where('masterUserId', isEqualTo: uid)
          .where('status', isEqualTo: 'accepted')
          .get();
      final collaboratorIds = accepted.docs
          .map((d) => d.data()['collaboratorUserId'] as String?)
          .whereType<String>()
          .toSet()
          .toList();
      await wsRef.set({
        'ownerId': uid,
        'name': 'Pessoal',
        'type': 'personal',
        'memberUids': [uid, ...collaboratorIds],
        'roles': {uid: 'editor', for (final c in collaboratorIds) c: 'editor'},
        'isDefault': true,
        'archived': false,
        'order': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    // ── 2. Record the default on the profile (before the flag, after the ws). ──
    if (profile['defaultWorkspaceId'] != wid) {
      await fs.collection('users').doc(uid).set({
        'defaultWorkspaceId': wid,
        'captureWorkspaceId': profile['captureWorkspaceId'] ?? wid,
      }, SetOptions(merge: true));
    }

    // ── 3. Backfill workspaceId onto legacy ledger docs. ──
    for (final collection in _ledgerCollections) {
      DocumentSnapshot? cursor;
      while (true) {
        var q = fs
            .collection(collection)
            .where('userId', isEqualTo: uid)
            .orderBy(FieldPath.documentId)
            .limit(400);
        if (cursor != null) q = q.startAfterDocument(cursor);
        final snap = await q.get();
        if (snap.docs.isEmpty) break;

        final missing =
            snap.docs.where((d) => !d.data().containsKey('workspaceId'));
        if (missing.isNotEmpty) {
          final batch = fs.batch();
          for (final d in missing) {
            batch.update(d.reference, {'workspaceId': wid});
          }
          await batch.commit();
        }
        if (snap.docs.length < 400) break;
        cursor = snap.docs.last;
      }
    }

    // ── 4. Scope legacy invitations to the default workspace. ──
    final invitations = await fs
        .collection('invitations')
        .where('masterUserId', isEqualTo: uid)
        .get();
    for (final d in invitations.docs) {
      if (d.data().containsKey('workspaceId')) continue;
      await d.reference.update({'workspaceId': wid, 'role': 'editor'});
    }

    // ── 5. Mark done (interrupted runs resume from the top, idempotently). ──
    await fs.collection('users').doc(uid).set(
        {'workspaceMigrationV1': true}, SetOptions(merge: true));
    debugPrint('[WorkspaceMigration] completed for $uid');
  } catch (e) {
    debugPrint('[WorkspaceMigration] failed (will retry next launch): $e');
  } finally {
    _migrationRunning = false;
  }
});
