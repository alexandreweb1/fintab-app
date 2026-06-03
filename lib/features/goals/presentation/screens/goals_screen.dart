import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/animated_dialog.dart';
import '../../../../features/subscription/presentation/providers/subscription_provider.dart';
import '../../../../features/subscription/presentation/widgets/pro_gate_widget.dart';
import '../providers/goals_provider.dart';
import '../widgets/add_goal_dialog.dart';
import '../widgets/goal_card.dart';

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(goalsStreamProvider);

    return goalsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erro: $e')),
      data: (goals) {
        if (goals.isEmpty) {
          return _EmptyGoals(
            onAdd: () => _openAddDialog(context, ref),
          );
        }

        return Stack(
          children: [
            ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 96),
              itemCount: goals.length,
              itemBuilder: (ctx, i) {
                final goal = goals[i];
                return GoalCard(
                  goal: goal,
                  onEdit: () => showAnimatedDialog(
                    context: context,
                    builder: (_) => AddGoalDialog(goal: goal),
                  ),
                  onDelete: () => _confirmDelete(context, ref, goal.id),
                );
              },
            ),
            Positioned(
              bottom: 16,
              right: 16,
              child: FloatingActionButton.extended(
                heroTag: 'add_goal',
                onPressed: () => _openAddDialog(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Nova meta'),
                backgroundColor: const Color(0xFF00D887),
                foregroundColor: Colors.black,
              ),
            ),
          ],
        );
      },
    );
  }

  void _openAddDialog(BuildContext context, WidgetRef ref) {
    if (!ref.read(isProProvider)) {
      showProGateBottomSheet(
        context,
        featureName: 'Metas financeiras',
        featureDescription: 'Crie e acompanhe metas financeiras personalizadas.',
        featureIcon: Icons.savings_rounded,
      );
      return;
    }
    showAnimatedDialog(
      context: context,
      builder: (_) => const AddGoalDialog(),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, String goalId) async {
    final confirmed = await showAnimatedDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir meta'),
        content: const Text(
            'Tem certeza que deseja excluir esta meta? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    ref.read(goalsNotifierProvider.notifier).delete(goalId);
  }
}

class _EmptyGoals extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyGoals({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.savings_rounded,
            size: 72,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'Nenhuma meta criada',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Defina objetivos financeiros e\nacompanhe seu progresso.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Criar meta'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF00D887),
              foregroundColor: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
