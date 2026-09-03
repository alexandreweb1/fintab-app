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

/// The owner's default ("Pessoal") workspace id — from the profile once the
/// migration has run, else resolved from the own workspace docs (the migration
/// creates the workspace BEFORE stamping the profile, and that second write
/// can fail/lag; selection must keep working meanwhile).
final defaultWorkspaceIdProvider = Provider<String?>((ref) {
  final profile = ref.watch(userProfileStreamProvider).value;
  final fromProfile = profile?['defaultWorkspaceId'] as String?;
  if (fromProfile != null) return fromProfile;
  final own = ref.watch(ownWorkspacesStreamProvider).value ?? const [];
  for (final w in own) {
    if (w.isDefault) return w.id;
  }
  // Resilience: if the migration never stamped the profile / created the
  // deterministic "Pessoal" default (interrupted run, OR a Firestore rules
  // get() on the not-yet-existing default doc was denied — the workspaces read
  // rule dereferences resource.data.ownerId with no `resource == null` guard),
  // fall back to the owner's FIRST Carteira (by order) as the de-facto default.
  // Without this `defaultWs` stays null and activeLedgerScopeProvider takes the
  // pre-migration branch that IGNORES the active-Carteira selection — making
  // the switcher a dead no-op for owners who have Carteiras but no resolved
  // default. Pick the lowest-order Carteira deterministically (independent of
  // stream sort) since this choice anchors where legacy null-workspace docs
  // are read.
  if (own.isNotEmpty) {
    var pick = own.first;
    for (final w in own) {
      if (w.order < pick.order) pick = w;
    }
    return pick.id;
  }
  return null;
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
  // The RESOLVED default (profile stamp, else an isDefault own doc, else the
  // de-facto first-Carteira fallback) counts as default so budget doc-ids stay
  // in the legacy (un-qualified) format there and don't duplicate on edit.
  if (ref.watch(defaultWorkspaceIdProvider) == stamp) return true;
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
    // Don't clobber a selection the user made while prefs were still loading.
    if (mounted && v != null && state == null) state = v;
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
  // Watch only the uid: authStateProvider re-emits on token refresh / profile
  // reload, and recreating the notifier would drop the in-memory selection
  // (racing a tap made moments earlier).
  final uid = ref.watch(authStateProvider.select((a) => a.value?.id));
  return ActiveWorkspaceNotifier(uid ?? '');
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
  final subLoading = ref.watch(isSubscriptionLoadingProvider);
  final selectedRaw = ref.watch(activeWorkspaceIdProvider);
  // Free users are pinned to the default Carteira. While the subscription
  // status is still loading we can't tell Pro from free — honor the selection
  // instead of silently snapping back (the scope re-resolves once it lands).
  final selected = (canSwitch || subLoading) ? selectedRaw : null;

  // ── Legacy account-wide collaborator: read the master's data by userId. ──
  if (masterUserId != null) {
    final shared = ref.watch(sharedWorkspacesStreamProvider).value ?? const [];
    // The collaborator may ALSO own Carteiras of their own (Ajustes › Carteiras
    // lets any Pro user create one — it is not gated on isMaster). Those must
    // stay selectable: resolve the selection against the user's OWN Carteiras
    // (and third-party shared-in ones) BEFORE treating it as "the master's
    // context". Without this every tap on an own Carteira was silently
    // ignored — the pill stayed stuck on the master's default and the
    // switcher looked dead (no paywall, no error).
    if (selected != null) {
      final own = ref.watch(ownWorkspacesStreamProvider).value ?? const [];
      if (selected == kAllWorkspaces) {
        // "Todas juntas" = every OWN Carteira combined (the master's data is
        // a different account and can't be merged into one userId query).
        if (own.isNotEmpty) {
          return UserScope(
              user.id, null, ref.watch(defaultWorkspaceIdProvider));
        }
      } else {
        for (final w in own) {
          if (w.id == selected) {
            return UserScope(
                user.id, w.id, ref.watch(defaultWorkspaceIdProvider));
          }
        }
        for (final w in shared) {
          if (w.id == selected && w.ownerId != masterUserId) {
            return MemberScope(w.id, w.ownerId);
          }
        }
      }
    }
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

  // Falls back to the own default workspace doc when the profile stamp is
  // missing (migration interrupted / profile still syncing) — without this the
  // selection below would be silently ignored and the switcher would look dead.
  final defaultWs = ref.watch(defaultWorkspaceIdProvider);

  // Pre-migration (no workspace docs at all): exactly today's behavior.
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

/// The uid the ROOT LEDGER STREAMS query by on the UserScope path (and that
/// the category/wallet seeds home defaults to). Follows the ACTIVE scope:
/// an owner's own uid; for a legacy account-wide collaborator, the master's
/// uid while the master's context is active but their OWN uid while one of
/// their own Carteiras is selected — otherwise an own Carteira would be read
/// from (and seeded into) the master's account. Empty while the profile is
/// still loading, mirroring [effectiveUserIdProvider], so no query fires with
/// the wrong uid before masterUserId is known.
final ledgerQueryUserIdProvider = Provider<String>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return '';
  if (ref.watch(userProfileStreamProvider).isLoading) return '';
  return ref.watch(ledgerOwnerIdProvider);
});

/// Where background captures (bank notifications, share sheet, clipboard)
/// land: the DEFAULT Carteira of the account the capture is homed to
/// ([effectiveUserIdProvider]) — the owner's own default, or, for a legacy
/// account-wide collaborator, the master's default (null → legacy doc without
/// the field, which the master reads as default anyway). Never the
/// collaborator's own Carteira: a doc homed to the master's uid but stamped
/// with a foreign workspaceId would be invisible in every Carteira view.
final captureWorkspaceIdProvider = Provider<String?>((ref) {
  final profile = ref.watch(userProfileStreamProvider).value;
  final masterUserId = profile?['masterUserId'] as String?;
  if (masterUserId == null) return ref.watch(defaultWorkspaceIdProvider);
  final shared = ref.watch(sharedWorkspacesStreamProvider).value ?? const [];
  for (final w in shared) {
    if (w.ownerId == masterUserId && w.isDefault) return w.id;
  }
  return null;
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
