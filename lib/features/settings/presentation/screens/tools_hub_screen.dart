import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../bills/presentation/screens/bills_screen.dart';
import '../../../category_rules/presentation/screens/category_rules_screen.dart';
import '../../../investments/presentation/screens/investments_screen.dart';
import '../../../subscriptions/presentation/screens/subscriptions_screen.dart';
import '../../../subscription/presentation/providers/subscription_provider.dart';
import '../../../subscription/presentation/widgets/pro_badge_widget.dart';
import '../../../subscription/presentation/widgets/pro_gate_widget.dart';
import 'currency_converter_screen.dart';

/// A subscreen that groups the app's feature "tools", keeping Settings clean.
class ToolsHubScreen extends ConsumerWidget {
  const ToolsHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isPro = ref.watch(isProProvider);

    void open(Widget screen) => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => screen),
        );

    void openPro(Widget screen, String name, String desc, IconData icon) {
      if (!ref.read(isProProvider)) {
        showProGateBottomSheet(context,
            featureName: name, featureDescription: desc, featureIcon: icon);
        return;
      }
      open(screen);
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.toolsHub)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _label(context, l10n.toolsMarket),
          _Tile(
            icon: Icons.candlestick_chart_outlined,
            color: const Color(0xFF6C5CE7),
            title: l10n.investments,
            subtitle: l10n.investmentsDesc,
            pro: !isPro,
            onTap: () => openPro(const InvestmentsScreen(), l10n.investments,
                l10n.investmentsDesc, Icons.candlestick_chart_outlined),
          ),
          _Tile(
            icon: Icons.currency_exchange_rounded,
            color: const Color(0xFF0EA5A5),
            title: l10n.currencyConverter,
            subtitle: l10n.currencyConverterDesc,
            pro: !isPro,
            onTap: () => openPro(
                const CurrencyConverterScreen(),
                l10n.currencyConverter,
                l10n.currencyConverterDesc,
                Icons.currency_exchange_rounded),
          ),
          const SizedBox(height: 8),
          _label(context, l10n.toolsOrganize),
          _Tile(
            icon: Icons.event_note_outlined,
            color: const Color(0xFF00B894),
            title: l10n.bills,
            subtitle: l10n.billsDesc,
            onTap: () => open(const BillsScreen()),
          ),
          _Tile(
            icon: Icons.autorenew_rounded,
            color: const Color(0xFFE17055),
            title: l10n.subscriptions,
            subtitle: l10n.subscriptionsDesc,
            onTap: () => open(const SubscriptionsScreen()),
          ),
          _Tile(
            icon: Icons.rule_folder_outlined,
            color: const Color(0xFF00B894),
            title: 'Regras de categorização',
            subtitle: 'Categorize automaticamente por palavra-chave',
            onTap: () => open(const CategoryRulesScreen()),
          ),
        ],
      ),
    );
  }

  Widget _label(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
        child: Text(text.toUpperCase(),
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool pro;
  final VoidCallback onTap;
  const _Tile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.pro = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Row(children: [
          Flexible(child: Text(title)),
          if (pro) ...[const SizedBox(width: 6), const ProBadgeWidget()],
        ]),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, size: 20),
      ),
    );
  }
}
