import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_finance_app/core/providers/workspace_provider.dart';
import 'package:my_finance_app/core/providers/effective_user_provider.dart';
import 'package:my_finance_app/features/auth/domain/entities/user_entity.dart';
import 'package:my_finance_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:my_finance_app/features/subscription/presentation/providers/subscription_provider.dart';
import 'package:my_finance_app/features/workspaces/domain/workspace_entity.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Regression coverage for the "trocar de Carteira não faz nada" bug.
//
// A Pro owner whose migration never produced a resolved default ("Pessoal")
// — e.g. the workspaces read rule denied a get() of the not-yet-existing
// ws_<uid>_default doc, so the client swallowed the error and never stamped
// users/{uid}.defaultWorkspaceId — used to fall into
//   activeLedgerScopeProvider: if (defaultWs == null) return UserScope(uid,null,null)
// which returns BEFORE reading the active selection. Tapping any Carteira
// flipped the raw state but the scope re-resolved identically → dead switch.
//
// The fix makes defaultWorkspaceIdProvider fall back to the owner's first
// Carteira (by order) so the selection is always honored.
// ─────────────────────────────────────────────────────────────────────────────

WorkspaceEntity _ws(
  String id, {
  bool isDefault = false,
  int order = 0,
  WorkspaceType type = WorkspaceType.personal,
  String owner = 'owner1',
}) =>
    WorkspaceEntity(
      id: id,
      ownerId: owner,
      name: id,
      type: type,
      memberUids: [owner],
      roles: {owner: WorkspaceRole.editor},
      isDefault: isDefault,
      order: order,
      createdAt: DateTime(2020, 1, 1),
    );

ProviderContainer _make({
  required Map<String, dynamic>? profile,
  required List<WorkspaceEntity> own,
  List<WorkspaceEntity> shared = const [],
  bool pro = true,
  bool subLoading = false,
  String user = 'owner1',
}) {
  return ProviderContainer(overrides: [
    authStateProvider
        .overrideWith((ref) => Stream.value(UserEntity(id: user, email: 't@t.co'))),
    userProfileStreamProvider.overrideWith((ref) => Stream.value(profile)),
    ownWorkspacesStreamProvider.overrideWith((ref) => Stream.value(own)),
    sharedWorkspacesStreamProvider.overrideWith((ref) => Stream.value(shared)),
    canUseWorkspacesProvider.overrideWithValue(pro),
    isSubscriptionLoadingProvider.overrideWithValue(subLoading),
  ]);
}

