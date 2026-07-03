import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/providers/effective_user_provider.dart';
import '../../../core/providers/workspace_provider.dart';
import '../../subscription/presentation/widgets/pro_gate_widget.dart';
import '../domain/workspace_entity.dart';
import 'providers/workspaces_notifier.dart';

IconData workspaceIcon(WorkspaceType type) => type == WorkspaceType.business
    ? Icons.business_center_rounded
    : Icons.person_rounded;

/// Slim global bar that shows the active Carteira and opens the switcher.
/// Rendered above the tab content on every screen; hidden while the user has
/// a single context (nothing to switch).
class WorkspaceSwitcherBar extends ConsumerWidget {
  const WorkspaceSwitcherBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    if (!ref.watch(canUseWorkspacesProvider)) return const SizedBox.shrink();

    final own = (ref.watch(ownWorkspacesStreamProvider).value ?? const [])
        .where((w) => !w.archived)
        .toList();
    final shared = ref.watch(sharedWorkspacesStreamProvider).value ?? const [];
    final contexts = own.length + shared.length;
    if (contexts < 2) return const SizedBox.shrink();

    final active = ref.watch(activeWorkspaceProvider);
    final combined = ref.watch(isCombinedViewProvider);
    final label = combined
        ? l10n.allWorkspaces
        : (active?.name ?? l10n.workspacePersonal);
    final icon = combined
        ? Icons.dashboard_customize_rounded
        : workspaceIcon(active?.type ?? WorkspaceType.personal);

    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
      child: InkWell(
        onTap: () => showWorkspaceSwitcherSheet(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Row(
            children: [
              Icon(icon, size: 16, color: cs.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              Icon(Icons.unfold_more_rounded,
                  size: 16, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet listing all contexts: own Carteiras, "Todas juntas",
/// shared-in Carteiras, plus create/manage actions.
Future<void> showWorkspaceSwitcherSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const _SwitcherSheet(),
  );
}

class _SwitcherSheet extends ConsumerWidget {
  const _SwitcherSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final own = (ref.watch(ownWorkspacesStreamProvider).value ?? const [])
        .where((w) => !w.archived)
        .toList();
    final shared = ref.watch(sharedWorkspacesStreamProvider).value ?? const [];
    final active = ref.watch(activeWorkspaceProvider);
    final combined = ref.watch(isCombinedViewProvider);
    final isMaster = ref.watch(isMasterProvider);

    void select(String? id) {
      ref.read(activeWorkspaceIdProvider.notifier).select(id);
      Navigator.of(context).pop();
    }

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
              child: Text(l10n.workspaceSwitchTo,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            ...own.map((w) => ListTile(
                  leading: Icon(workspaceIcon(w.type),
                      color: w.isBusiness ? const Color(0xFF7B1FA2) : cs.primary),
                  title: Text(w.name),
                  subtitle: Text(w.isBusiness
                      ? l10n.workspaceBusiness
                      : l10n.workspacePersonal),
                  trailing: (!combined && active?.id == w.id)
                      ? Icon(Icons.check_circle_rounded, color: cs.primary)
                      : null,
                  onTap: () => select(w.id),
                )),
            if (own.length > 1)
              ListTile(
                leading: const Icon(Icons.dashboard_customize_rounded),
                title: Text(l10n.allWorkspaces),
                subtitle: Text(l10n.allWorkspacesHint,
                    style: const TextStyle(fontSize: 11.5)),
                trailing: combined
                    ? Icon(Icons.check_circle_rounded, color: cs.primary)
                    : null,
                onTap: () => select(kAllWorkspaces),
              ),
            if (shared.isNotEmpty) ...[
              const Divider(height: 12),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 2),
                child: Text(l10n.workspaceSharedWithMe,
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurfaceVariant)),
              ),
              ...shared.map((w) => ListTile(
                    leading: Icon(Icons.group_rounded, color: cs.tertiary),
                    title: Text(w.name),
                    subtitle: Text(w.isBusiness
                        ? l10n.workspaceBusiness
                        : l10n.workspacePersonal),
                    trailing: active?.id == w.id
                        ? Icon(Icons.check_circle_rounded, color: cs.primary)
                        : null,
                    onTap: () => select(w.id),
                  )),
            ],
            if (isMaster) ...[
              const Divider(height: 12),
              ListTile(
                leading: Icon(Icons.add_circle_outline, color: cs.primary),
                title: Text(l10n.newWorkspace),
                onTap: () async {
                  Navigator.of(context).pop();
                  await showCreateWorkspaceDialog(context, ref);
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: Text(l10n.manageWorkspaces),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const ManageWorkspacesScreen()));
                },
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// Create dialog — Pro-gated (multiple Carteiras is a Pro feature).
Future<void> showCreateWorkspaceDialog(
    BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  if (!ref.read(canUseWorkspacesProvider)) {
    showProGateBottomSheet(
      context,
      featureName: l10n.workspaces,
      featureDescription: l10n.workspacesDesc,
      featureIcon: Icons.business_center_rounded,
    );
    return;
  }
  await showDialog<void>(
    context: context,
    builder: (_) => const _CreateWorkspaceDialog(),
  );
}

class _CreateWorkspaceDialog extends ConsumerStatefulWidget {
  const _CreateWorkspaceDialog();
  @override
  ConsumerState<_CreateWorkspaceDialog> createState() =>
      _CreateWorkspaceDialogState();
}

class _CreateWorkspaceDialogState
    extends ConsumerState<_CreateWorkspaceDialog> {
  final _name = TextEditingController();
  WorkspaceType _type = WorkspaceType.business;
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final l10n = AppLocalizations.of(context);
    final name = _name.text.trim();
    if (name.isEmpty) return;
    setState(() => _loading = true);
    final id = await ref
        .read(workspacesNotifierProvider.notifier)
        .create(name: name, type: _type);
    if (!mounted) return;
    setState(() => _loading = false);
    if (id != null) {
      // Jump straight into the new Carteira.
      await ref.read(activeWorkspaceIdProvider.notifier).select(id);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${l10n.newWorkspace}: $name ✓')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.newWorkspace),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SegmentedButton<WorkspaceType>(
            segments: [
              ButtonSegment(
                  value: WorkspaceType.personal,
                  icon: const Icon(Icons.person_rounded, size: 16),
                  label: Text(l10n.workspacePersonal)),
              ButtonSegment(
                  value: WorkspaceType.business,
                  icon: const Icon(Icons.business_center_rounded, size: 16),
                  label: Text(l10n.workspaceBusiness)),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: l10n.workspaceName,
              hintText: _type == WorkspaceType.business
                  ? 'Minha Empresa, Holding…'
                  : 'Família, Viagem…',
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: _loading ? null : () => Navigator.pop(context),
            child: Text(l10n.cancel)),
        FilledButton(
          onPressed: _loading ? null : _create,
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(l10n.create),
        ),
      ],
    );
  }
}

/// Full management screen: rename / archive / delete own Carteiras.
class ManageWorkspacesScreen extends ConsumerWidget {
  const ManageWorkspacesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final own = ref.watch(ownWorkspacesStreamProvider).value ?? const [];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.manageWorkspaces)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showCreateWorkspaceDialog(context, ref),
        icon: const Icon(Icons.add),
        label: Text(l10n.newWorkspace),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
        children: own
            .map((w) => Card(
                  elevation: 0,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                        color: cs.outlineVariant.withValues(alpha: 0.5)),
                  ),
                  child: ListTile(
                    leading: Icon(workspaceIcon(w.type),
                        color:
                            w.isBusiness ? const Color(0xFF7B1FA2) : cs.primary),
                    title: Row(children: [
                      Flexible(child: Text(w.name)),
                      if (w.isDefault)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Icon(Icons.star_rounded,
                              size: 15, color: cs.tertiary),
                        ),
                      if (w.archived)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Icon(Icons.archive_outlined,
                              size: 15, color: cs.onSurfaceVariant),
                        ),
                    ]),
                    subtitle: Text(w.isBusiness
                        ? l10n.workspaceBusiness
                        : l10n.workspacePersonal),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) => _onAction(context, ref, w, v),
                      itemBuilder: (_) => [
                        PopupMenuItem(value: 'rename', child: Text(l10n.edit)),
                        if (!w.isDefault)
                          PopupMenuItem(
                              value: 'archive',
                              child: Text(w.archived
                                  ? l10n.unarchiveWorkspace
                                  : l10n.archiveWorkspace)),
                        if (!w.isDefault)
                          PopupMenuItem(
                              value: 'delete',
                              child: Text(l10n.deleteWorkspace,
                                  style: TextStyle(color: cs.error))),
                      ],
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Future<void> _onAction(BuildContext context, WidgetRef ref,
      WorkspaceEntity w, String action) async {
    final l10n = AppLocalizations.of(context);
    final notifier = ref.read(workspacesNotifierProvider.notifier);
    switch (action) {
      case 'rename':
        final ctrl = TextEditingController(text: w.name);
        final name = await showDialog<String>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(l10n.workspaceName),
            content: TextField(
              controller: ctrl,
              autofocus: true,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(c),
                  child: Text(l10n.cancel)),
              FilledButton(
                  onPressed: () => Navigator.pop(c, ctrl.text.trim()),
                  child: Text(l10n.save)),
            ],
          ),
        );
        if (name != null && name.isNotEmpty) await notifier.rename(w.id, name);
      case 'archive':
        await notifier.setArchived(w.id, !w.archived);
      case 'delete':
        if (w.isDefault) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(l10n.cannotDeleteDefaultWorkspace)));
          return;
        }
        final ctrl = TextEditingController();
        final ok = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text('${l10n.deleteWorkspace}: ${w.name}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.deleteWorkspaceWarning,
                    style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 12),
                Text('Digite "${w.name}" para confirmar:',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: ctrl,
                  decoration:
                      const InputDecoration(border: OutlineInputBorder()),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  child: Text(l10n.cancel)),
              ValueListenableBuilder(
                valueListenable: ctrl,
                builder: (_, v, __) => FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(c).colorScheme.error),
                  onPressed: v.text.trim() == w.name
                      ? () => Navigator.pop(c, true)
                      : null,
                  child: Text(l10n.delete),
                ),
              ),
            ],
          ),
        );
        if (ok == true) {
          // If deleting the active Carteira, fall back to the default first.
          final activeId = ref.read(activeWorkspaceIdProvider);
          if (activeId == w.id) {
            await ref.read(activeWorkspaceIdProvider.notifier).select(null);
          }
          await notifier.delete(w);
        }
    }
  }
}
