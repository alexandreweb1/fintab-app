import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/subscription/presentation/providers/subscription_provider.dart';
import '../../features/workspaces/data/workspace_model.dart';
import '../../features/workspaces/domain/workspace_entity.dart';
import 'effective_user_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Workspaces ("Carteiras" PF/PJ) — streams + write-stamp scope.
//
// P0/P1 plumbing: writes stamp the owner's default workspace once the owner
// has migrated; reads stay on the legacy userId path until P2 flips them.
// ─────────────────────────────────────────────────────────────────────────────

/// Workspaces the signed-in user OWNS.
final ownWorkspacesStreamProvider =
    StreamProvider<List<WorkspaceEntity>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(const []);
  return ref
      .watch(firestoreProvider)
      .collection('workspaces')
      .where('ownerId', isEqualTo: user.id)
      .snapshots()
      .map((s) {
    final list = s.docs
        .map((d) => WorkspaceModel.fromFirestore(d) as WorkspaceEntity)
        .toList();
    list.sort((a, b) => a.order.compareTo(b.order));
    return list;
  });
});

/// Workspaces SHARED WITH the signed-in user (member but not owner).
final sharedWorkspacesStreamProvider =
    StreamProvider<List<WorkspaceEntity>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(const []);
  return ref
      .watch(firestoreProvider)
      .collection('workspaces')
      .where('memberUids', arrayContains: user.id)
      .snapshots()
      .map((s) => s.docs
          .map((d) => WorkspaceModel.fromFirestore(d) as WorkspaceEntity)
          .where((w) => w.ownerId != user.id)
          .toList());
});

/// Own + shared-in workspaces (own first, by order).
final allWorkspacesProvider = Provider<List<WorkspaceEntity>>((ref) {
  final own = ref.watch(ownWorkspacesStreamProvider).value ?? const [];
  final shared = ref.watch(sharedWorkspacesStreamProvider).value ?? const [];
  return [...own, ...shared];
});

/// The owner's default ("Pessoal") workspace id from their profile — null
/// until the migration has run.
final defaultWorkspaceIdProvider = Provider<String?>((ref) {
  final profile = ref.watch(userProfileStreamProvider).value;
  return profile?['defaultWorkspaceId'] as String?;
});

/// The workspaceId that write notifiers stamp on NEW ledger docs — follows the
/// ACTIVE Carteira.
///
/// - Own Carteira selected → that Carteira.
/// - Combined "Todas juntas" → the default Carteira (new entries need one
///   concrete home; the switcher explains this).
/// - Shared-in Carteira → that Carteira (viewers are blocked by rules anyway).
/// - Pre-migration → null → models omit the field (legacy create rule path).
final workspaceStampProvider = Provider<String?>((ref) {
  final scope = ref.watch(activeLedgerScopeProvider);
  return switch (scope) {
    UserScope s => s.workspaceId ?? s.defaultWorkspaceId,
    MemberScope s => s.workspaceId,
  };
});

/// Whether the current write-stamp targets the owner's DEFAULT workspace.
///
/// Budget doc-ids stay in the legacy format inside the default workspace (so
/// edits keep hitting the pre-migration docs instead of duplicating them) and
/// only get workspace-qualified in additional (non-default) workspaces.
final workspaceStampIsDefaultProvider = Provider<bool>((ref) {
  final stamp = ref.watch(workspaceStampProvider);
  if (stamp == null) return true; // legacy mode behaves as default
  final profile = ref.watch(userProfileStreamProvider).value;
  if (profile?['defaultWorkspaceId'] == stamp) return true;
  final shared = ref.watch(sharedWorkspacesStreamProvider).value ?? const [];
  for (final w in shared) {
    if (w.id == stamp) return w.isDefault;
  }
  final own = ref.watch(ownWorkspacesStreamProvider).value ?? const [];
  for (final w in own) {
    if (w.id == stamp) return w.isDefault;
  }
  return false;
});

// ─────────────────────────────────────────────────────────────────────────────
// P2 — Active Carteira selection + ledger read scope.
// ─────────────────────────────────────────────────────────────────────────────

/// Sentinel meaning "Todas juntas" (consolidated view of the user's OWN
/// Carteiras). Never a real workspace id.
const kAllWorkspaces = '__ALL__';

/// Multiple Carteiras is a Pro feature (data is never gated — only creating
/// and switching).
final canUseWorkspacesProvider = Provider<bool>((ref) {
  return ref.watch(isProProvider);
});

/// The user's selected Carteira id ([kAllWorkspaces] = combined view; null =
/// default). Persisted per-uid in SharedPreferences.
class ActiveWorkspaceNotifier extends StateNotifier<String?> {
  final String _uid;
  ActiveWorkspaceNotifier(this._uid) : super(null) {
    _load();
  }

  String get _key => 'active_workspace_$_uid';

  Future<void> _load() async {
    if (_uid.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_key);
    if (mounted && v != null) state = v;
  }

  Future<void> select(String? workspaceId) async {
    state = workspaceId;
    if (_uid.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    if (workspaceId == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, workspaceId);
    }
  }
}

final activeWorkspaceIdProvider =
    StateNotifierProvider<ActiveWorkspaceNotifier, String?>((ref) {
  final user = ref.watch(authStateProvider).value;
  return ActiveWorkspaceNotifier(user?.id ?? '');
});

// ── Ledger read scope ────────────────────────────────────────────────────────

/// How the 8 ledger root streams should query + filter.
sealed class LedgerScope {
  const LedgerScope();
}

