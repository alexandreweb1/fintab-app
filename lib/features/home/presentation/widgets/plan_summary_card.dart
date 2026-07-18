import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/navigation_provider.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../onboarding/domain/onboarding_profile.dart';
import '../../../onboarding/presentation/providers/onboarding_provider.dart';

/// Card "Seu plano" no dashboard: recap do onboarding — arquétipo + o plano
/// modelo 50/30/20 (os 3 grupos) — com atalho para a aba de Orçamentos, onde
/// o acompanhamento por categoria (auto-criado no fim do onboarding) fica.
///
/// Só faz sentido quando existe um plano (pesquisa concluída). O dashboard
/// controla a exibição via [onboardingPlanAnswersProvider]; devolvemos um
/// SizedBox.shrink como defesa caso seja renderizado sem plano.
class PlanSummaryCard extends ConsumerWidget {
  const PlanSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final answers = ref.watch(onboardingPlanAnswersProvider);
    if (answers == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final plan = buildOnboardingPlan(answers);
    final fmt = ref.watch(currencyFormatterProvider);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Arquétipo do onboarding — âncora de identidade/motivação.
          Row(
            children: [
              Icon(Icons.assignment_outlined, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'SEU PERFIL: ${answers.archetype.displayName.toUpperCase()}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: cs.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 3 barras de grupo (50% necessidades · 20% desejos · 30% guardar).
          for (final group in plan.groups) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    group.name,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  group.amount != null
                      ? '${fmt(group.amount!)} · '
                          '${group.percentage.toStringAsFixed(0)}%'
                      : '${group.percentage.toStringAsFixed(0)}%',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (group.percentage / 100).clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: cs.primary.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation(cs.primary),
              ),
            ),
            const SizedBox(height: 12),
          ],

          const SizedBox(height: 2),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              // Aba Planejamento (Orçamentos) — onde ficam os orçamentos
              // auto-criados a partir deste plano.
              onPressed: () =>
                  ref.read(mainTabIndexProvider.notifier).state = 2,
              icon: const Icon(Icons.pie_chart_outline_rounded, size: 18),
              label: const Text('Ver acompanhamento por categoria'),
            ),
          ),
        ],
      ),
    );
  }
}