Future<void> _settle(ProviderContainer c) async {
  await c.read(authStateProvider.future);
  await c.read(userProfileStreamProvider.future);
  await c.read(ownWorkspacesStreamProvider.future);
  await c.read(sharedWorkspacesStreamProvider.future);
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  group('defaultWorkspaceIdProvider fallback', () {
    test('no profile stamp + no isDefault doc → first own Carteira by order',
        () async {
      final c = _make(profile: null, own: [
        _ws('empresa', order: 2, type: WorkspaceType.business),
        _ws('familia', order: 1),
      ]);
      addTearDown(c.dispose);
      await _settle(c);
      // own is pre-sorted by order in the stream provider; the fallback picks
      // the lowest-order Carteira.
      expect(c.read(defaultWorkspaceIdProvider), 'familia');
    });

    test('profile stamp wins over the fallback', () async {
      final c = _make(
        profile: {'defaultWorkspaceId': 'ws_default'},
        own: [_ws('ws_default', isDefault: true, order: 0), _ws('empresa', order: 2)],
      );
      addTearDown(c.dispose);
      await _settle(c);
      expect(c.read(defaultWorkspaceIdProvider), 'ws_default');
    });

    test('truly pre-migration (no Carteiras) stays null', () async {
      final c = _make(profile: null, own: const []);
      addTearDown(c.dispose);
      await _settle(c);
      expect(c.read(defaultWorkspaceIdProvider), isNull);
    });
  });

  group('activeLedgerScopeProvider honors the selection', () {
    test('REGRESSION: Pro owner with no resolved default → tapping a Carteira '
        'filters to it (was a dead no-op)', () async {
      final c = _make(profile: null, own: [
        _ws('familia', order: 1),
        _ws('empresa', order: 2, type: WorkspaceType.business),
      ]);
      addTearDown(c.dispose);
      await _settle(c);

      c.read(activeWorkspaceIdProvider.notifier).select('empresa');

      final scope = c.read(activeLedgerScopeProvider);
      expect(scope, isA<UserScope>());
      scope as UserScope;
      expect(scope.userId, 'owner1');
      expect(scope.workspaceId, 'empresa'); // selection honored (was null pre-fix)
      expect(scope.defaultWorkspaceId, 'familia'); // de-facto default
      // The header pill / checkmark follow this.
      expect(c.read(activeWorkspaceProvider)?.id, 'empresa');
      expect(c.read(isCombinedViewProvider), false);
    });

    test('selecting the de-facto default keeps legacy (null-workspace) data '
        'and un-qualified budget doc-ids', () async {
      final c = _make(profile: null, own: [
        _ws('familia', order: 1),
        _ws('empresa', order: 2),
      ]);
      addTearDown(c.dispose);
      await _settle(c);

      c.read(activeWorkspaceIdProvider.notifier).select('familia');

      final scope = c.read(activeLedgerScopeProvider) as UserScope;
      expect(scope.workspaceId, 'familia');
      expect(scope.defaultWorkspaceId, 'familia');
      // Budget doc-ids must stay legacy-format in the de-facto default so
      // editing a pre-existing budget updates it in place (no duplicate).
      expect(c.read(workspaceStampProvider), 'familia');
      expect(c.read(workspaceStampIsDefaultProvider), true);
    });

    test('"Todas juntas" resolves to the combined view', () async {
      final c = _make(profile: null, own: [
        _ws('familia', order: 1),
        _ws('empresa', order: 2),
      ]);
      addTearDown(c.dispose);
      await _settle(c);

      c.read(activeWorkspaceIdProvider.notifier).select(kAllWorkspaces);

      expect(c.read(isCombinedViewProvider), true);
      final scope = c.read(activeLedgerScopeProvider) as UserScope;
      expect(scope.workspaceId, isNull);
      expect(scope.defaultWorkspaceId, 'familia');
    });

    test('free user stays pinned to the (now resolved) default, selection '
        'ignored — intended gating', () async {
      final c = _make(
        profile: null,
        own: [_ws('familia', order: 1), _ws('empresa', order: 2)],
        pro: false,
      );
      addTearDown(c.dispose);
      await _settle(c);

      c.read(activeWorkspaceIdProvider.notifier).select('empresa');

      final scope = c.read(activeLedgerScopeProvider) as UserScope;
      // Not the dead null scope anymore — a concrete default the streams can read.
      expect(scope.workspaceId, 'familia');
      expect(scope.defaultWorkspaceId, 'familia');
    });

    test('migrated user with a real default switches normally', () async {
      final c = _make(
        profile: {'defaultWorkspaceId': 'ws_default'},
        own: [_ws('ws_default', isDefault: true, order: 0), _ws('empresa', order: 2)],
      );
      addTearDown(c.dispose);
      await _settle(c);

      c.read(activeWorkspaceIdProvider.notifier).select('empresa');

      final scope = c.read(activeLedgerScopeProvider) as UserScope;
      expect(scope.workspaceId, 'empresa');
      expect(scope.defaultWorkspaceId, 'ws_default');
      // And the default itself stays default for budget doc-ids.
      c.read(activeWorkspaceIdProvider.notifier).select('ws_default');
      expect(c.read(workspaceStampIsDefaultProvider), true);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Regression: legacy account-wide collaborator (users/{uid}.masterUserId set)
  // who ALSO owns Carteiras. Creation is reachable via Ajustes › Carteiras
  // (Pro-gated only, not isMaster-gated), but activeLedgerScopeProvider's
  // masterUserId branch used to resolve the selection ONLY against the
  // master's shared workspaces — every tap on an own Carteira was silently
  // ignored (no paywall, no error): the pill stayed stuck on the master's
  // default. Reads/seeds also queried effectiveUserId (the master) instead of
  // the active scope's uid.
  // ───────────────────────────────────────────────────────────────────────────
  group('legacy collaborator (profile.masterUserId) who also owns Carteiras',
      () {
    const master = 'master1';
    final masterDefault =
        _ws('ws_master1_default', isDefault: true, order: 0, owner: master);
    final masterBiz = _ws('master_empresa', order: 5, owner: master);
    final thirdParty = _ws('amigo_ws', order: 0, owner: 'friend1');
    final ownPf = _ws('minha_pf', order: 1);
    final ownPj = _ws('minha_pj', order: 2, type: WorkspaceType.business);

    test('no selection → the master\'s default (unchanged home context)',
        () async {
      final c = _make(
        profile: {'masterUserId': master},
        own: [ownPf, ownPj],
        shared: [masterDefault, masterBiz],
      );
      addTearDown(c.dispose);
      await _settle(c);

      final scope = c.read(activeLedgerScopeProvider) as UserScope;
      expect(scope.userId, master);
      expect(scope.workspaceId, 'ws_master1_default');
      expect(scope.defaultWorkspaceId, 'ws_master1_default');
      expect(c.read(ledgerQueryUserIdProvider), master);
      expect(c.read(ledgerOwnerIdProvider), master);
      expect(c.read(activeWorkspaceProvider)?.id, 'ws_master1_default');
    });

    test('REGRESSION: tapping an OWN Carteira is honored — reads AND writes '
        'home to the collaborator\'s own uid (was a dead no-op on the master)',
        () async {
      final c = _make(
        profile: {'masterUserId': master},
        own: [ownPf, ownPj],
        shared: [masterDefault, masterBiz],
      );
      addTearDown(c.dispose);
      await _settle(c);

      c.read(activeWorkspaceIdProvider.notifier).select('minha_pj');

      final scope = c.read(activeLedgerScopeProvider);
      expect(scope, isA<UserScope>());
      scope as UserScope;
      expect(scope.userId, 'owner1'); // NOT the master
      expect(scope.workspaceId, 'minha_pj');
      expect(scope.defaultWorkspaceId, 'minha_pf'); // de-facto own default
      expect(c.read(activeWorkspaceProvider)?.id, 'minha_pj');
      expect(c.read(isCombinedViewProvider), false);
      // Root streams / seeds query the OWN uid; new docs are homed + stamped
      // to the own Carteira (never seeded into the master's account).
      expect(c.read(ledgerQueryUserIdProvider), 'owner1');
      expect(c.read(ledgerOwnerIdProvider), 'owner1');
      expect(c.read(workspaceStampProvider), 'minha_pj');
      expect(c.read(workspaceStampIsDefaultProvider), false);
    });

    test('own de-facto default keeps un-qualified budget doc-ids', () async {
      final c = _make(
        profile: {'masterUserId': master},
        own: [ownPf, ownPj],
        shared: [masterDefault],
      );
      addTearDown(c.dispose);
      await _settle(c);

      c.read(activeWorkspaceIdProvider.notifier).select('minha_pf');

      final scope = c.read(activeLedgerScopeProvider) as UserScope;
      expect(scope.userId, 'owner1');
      expect(scope.workspaceId, 'minha_pf');
      expect(c.read(workspaceStampProvider), 'minha_pf');
      expect(c.read(workspaceStampIsDefaultProvider), true);
    });

    test('the master\'s Carteiras still resolve to the master\'s account',
        () async {
      final c = _make(
        profile: {'masterUserId': master},
        own: [ownPf, ownPj],
        shared: [masterDefault, masterBiz],
      );
      addTearDown(c.dispose);
      await _settle(c);

      c.read(activeWorkspaceIdProvider.notifier).select('master_empresa');

      final scope = c.read(activeLedgerScopeProvider) as UserScope;
      expect(scope.userId, master);
      expect(scope.workspaceId, 'master_empresa');
      expect(scope.defaultWorkspaceId, 'ws_master1_default');
      expect(c.read(ledgerQueryUserIdProvider), master);
      expect(c.read(activeWorkspaceProvider)?.id, 'master_empresa');
    });

    test('"Todas juntas" = combined view of the OWN Carteiras', () async {
      final c = _make(
        profile: {'masterUserId': master},
        own: [ownPf, ownPj],
        shared: [masterDefault],
      );
      addTearDown(c.dispose);
      await _settle(c);

      c.read(activeWorkspaceIdProvider.notifier).select(kAllWorkspaces);

      final scope = c.read(activeLedgerScopeProvider) as UserScope;
      expect(scope.userId, 'owner1');
      expect(scope.workspaceId, isNull);
      expect(scope.defaultWorkspaceId, 'minha_pf');
      expect(c.read(isCombinedViewProvider), true);
      expect(c.read(ledgerQueryUserIdProvider), 'owner1');
    });

    test('"Todas juntas" with NO own Carteiras stays on the master', () async {
      final c = _make(
        profile: {'masterUserId': master},
        own: const [],
        shared: [masterDefault],
      );
      addTearDown(c.dispose);
      await _settle(c);

      c.read(activeWorkspaceIdProvider.notifier).select(kAllWorkspaces);

      final scope = c.read(activeLedgerScopeProvider) as UserScope;
      expect(scope.userId, master);
      expect(scope.workspaceId, 'ws_master1_default');
    });

    test('a third-party shared-in Carteira resolves to MemberScope', () async {
      final c = _make(
        profile: {'masterUserId': master},
        own: [ownPf],
        shared: [masterDefault, thirdParty],
      );
      addTearDown(c.dispose);
      await _settle(c);

      c.read(activeWorkspaceIdProvider.notifier).select('amigo_ws');

      final scope = c.read(activeLedgerScopeProvider);
      expect(scope, isA<MemberScope>());
      scope as MemberScope;
      expect(scope.workspaceId, 'amigo_ws');
      expect(scope.ownerId, 'friend1');
      expect(c.read(ledgerOwnerIdProvider), 'friend1');
    });

    test('orphaned selection falls back to the master\'s default', () async {
      final c = _make(
        profile: {'masterUserId': master},
        own: [ownPf],
        shared: [masterDefault],
      );
      addTearDown(c.dispose);
      await _settle(c);

      c.read(activeWorkspaceIdProvider.notifier).select('deleted_ws');

      final scope = c.read(activeLedgerScopeProvider) as UserScope;
      expect(scope.userId, master);
      expect(scope.workspaceId, 'ws_master1_default');
    });

    test('free collaborator stays pinned to the master (Pro gating unchanged)',
        () async {
      final c = _make(
        profile: {'masterUserId': master},
        own: [ownPf, ownPj],
        shared: [masterDefault],
        pro: false,
      );
      addTearDown(c.dispose);
      await _settle(c);

      c.read(activeWorkspaceIdProvider.notifier).select('minha_pj');

      final scope = c.read(activeLedgerScopeProvider) as UserScope;
      expect(scope.userId, master);
      expect(scope.workspaceId, 'ws_master1_default');
    });

    test('background capture targets the master\'s default, never an own '
        'Carteira (even while an own Carteira is active)', () async {
      final c = _make(
        profile: {'masterUserId': master},
        own: [ownPf, ownPj],
        shared: [masterDefault],
      );
      addTearDown(c.dispose);
      await _settle(c);

      c.read(activeWorkspaceIdProvider.notifier).select('minha_pj');

      expect(c.read(captureWorkspaceIdProvider), 'ws_master1_default');
      // Unknown master default (master not migrated / not a member of it) →
      // null → legacy doc without the field, read as default by the master.
      final c2 = _make(
        profile: {'masterUserId': master},
        own: [ownPf],
        shared: const [],
      );
      addTearDown(c2.dispose);
      await _settle(c2);
      expect(c2.read(captureWorkspaceIdProvider), isNull);
    });

    test('owner: background capture targets the own default', () async {
      final c = _make(
        profile: {'defaultWorkspaceId': 'ws_default'},
        own: [
          _ws('ws_default', isDefault: true, order: 0),
          _ws('empresa', order: 2)
        ],
      );
      addTearDown(c.dispose);
      await _settle(c);
      c.read(activeWorkspaceIdProvider.notifier).select('empresa');
      expect(c.read(captureWorkspaceIdProvider), 'ws_default');
      expect(c.read(ledgerQueryUserIdProvider), 'owner1');
    });
  });
}
