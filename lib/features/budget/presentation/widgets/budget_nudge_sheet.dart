import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/navigation_provider.dart';
import '../../../../core/services/budget_nudge_service.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../subscription/presentation/screens/pro_screen.dart';
import '../providers/budget_nudge_signal_provider.dart';

const _kGreen = Color(0xFF00D887);

/// Index of the Planejamento tab in the main bottom navigation.
const int _kPlanningTabIndex = 2;

/// Post-save nudge shown from `MainScreen` when an expense lands outside the
/// budget. Content adapts to the [BudgetNudgePayload] variant:
///  - free user  → educational pitch + "Conhecer o Pro" (→ paywall)
///  - Pro + has budgets → "Criar orçamento" for that category
///  - Pro + no budgets  → "Começar a orçar" (opens the template chooser)
class BudgetNudgeSheet extends ConsumerWidget {
  final BudgetNudgePayload payload;

  const BudgetNudgeSheet({super.key, required this.payload});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final fmt = ref.watch(currencyFormatterProvider);

    final content = _contentFor(payload, fmt);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: cs.onSurface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: Color(0x1F00D887), // _kGreen @ 12%
              shape: BoxShape.circle,
            ),
            child: Icon(content.icon, size: 32, color: _kGreen),
          ),
          const SizedBox(height: 16),
          Text(
            content.title,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            content.body,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.7),
                ),
            textAlign: TextAlign.center,
          ),
          if (content.benefits.isNotEmpty) ...[
            const SizedBox(height: 16),
            ...content.benefits.map((b) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          size: 18, color: _kGreen),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(b,
                            style: Theme.of(context).textTheme.bodyMedium),
                      ),
                    ],
                  ),
                )),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _onPrimary(context, ref),
              style: FilledButton.styleFrom(
                backgroundColor: _kGreen,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: Icon(content.ctaIcon),
              label: Text(
                content.cta,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Agora não',
                  style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5)),
                ),
              ),
              Text('·',
                  style: TextStyle(color: cs.onSurface.withValues(alpha: 0.3))),
              TextButton(
                onPressed: () async {
                  await BudgetNudgeService.instance
                      .disable(isUpsell: payload.isUpsell);
                  if (context.mounted) Navigator.of(context).pop();
                },
                child: Text(
                  'Não mostrar de novo',
                  style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _onPrimary(BuildContext context, WidgetRef ref) {
    Navigator.of(context).pop();
    switch (payload.kind) {
      case BudgetNudgeKind.freeEducational:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ProScreen()),
        );
        break;
      case BudgetNudgeKind.createForCategory:
        ref.read(mainTabIndexProvider.notifier).state = _kPlanningTabIndex;
        ref.read(pendingBudgetDialogProvider.notifier).state =
            BudgetDialogRequest.create(
          categoryName: payload.categoryName,
          suggested: payload.suggested,
        );
        break;
      case BudgetNudgeKind.startBudgets:
        ref.read(mainTabIndexProvider.notifier).state = _kPlanningTabIndex;
        ref.read(pendingBudgetDialogProvider.notifier).state =
            const BudgetDialogRequest.templateChooser();
        break;
    }
  }

  _NudgeContent _contentFor(BudgetNudgePayload p, String Function(double) fmt) {
    switch (p.kind) {
      case BudgetNudgeKind.freeEducational:
        final foraLine = p.foraDoPlano > 0.005
            ? 'Você já gastou ${fmt(p.foraDoPlano)} este mês sem um plano. '
            : '';
        return _NudgeContent(
          icon: Icons.pie_chart_outline_rounded,
          title: 'Assuma o controle do mês',
          body: '${foraLine}Com Orçamentos você define quanto pode gastar por '
              'categoria e vê na hora quando algo foge do plano.',
          benefits: const [
            'Saiba quanto ainda pode gastar',
            'Enxergue estouros e gastos fora do plano',
            'Feche o mês sem sustos',
          ],
          cta: 'Conhecer o Pro',
          ctaIcon: Icons.workspace_premium_rounded,
        );
      case BudgetNudgeKind.createForCategory:
        final sug = p.suggested > 0.005
            ? ' Sugerimos começar com ${fmt(p.suggested)}.'
            : '';
        return _NudgeContent(
          icon: Icons.post_add_rounded,
          title: 'Fora do orçamento',
          body:
              '"${p.categoryName}" não está no seu plano deste mês. Quer criar '
              'um orçamento para acompanhar?$sug',
          benefits: const [],
          cta: 'Criar orçamento',
          ctaIcon: Icons.add_chart_rounded,
        );
      case BudgetNudgeKind.startBudgets:
        return const _NudgeContent(
          icon: Icons.pie_chart_outline_rounded,
          title: 'Comece a orçar',
          body: 'Você ainda não tem orçamentos este mês. Crie a partir de um '
              'modelo e acompanhe seus gastos por categoria.',
          benefits: [],
          cta: 'Criar meu plano',
          ctaIcon: Icons.auto_awesome_rounded,
        );
    }
  }
}

class _NudgeContent {
  final IconData icon;
  final String title;
  final String body;
  final List<String> benefits;
  final String cta;
  final IconData ctaIcon;

  const _NudgeContent({
    required this.icon,
    required this.title,
    required this.body,
    required this.benefits,
    required this.cta,
    required this.ctaIcon,
  });
}
