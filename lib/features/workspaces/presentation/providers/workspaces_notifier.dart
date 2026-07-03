import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/workspace_entity.dart';

/// CRUD for the user's OWN workspaces ("Carteiras"). All operations are
/// owner-only (enforced by the Firestore rules).
class WorkspacesNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  final String _uid;
  WorkspacesNotifier(this._ref, this._uid)
      : super(const AsyncValue.data(null));

  FirebaseFirestore get _fs => _ref.read(firestoreProvider);

  /// Creates a workspace and returns its id (null on failure).
  Future<String?> create({
    required String name,
    required WorkspaceType type,
  }) async {
    if (_uid.isEmpty) return null;
    try {
      final doc = await _fs.collection('workspaces').add({
        'ownerId': _uid,
        'name': name,
        'type': type.id,
        'memberUids': [_uid],
        'roles': {_uid: 'editor'},
        'isDefault': false,
        'archived': false,
        'order': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return doc.id;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<bool> rename(String workspaceId, String name) async {
    try {
      await _fs.collection('workspaces').doc(workspaceId).update({'name': name});
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> setArchived(String workspaceId, bool archived) async {
    try {
      await _fs
          .collection('workspaces')
          .doc(workspaceId)
          .update({'archived': archived});
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  static const _ledgerCollections = [
    'transactions',
    'categories',
    'budgets',
    'wallets',
    'goals',
    'recurring_transactions',
    'category_rules',
    'bills',
  ];

  /// Deletes a NON-default workspace and all its ledger docs (cascade,
  /// paginated). The default workspace must never be deleted.
  Future<bool> delete(WorkspaceEntity workspace) async {
    if (workspace.isDefault || workspace.ownerId != _uid) return false;
    try {
      for (final collection in _ledgerCollections) {
        while (true) {
          final snap = await _fs
              .collection(collection)
              .where('userId', isEqualTo: _uid)
              .where('workspaceId', isEqualTo: workspace.id)
              .limit(400)
              .get();
          if (snap.docs.isEmpty) break;
          final batch = _fs.batch();
          for (final d in snap.docs) {
            batch.delete(d.reference);
          }
          await batch.commit();
          if (snap.docs.length < 400) break;
        }
      }
      await _fs.collection('workspaces').doc(workspace.id).delete();
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final workspacesNotifierProvider =
    StateNotifierProvider<WorkspacesNotifier, AsyncValue<void>>((ref) {
  final user = ref.watch(authStateProvider).value;
  return WorkspacesNotifier(ref, user?.id ?? '');
});
