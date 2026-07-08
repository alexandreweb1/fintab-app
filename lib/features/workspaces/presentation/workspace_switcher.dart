import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/providers/effective_user_provider.dart';
import '../../../core/providers/workspace_provider.dart';
import '../../subscription/presentation/providers/subscription_provider.dart';
import '../../subscription/presentation/widgets/pro_gate_widget.dart';
import '../domain/workspace_entity.dart';
import 'providers/workspaces_notifier.dart';

IconData workspaceIcon(WorkspaceType type) => type == WorkspaceType.business
    ? Icons.business_center_rounded
    : Icons.person_rounded;

/// Short PF/PJ badge for a Carteira type. [onDark] tunes it for the navy
/// dashboard header; otherwise it uses theme colors for light surfaces.
class CarteiraTypeBadge extends StatelessWidget {
  final WorkspaceType type;
  final bool onDark;
  const CarteiraTypeBadge({super.key, required this.type, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    final isBiz = type == WorkspaceType.business;
    final text = isBiz ? 'PJ' : 'PF';
    final Color bg;
    final Color fg;
    if (onDark) {
      bg = Colors.white.withValues(alpha: 0.16);
      fg = isBiz ? const Color(0xFFE1BEE7) : Colors.white;
    } else {
      final base = isBiz ? const Color(0xFF7B1FA2) : Theme.of(context).colorScheme.primary;
      bg = base.withValues(alpha: 0.12);
      fg = base;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// Home-header Carteira selector — a translucent pill (styled for the navy
/// dashboard header) that opens an animated dropdown listing every Carteira.
/// Replaces the old global switcher bar (removed).
class CarteiraHeaderSelector extends ConsumerStatefulWidget {
  const CarteiraHeaderSelector({super.key});

  @override
  ConsumerState<CarteiraHeaderSelector> createState() =>
      _CarteiraHeaderSelectorState();
}

class _CarteiraHeaderSelectorState
    extends ConsumerState<CarteiraHeaderSelector> {
  final _pillKey = GlobalKey();

  void _open() {
    final box = _pillKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    showCarteiraMenu(context, anchorRect: rect);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final active = ref.watch(activeWorkspaceProvider);
    final combined = ref.watch(isCombinedViewProvider);
    final type = active?.type ?? WorkspaceType.personal;
    final label = combined
        ? l10n.allWorkspaces
        : (active?.name ?? l10n.workspacePersonal);
    final icon = combined
        ? Icons.dashboard_customize_rounded
        : workspaceIcon(type);

    return Material(
      key: _pillKey,
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: _open,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 7, 10, 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 14, color: Colors.white),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 170),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (!combined) ...[
                const SizedBox(width: 7),
                CarteiraTypeBadge(type: type, onDark: true),
              ],
              const Icon(Icons.keyboard_arrow_down_rounded,
                  size: 20, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

/// Animated dropdown (anchored below [anchorRect]) listing all contexts: own
/// Carteiras, "Todas juntas", shared-in Carteiras, plus create/manage actions.
/// It grows out of the header pill — see [CarteiraHeaderSelector].
Future<void> showCarteiraMenu(BuildContext context,
    {required Rect anchorRect}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, __, ___) => const SizedBox.shrink(),
    transitionBuilder: (ctx, anim, sec, _) {
      final curved = CurvedAnimation(
        parent: anim,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      final mq = MediaQuery.of(ctx);
      final screenW = mq.size.width;
      final menuW = (screenW - 24).clamp(220.0, 360.0);
      final maxH = mq.size.height * 0.6;
      var left = anchorRect.center.dx - menuW / 2;
      final maxLeft = screenW - menuW - 12;
      left = left.clamp(12.0, maxLeft < 12.0 ? 12.0 : maxLeft);
      final top = anchorRect.bottom + 6;
      return Stack(
        children: [
          Positioned(
            left: left,
            top: top,
            width: menuW,
            child: FadeTransition(
              opacity: curved,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxH),
                  child: const _CarteiraMenuCard(),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _CarteiraMenuCard extends ConsumerWidget {
  const _CarteiraMenuCard();

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
    final canSwitch = ref.watch(canUseWorkspacesProvider);
    final defaultWsId = ref.watch(defaultWorkspaceIdProvider);

    final subLoading = ref.watch(isSubscriptionLoadingProvider);

    void select(String? id, {bool targetIsDefault = false}) {
      final isDefaultTarget =
          id == null || id == defaultWsId || targetIsDefault;
      // Free users are pinned to the default Carteira — steer any other pick
      // to the Pro upsell instead of silently snapping back. While the
      // subscription is still loading we can't tell (and the gate sheet
      // refuses to open), so honor the tap; the scope snaps back to the
      // default if the user turns out to be free.
      if (!canSwitch && !subLoading && !isDefaultTarget) {
        Navigator.of(context).pop();
        showProGateBottomSheet(
          context,
          featureName: l10n.workspaces,
          featureDescription: l10n.workspacesDesc,
          featureIcon: Icons.business_center_rounded,
        );
        return;
      }
      ref.read(activeWorkspaceIdProvider.notifier).select(id);
      Navigator.of(context).pop();
    }

    Widget tile({
      required Widget leading,
      required String title,
      Widget? badge,
      String? subtitle,
      required bool selected,
      required VoidCallback onTap,
    }) {
      return InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(children: [
                      Flexible(
                        child: Text(title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600)),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        badge,
                      ],
                    ]),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(subtitle,
                            style: TextStyle(
                                fontSize: 11.5, color: cs.onSurfaceVariant)),
                      ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle_rounded, color: cs.primary, size: 20),
            ],
          ),
        ),
      );
    }

    return Material(
      color: cs.surface,
      elevation: 10,
      shadowColor: Colors.black.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.workspaceSwitchTo,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: cs.onSurfaceVariant)),
                  const SizedBox(height: 2),
                  Text(l10n.carteiraScopeHint,
                      style: TextStyle(
                          fontSize: 11.5,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.8))),
                ],
              ),
            ),
            ...own.map((w) => tile(
                  leading: _MenuLeadingIcon(
                    icon: workspaceIcon(w.type),
                    color: w.isBusiness ? const Color(0xFF7B1FA2) : cs.primary,
                  ),
                  title: w.name,
                  badge: CarteiraTypeBadge(type: w.type),
                  selected: !combined && active?.id == w.id,
                  onTap: () => select(w.id, targetIsDefault: w.isDefault),
                )),
            if (own.length > 1)
              tile(
                leading: _MenuLeadingIcon(
                  icon: Icons.dashboard_customize_rounded,
                  color: cs.tertiary,
                ),
                title: l10n.allWorkspaces,
                subtitle: l10n.allWorkspacesHint,
                selected: combined,
                onTap: () => select(kAllWorkspaces),
              ),
            if (shared.isNotEmpty) ...[
              const Divider(height: 8),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
                child: Text(l10n.workspaceSharedWithMe,
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurfaceVariant)),
              ),
              ...shared.map((w) => tile(
                    leading:
                        _MenuLeadingIcon(icon: Icons.group_rounded, color: cs.tertiary),
                    title: w.name,
                    badge: CarteiraTypeBadge(type: w.type),
                    selected: active?.id == w.id,
                    onTap: () => select(w.id),
                  )),
            ],
            if (isMaster) ...[
              const Divider(height: 8),
              tile(
                leading:
                    _MenuLeadingIcon(icon: Icons.add_rounded, color: cs.primary),
                title: l10n.newWorkspace,
                selected: false,
                onTap: () async {
                  Navigator.of(context).pop();
                  await showCreateWorkspaceDialog(context, ref);
                },
              ),
              tile(
                leading: _MenuLeadingIcon(
                    icon: Icons.settings_outlined, color: cs.onSurfaceVariant),
                title: l10n.manageWorkspaces,
                selected: false,
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

class _MenuLeadingIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _MenuLeadingIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 17, color: color),
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
