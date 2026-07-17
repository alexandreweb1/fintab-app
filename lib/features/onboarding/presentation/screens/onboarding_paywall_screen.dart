import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/platform_store.dart';
import '../../../settings/presentation/screens/privacy_policy_screen.dart';
import '../../../settings/presentation/screens/terms_of_use_screen.dart';
import '../../../subscription/presentation/providers/subscription_provider.dart';
import '../../../subscription/presentation/screens/pro_screen.dart';
import '../providers/onboarding_provider.dart';

const _kGreen = Color(0xFF00D887);
const _kGreenDark = Color(0xFF00A86B);

/// Paywall do fim do onboarding — última PÁGINA do OnboardingFlowScreen
/// (rota única: o back do sistema passa pelo PopScope do fluxo e nunca
/// escapa sem gravar o desfecho). Copy personalizada pelo objetivo declarado,
/// mesma lógica de compra da ProScreen (iapNotifierProvider). O X e o botão
/// "Continuar com o plano grátis" ficam sempre visíveis — sair é fácil.
class OnboardingPaywallPage extends ConsumerStatefulWidget {
  /// True quando o usuário confirmou o compromisso na tela anterior.
  final bool committed;

  /// Saída única da página; o fluxo grava completedAt e fecha a rota.
  final void Function({required bool dismissed}) onFinished;

  const OnboardingPaywallPage({
    super.key,
    required this.committed,
    required this.onFinished,
  });

  @override
  ConsumerState<OnboardingPaywallPage> createState() =>
      _OnboardingPaywallPageState();
}