/// Query `where('userId'==userId)` and filter by workspace CLIENT-SIDE.
/// Covers: the owner (any of their Carteiras or the combined view) and legacy
/// account-wide collaborators (userId = master's uid). Docs without a
/// workspaceId belong to [defaultWorkspaceId]. [workspaceId] == null means the
/// combined "Todas juntas" view (no filter).
class UserScope extends LedgerScope {
  final String userId;
  final String? workspaceId;
  final String? defaultWorkspaceId;
  const UserScope(this.userId, this.workspaceId, this.defaultWorkspaceId);

  @override
  bool operator ==(Object other) =>
      other is UserScope &&
      other.userId == userId &&
      other.workspaceId == workspaceId &&
      other.defaultWorkspaceId == defaultWorkspaceId;
  @override
  int get hashCode => Object.hash(userId, workspaceId, defaultWorkspaceId);
}

/// Query `where('workspaceId'==workspaceId)` SERVER-SIDE — used by NEW-style
/// shared members (no masterUserId link), authorized by workspace membership.
class MemberScope extends LedgerScope {
  final String workspaceId;
  final String ownerId;
  const MemberScope(this.workspaceId, this.ownerId);

  @override
  bool operator ==(Object other) =>
      other is MemberScope &&
      other.workspaceId == workspaceId &&
      other.ownerId == ownerId;
  @override
  int get hashCode => Object.hash(workspaceId, ownerId);
}

/// Resolves what the ledger streams should read right now.
final activeLedgerScopeProvider = Provider<LedgerScope>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return const UserScope('', null, null);

  final profile = ref.watch(userProfileStreamProvider).value;
  final masterUserId = profile?['masterUserId'] as String?;
  final canSwitch = ref.watch(canUseWorkspacesProvider);
  final selectedRaw = ref.watch(activeWorkspaceIdProvider);
  final selected = canSwitch ? selectedRaw : null; // free users: default only

  // ── Legacy account-wide collaborator: read the master's data by userId. ──
  if (masterUserId != null) {
    final shared = ref.watch(sharedWorkspacesStreamProvider).value ?? const [];
    String? masterDefault;
    for (final w in shared) {
      if (w.ownerId == masterUserId && w.isDefault) masterDefault = w.id;
    }
    // Selection restricted to the master's workspaces.
    String? ws = masterDefault;
    if (selected != null && selected != kAllWorkspaces) {
      for (final w in shared) {
        if (w.id == selected && w.ownerId == masterUserId) ws = w.id;
      }
    }
    return UserScope(masterUserId, ws, masterDefault);
  }

  final defaultWs = profile?['defaultWorkspaceId'] as String?;

  // Pre-migration: exactly today's behavior (no filter).
  if (defaultWs == null) return UserScope(user.id, null, null);

  if (selected == null) return UserScope(user.id, defaultWs, defaultWs);
  if (selected == kAllWorkspaces) return UserScope(user.id, null, defaultWs);

  // Own workspace?
  final own = ref.watch(ownWorkspacesStreamProvider).value ?? const [];
  for (final w in own) {
    if (w.id == selected) return UserScope(user.id, w.id, defaultWs);
  }
  // Shared-in workspace (new-style membership)?
  final shared = ref.watch(sharedWorkspacesStreamProvider).value ?? const [];
  for (final w in shared) {
    if (w.id == selected) return MemberScope(w.id, w.ownerId);
  }
  // Orphaned selection (deleted/archived workspace) → default.
  return UserScope(user.id, defaultWs, defaultWs);
});

/// The active [WorkspaceEntity] (null in combined view / pre-migration).
final activeWorkspaceProvider = Provider<WorkspaceEntity?>((ref) {
  final scope = ref.watch(activeLedgerScopeProvider);
  final all = ref.watch(allWorkspacesProvider);
  final id = switch (scope) {
    UserScope s => s.workspaceId,
    MemberScope s => s.workspaceId,
  };
  if (id == null) return null;
  for (final w in all) {
    if (w.id == id) return w;
  }
  return null;
});

/// True when the combined "Todas juntas" view is active.
final isCombinedViewProvider = Provider<bool>((ref) {
  final scope = ref.watch(activeLedgerScopeProvider);
  return scope is UserScope && scope.workspaceId == null &&
      scope.defaultWorkspaceId != null;
});

/// The uid ledger docs must be homed to (`userId` field on writes). This is
/// what write notifiers use instead of effectiveUserIdProvider once scopes
/// exist: for a shared member it's the WORKSPACE OWNER's uid.
final ledgerOwnerIdProvider = Provider<String>((ref) {
  final scope = ref.watch(activeLedgerScopeProvider);
  return switch (scope) {
    UserScope s => s.userId,
    MemberScope s => s.ownerId,
  };
});

/// Filters a ledger list according to [scope] (no-op for MemberScope — those
/// queries are already server-filtered).
List<T> applyWorkspaceScope<T>(
  List<T> items,
  String? Function(T) workspaceIdOf,
  LedgerScope scope,
) {
  switch (scope) {
    case UserScope s:
      if (s.workspaceId == null) return items; // combined / pre-migration
      return items.where((it) {
        final w = workspaceIdOf(it);
        if (w == null) return s.workspaceId == s.defaultWorkspaceId;
        return w == s.workspaceId;
      }).toList();
    case MemberScope _:
      return items;
  }
}

/// Server-side query for a shared workspace's docs in [collection].
Query<Map<String, dynamic>> workspaceCollectionQuery(
  FirebaseFirestore fs,
  String collection,
  String workspaceId,
) {
  return fs.collection(collection).where('workspaceId', isEqualTo: workspaceId);
}
