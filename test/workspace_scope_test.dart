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
}
