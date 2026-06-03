import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/bank_filter_provider.dart';
import '../../../notification_backlog/presentation/providers/backlog_provider.dart';

class BankFilterScreen extends ConsumerStatefulWidget {
  const BankFilterScreen({super.key});

  @override
  ConsumerState<BankFilterScreen> createState() => _BankFilterScreenState();
}

class _BankFilterScreenState extends ConsumerState<BankFilterScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final allowed = ref.watch(allowedAppPackagesProvider);
    final cs = Theme.of(context).colorScheme;

    // Collect unique sourceApps from backlog (detected apps)
    final backlogItems =
        ref.watch(backlogItemsStreamProvider).valueOrNull ?? [];
    final detectedPackages = <String>{};
    for (final item in backlogItems) {
      if (item.sourceApp.isNotEmpty) detectedPackages.add(item.sourceApp);
    }

    // Merge known banks + detected + any custom allowed apps not in either
    final allPackages = <String>{
      ...knownBankApps.keys,
      ...detectedPackages,
      ...allowed,
    };

    // Apply search filter
    final filteredPackages = _search.isEmpty
        ? allPackages
        : allPackages.where((pkg) {
            final name = bankDisplayName(pkg).toLowerCase();
            final query = _search.toLowerCase();
            return name.contains(query) || pkg.toLowerCase().contains(query);
          }).toSet();

    final knownList =
        filteredPackages.where((p) => knownBankApps.containsKey(p)).toList()
          ..sort((a, b) => knownBankApps[a]!.compareTo(knownBankApps[b]!));
    final otherList =
        filteredPackages.where((p) => !knownBankApps.containsKey(p)).toList()
          ..sort((a, b) => bankDisplayName(a).compareTo(bankDisplayName(b)));

    final allForActions = <String>{
      ...knownBankApps.keys,
      ...detectedPackages,
      ...allowed,
    };
    final allEnabled = allForActions.every((p) => allowed.contains(p));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Apps Monitorados'),
        actions: [
          TextButton(
            onPressed: allEnabled
                ? () => ref
                    .read(allowedAppPackagesProvider.notifier)
                    .disableAll()
                : () => ref
                    .read(allowedAppPackagesProvider.notifier)
                    .enableAll(allForActions),
            child: Text(allEnabled ? 'Desativar tudo' : 'Ativar tudo'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddAppDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Adicionar app'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 80),
        children: [
          // Explanation
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Ative os aplicativos que deseja monitorar. '
              'Apenas notificações dos apps ativos serão detectadas.',
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar app...',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                filled: true,
                fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),

          // Active count chip
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                _CountChip(
                  label: '${allowed.length} ativo${allowed.length != 1 ? 's' : ''}',
                  color: cs.primary,
                ),
                const SizedBox(width: 8),
                _CountChip(
                  label: '${allPackages.length - allowed.length} inativo${(allPackages.length - allowed.length) != 1 ? 's' : ''}',
                  color: cs.onSurfaceVariant,
                ),
              ],
            ),
          ),

          // Known banks section
          if (knownList.isNotEmpty) ...[
            _SectionHeader(title: 'Bancos conhecidos', color: cs),
            ...knownList.map((pkg) => _AppTile(
                  packageName: pkg,
                  displayName: knownBankApps[pkg]!,
                  isEnabled: allowed.contains(pkg),
                  isDetected: detectedPackages.contains(pkg),
                  onToggle: () =>
                      ref.read(allowedAppPackagesProvider.notifier).toggle(pkg),
                )),
          ],

          // Other detected / custom apps
          if (otherList.isNotEmpty) ...[
            const SizedBox(height: 8),
            _SectionHeader(title: 'Outros apps', color: cs),
            ...otherList.map((pkg) => _AppTile(
                  packageName: pkg,
                  displayName: bankDisplayName(pkg),
                  isEnabled: allowed.contains(pkg),
                  isDetected: detectedPackages.contains(pkg),
                  isCustom: !knownBankApps.containsKey(pkg) &&
                      !detectedPackages.contains(pkg),
                  onToggle: () =>
                      ref.read(allowedAppPackagesProvider.notifier).toggle(pkg),
                )),
          ],

          // Empty search state
          if (knownList.isEmpty && otherList.isEmpty && _search.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'Nenhum app encontrado para "$_search"',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showAddAppDialog(BuildContext context) {
    final controller = TextEditingController();
    final cs = Theme.of(context).colorScheme;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Adicionar app'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Digite o nome do pacote do aplicativo '
              '(ex: com.exemplo.app)',
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'com.exemplo.app',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final pkg = controller.text.trim();
              if (pkg.isNotEmpty && pkg.contains('.')) {
                ref
                    .read(allowedAppPackagesProvider.notifier)
                    .addCustomApp(pkg);
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${bankDisplayName(pkg)} adicionado'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  final String label;
  final Color color;
  const _CountChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final ColorScheme color;
  const _SectionHeader({required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color.onSurfaceVariant,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _AppTile extends StatelessWidget {
  final String packageName;
  final String displayName;
  final bool isEnabled;
  final bool isDetected;
  final bool isCustom;
  final VoidCallback onToggle;

  const _AppTile({
    required this.packageName,
    required this.displayName,
    required this.isEnabled,
    required this.isDetected,
    required this.onToggle,
    this.isCustom = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SwitchListTile(
      value: isEnabled,
      onChanged: (_) => onToggle(),
      title: Text(displayName),
      subtitle: Row(
        children: [
          Flexible(
            child: Text(
              packageName,
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isDetected) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'detectado',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade700,
                ),
              ),
            ),
          ],
          if (isCustom) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'manual',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade700,
                ),
              ),
            ),
          ],
        ],
      ),
      secondary: CircleAvatar(
        radius: 18,
        backgroundColor:
            isEnabled ? cs.primaryContainer : cs.surfaceContainerHighest,
        child: Text(
          displayName.isNotEmpty ? displayName[0] : '?',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isEnabled ? cs.onPrimaryContainer : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