class _OnboardingPaywallPageState extends ConsumerState<OnboardingPaywallPage> {
  @override
  void initState() {
    super.initState();
    logOnboardingEvent('onboarding_paywall_viewed', {
      'platform': kIsWeb ? 'web' : 'mobile',
    });
    // O fluxo pode abrir antes de a MainScreen inicializar o IAP —
    // garante produtos carregados (initialize é guardado por isLoading).
    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final iap = ref.read(iapNotifierProvider);
        if (iap.products.isEmpty && !iap.isLoading) {
          ref.read(iapNotifierProvider.notifier).initialize();
        }
      });
    }
  }

  void _buy(String plan) {
    logOnboardingEvent('onboarding_paywall_purchase_tapped', {'plan': plan});
    final notifier = ref.read(iapNotifierProvider.notifier);
    if (plan == 'annual') {
      notifier.buyAnnual();
    } else {
      notifier.buyMonthly();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final answers = ref.watch(onboardingFlowProvider);
    final iapState = ref.watch(iapNotifierProvider);
    final benefits = buildPaywallBenefits(answers);
    final headline = paywallHeadline(answers, committed: widget.committed);

    // Compra confirmada (Firestore é a fonte de verdade) → encerra o fluxo.
    // A compra pode ter acontecido numa rota empilhada por cima (ProScreen
    // via "Ver tudo", Termos abertos com a sheet da loja processando):
    // fecha as filhas antes de sair, senão o pop removeria a rota errada.
    ref.listen<bool>(isProProvider, (prev, next) {
      if (!next) return;
      final route = ModalRoute.of(context);
      if (route != null && !route.isCurrent) {
        Navigator.of(context).popUntil((r) => r == route);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Bem-vindo(a) ao Fintab Pro! Bom trabalho.')),
      );
      widget.onFinished(dismissed: false);
    });

    return Scaffold(
      backgroundColor: cs.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 200,
            backgroundColor: _kGreenDark,
            foregroundColor: Colors.white,
            automaticallyImplyLeading: false,
            // X visível desde o primeiro frame — sem delay, sem fade.
            leading: IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Fechar',
              onPressed: () => widget.onFinished(dismissed: true),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_kGreen, _kGreenDark],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 40, 20, 12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.workspace_premium_rounded,
                              size: 30, color: Colors.white),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          headline,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Seu plano modelo já está no seu painel — e o grátis '
                        'continua completo para lançar e acompanhar. O Pro '
                        'transforma o plano em orçamentos reais, com '
                        'acompanhamento automático por categoria.',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: cs.onSurfaceVariant, height: 1.4),
                      ),
                      const SizedBox(height: 16),

                      // ── 4 benefícios rankeados pelo perfil ──────────────
                      Card(
                        margin: EdgeInsets.zero,
                        elevation: 0,
                        color: cs.surfaceContainerLow,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              for (final b in benefits)
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 6),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: _kGreen.withValues(
                                              alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Icon(b.icon,
                                            size: 20, color: _kGreenDark),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          b.title,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                  fontWeight:
                                                      FontWeight.w600),
                                        ),
                                      ),
                                      const Icon(Icons.check_circle_rounded,
                                          size: 18, color: _kGreen),
                                    ],
                                  ),
                                ),
                              TextButton(
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) => const ProScreen()),
                                ),
                                child:
                                    const Text('Ver tudo que vem no Pro'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      if (kIsWeb)
                        const _WebCard()
                      else ...[
                        Text(
                          'Seu plano de gastos já está pronto. Com o Pro, ele '
                          'é aplicado como orçamentos em 1 toque.',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        ..._priceSection(iapState),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),

      // Saída fácil, sempre visível sem scroll.
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () => widget.onFinished(dismissed: true),
                child: const Text('Continuar com o plano grátis'),
              ),
              Text(
                'O Fintab grátis continua completo para registrar e entender '
                'seus gastos. O Pro aprofunda e automatiza.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Cards de preço (mesma lógica da ProScreen; preços da loja) ────────────

  List<Widget> _priceSection(IAPState iapState) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    String priceFor(String id, String fallback) {
      final matches = iapState.products.where((p) => p.id == id);
      return matches.isEmpty ? fallback : matches.first.price;
    }

    final annualPrice = priceFor(kIapAnnual, 'R\$ 49,90');
    final monthlyPrice = priceFor(kIapMonthly, 'R\$ 4,90');

    return [
      _PriceCard(
        planName: 'Anual',
        price: annualPrice,
        period: '/ano',
        detail: '${_annualDetail(iapState)}\n'
            'Cobrado de imediato. Renovação automática; '
            'cancele quando quiser.',
        savings: 'MELHOR VALOR',
        isHighlighted: true,
        isLoading: iapState.isLoading,
        ctaLabel: 'Assinar',
        onTap: () => _buy('annual'),
      ),
      const SizedBox(height: 10),
      _PriceCard(
        planName: 'Mensal',
        price: monthlyPrice,
        period: '/mês',
        detail: 'Grátis por 7 dias, depois $monthlyPrice/mês.\n'
            'Cancele antes do fim do teste e não pague nada.',
        savings: '7 DIAS GRÁTIS',
        isHighlighted: false,
        isLoading: iapState.isLoading,
        ctaLabel: 'Testar grátis',
        onTap: () => _buy('monthly'),
      ),
      const SizedBox(height: 12),
      Text(
        'O teste grátis de 7 dias vale só para o plano mensal. As '
        'assinaturas renovam automaticamente; cancele a qualquer momento '
        'na $storeNameFull.',
        textAlign: TextAlign.center,
        style: TextStyle(
            fontSize: 11, color: cs.onSurface.withValues(alpha: 0.45)),
      ),
      if (iapState.errorMessage != null) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  iapState.errorMessage!,
                  style:
                      TextStyle(color: Colors.red.shade700, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 8),
      Center(
        child: TextButton.icon(
          onPressed: iapState.isLoading
              ? null
              : () =>
                  ref.read(iapNotifierProvider.notifier).restorePurchases(),
          icon: const Icon(Icons.restore, size: 16),
          label: const Text('Restaurar compras anteriores'),
        ),
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _LegalLink(
            label: 'Termos de Uso',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TermsOfUseScreen()),
            ),
          ),
          Text('·',
              style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurface.withValues(alpha: 0.45))),
          _LegalLink(
            label: 'Política de Privacidade',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
            ),
          ),
        ],
      ),
    ];
  }

  /// "Equivale a X/mês · economize N% vs. mensal" — N calculado em runtime a
  /// partir dos preços reais da loja; omitido quando não calculável (3.1.2).
  String _annualDetail(IAPState iapState) {
    final annual =
        iapState.products.where((p) => p.id == kIapAnnual).firstOrNull;
    final monthly =
        iapState.products.where((p) => p.id == kIapMonthly).firstOrNull;

    if (annual == null) return 'Um ano inteiro de Pro pelo menor preço.';

    // Locale do idioma do app para separador decimal correto (R$ 4,16).
    final perMonth = NumberFormat.currency(
      locale: ref.read(dateLocaleProvider),
      symbol: annual.currencySymbol,
      decimalDigits: 2,
    ).format(annual.rawPrice / 12);
    var detail = 'Equivale a $perMonth/mês';

    if (monthly != null &&
        monthly.currencyCode == annual.currencyCode &&
        monthly.rawPrice > 0) {
      final yearly = monthly.rawPrice * 12;
      if (annual.rawPrice < yearly) {
        final pct = ((yearly - annual.rawPrice) / yearly * 100).round();
        detail = '$detail · economize $pct% vs. mensal';
      }
    }
    return detail;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card de preço (padrão da ProScreen, com rótulo de CTA configurável)
// ─────────────────────────────────────────────────────────────────────────────

class _PriceCard extends StatelessWidget {
  final String planName;
  final String price;
  final String period;
  final String detail;
  final String? savings;
  final bool isHighlighted;
  final bool isLoading;
  final String ctaLabel;
  final VoidCallback onTap;

  const _PriceCard({
    required this.planName,
    required this.price,
    required this.period,
    required this.detail,
    this.savings,
    required this.isHighlighted,
    required this.isLoading,
    required this.ctaLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Card(
          margin: EdgeInsets.zero,
          elevation: isHighlighted ? 3 : 0,
          color: isHighlighted
              ? _kGreen.withValues(alpha: 0.07)
              : cs.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: isHighlighted
                ? const BorderSide(color: _kGreen, width: 1.5)
                : BorderSide.none,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        planName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color:
                              isHighlighted ? _kGreenDark : cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: price,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: isHighlighted
                                    ? _kGreenDark
                                    : cs.onSurface,
                              ),
                            ),
                            TextSpan(
                              text: period,
                              style: TextStyle(
                                fontSize: 14,
                                color:
                                    cs.onSurface.withValues(alpha: 0.55),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        detail,
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.35,
                          color: cs.onSurface.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: isLoading ? null : onTap,
                  style: FilledButton.styleFrom(
                    backgroundColor: _kGreen,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black),
                        )
                      : Text(ctaLabel,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
        if (savings != null)
          Positioned(
            top: -10,
            right: 16,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _kGreen,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                savings!,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Web — sem IAP: instrução de assinar pelo celular, sem preços (3.1.1)
// ─────────────────────────────────────────────────────────────────────────────

class _WebCard extends StatelessWidget {
  const _WebCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _kGreen.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kGreen.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _kGreen.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.smartphone_rounded,
                size: 28, color: _kGreen),
          ),
          const SizedBox(height: 16),
          Text(
            'Assinatura pelo celular',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'As assinaturas do Fintab Pro são feitas pelo app no iPhone ou '
            'Android. Instale, entre com esta conta e seu plano estará te '
            'esperando.',
            style: TextStyle(
              fontSize: 13,
              color: cs.onSurface.withValues(alpha: 0.6),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _LegalLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _LegalLink({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: _kGreenDark,
            decoration: TextDecoration.underline,
            decorationColor: _kGreenDark,
          ),
        ),
      ),
    );
  }
}
