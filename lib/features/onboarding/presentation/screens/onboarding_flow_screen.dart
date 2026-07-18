import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/app_settings_provider.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../auth/presentation/screens/register_screen.dart';
import '../../domain/onboarding_profile.dart';
import '../providers/onboarding_provider.dart';
import 'onboarding_paywall_screen.dart';

const _kAmber = Color(0xFFFFA726);

/// Em que momento do ciclo de conta o fluxo está rodando.
enum OnboardingFlowMode {
  /// ANTES do cadastro: 8 perguntas → plano → ponte "salve seu plano"
  /// (criar conta / entrar). Respostas ficam no aparelho (stash).
  preAuth,

  /// Pós-login com a pesquisa já respondida (pré-cadastro ou sessão
  /// anterior): só compromisso → paywall.
  postAuthContinue,

  /// Pós-login sem pesquisa feita (ex.: conta criada direto pela tela de
  /// login): fluxo completo, como fallback.
  postAuthFull,
}

/// Fluxo de onboarding de primeiro uso: 8 perguntas tap-to-answer,
/// reveal do plano modelo, compromisso (checkbox + confirmação) e paywall.
/// A pesquisa roda ANTES do cadastro; a conta é criada na ponte "salve seu
/// plano" e o compromisso+paywall continuam depois do login.
///
/// Substitui o antigo `LiteracyOnboardingDialog` (a pergunta de nível de
/// familiaridade é a 4ª do fluxo e grava o mesmo `AppSettings.literacyLevel`).
class OnboardingFlowScreen extends ConsumerStatefulWidget {
  final OnboardingFlowMode mode;

  /// True quando o fluxo foi começado numa sessão anterior e abandonado.
  final bool resuming;

  /// Pré-cadastro com a pesquisa já concluída: abre direto na ponte.
  final bool startAtBridge;

  /// Respostas de uma sessão anterior (stash pré-cadastro ou o mapa
  /// `onboardingProfile` do Firestore) para pré-selecionar.
  final Map<String, dynamic>? initialData;

  /// Pós-cadastro vindo do stash: grava as respostas no Firestore ao abrir.
  final bool persistOnStart;

  const OnboardingFlowScreen({
    super.key,
    required this.mode,
    this.resuming = false,
    this.startAtBridge = false,
    this.initialData,
    this.persistOnStart = false,
  });

  @override
  ConsumerState<OnboardingFlowScreen> createState() =>
      _OnboardingFlowScreenState();
}

class _OnboardingFlowScreenState extends ConsumerState<OnboardingFlowScreen> {
  static const _questionCount = 8;
  static const _questionSteps = [
    'q_goal',
    'q_current_method',
    'q_control_style',
    'q_literacy',
    'q_month_end',
    'q_leak',
    'q_household',
    'q_income',
  ];

  late final PageController _controller;
  late final List<String> _steps;
  int _index = 0;
  bool _paywallCommitted = false;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    _steps = switch (widget.mode) {
      OnboardingFlowMode.preAuth => [
          ..._questionSteps,
          'plan_result',
          'auth_bridge',
        ],
      OnboardingFlowMode.postAuthFull => [
          ..._questionSteps,
          'plan_result',
          'commitment',
          'paywall',
        ],
      OnboardingFlowMode.postAuthContinue => ['commitment', 'paywall'],
    };

    final notifier = ref.read(onboardingFlowProvider.notifier);
    if (widget.initialData != null) notifier.hydrate(widget.initialData!);
    if (widget.persistOnStart) notifier.persistPreAuthAnswers();
    if (widget.mode != OnboardingFlowMode.postAuthContinue) {
      notifier.markStarted(alreadyStartedBefore: widget.resuming);
    }

    _index = widget.startAtBridge
        ? _steps.indexOf('auth_bridge').clamp(0, _steps.length - 1)
        : 0;
    _controller = PageController(initialPage: _index);
    WidgetsBinding.instance.addPostFrameCallback((_) => _logViewed(_index));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _logViewed(int index) {
    final stepId = _steps[index];
    // A página do paywall loga o próprio onboarding_paywall_viewed.
    if (stepId == 'paywall') return;
    final notifier = ref.read(onboardingFlowProvider.notifier);
    notifier.logStepViewed(stepId, index);
    if (stepId == 'plan_result') {
      notifier.markStepReached(stepId, index);
      logOnboardingEvent('onboarding_plan_viewed');
      // NÃO marcar preAuthOnboardingDone aqui: alterar o AppSettings no meio
      // do fluxo faz o _PreAuthGate reconstruir e — com o stash ainda "frio"
      // (null em cache nesta sessão) — trocar o reveal do plano por uma
      // LoginScreen, engolindo a ponte "Salve seu plano". O marcador é gravado
      // após o login (ver _OnboardingGate); relançamentos pré-login caem na
      // ponte pelo stash surveyDone:true, relido a cada nova sessão do app.
    } else if (stepId == 'commitment') {
      notifier.markStepReached(stepId, index);
      logOnboardingEvent('commitment_viewed');
    }
  }

  int _stepIndex(String id) => _steps.indexOf(id);

  void _goToStep(String id) => _goTo(_stepIndex(id));

  void _goTo(int index) {
    if (!mounted || index == _index) return;
    setState(() => _index = index);
    _controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
    _logViewed(index);
  }

  void _goBack() {
    if (_index > 0 && _index < _questionCount) _goTo(_index - 1);
  }

  /// Back do sistema (Android/gesto iOS): volta uma etapa nas perguntas e
  /// nas telas de plano/ponte/compromisso; no paywall, equivale a "Continuar
  /// com o plano grátis" — nunca sai do fluxo sem gravar o desfecho.
  void _handleSystemBack() {
    switch (_steps[_index]) {
      case 'paywall':
        _finishFromPaywall(dismissed: true);
      case 'commitment':
        // No modo continuação não há tela atrás — as saídas visíveis
        // ("Agora não" → paywall) resolvem.
        if (widget.mode == OnboardingFlowMode.postAuthFull) {
          _goToStep('plan_result');
        }
      case 'auth_bridge':
        _goToStep('plan_result');
      case 'plan_result':
        _goTo(_questionCount - 1);
      default:
        _goBack();
    }
  }

  /// "Agora não, quero explorar antes" (T1) — adiamento total.
  /// Nenhuma saída do fluxo aguarda rede: o Firestore sincroniza depois.
  void _defer() {
    if (_finishing) return;
    _finishing = true;
    ref.read(onboardingFlowProvider.notifier).defer();
    Navigator.of(context).pop();
  }

  /// "Ver meu plano no app" — pula compromisso e paywall, sem beco sem saída.
  void _finishWithoutPaywall() {
    if (_finishing) return;
    _finishing = true;
    ref.read(onboardingFlowProvider.notifier).complete();
    Navigator.of(context).pop();
  }

  void _showPaywall({required bool committed}) {
    setState(() => _paywallCommitted = committed);
    _goToStep('paywall');
  }

  /// Saída única do paywall (X, "continuar grátis", back do sistema e
  /// sucesso de compra) — sempre grava completedAt antes de sair.
  void _finishFromPaywall({required bool dismissed}) {
    if (_finishing) return;
    _finishing = true;
    if (dismissed) logOnboardingEvent('onboarding_paywall_dismissed');
    ref.read(onboardingFlowProvider.notifier).complete();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(onboardingFlowProvider.notifier);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleSystemBack();
      },
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: PageView(
                controller: _controller,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  if (widget.mode != OnboardingFlowMode.postAuthContinue) ...[
                  // ── T1 · q_goal ────────────────────────────────────────
                  _QuestionPage<OnboardingGoal>(
                    header: _header(0),
                    microHeader:
                        '8 toques rápidos para montar seu plano financeiro pessoal.',
                    title: 'Qual é o seu maior objetivo agora?',
                    subtitle: 'Vamos montar o Fintab em volta dele.',
                    options: const [
                      _Option(
                        value: OnboardingGoal.debts,
                        icon: Icons.restart_alt,
                        title: 'Sair do vermelho',
                        description: 'Quitar dívidas e voltar a respirar',
                      ),
                      _Option(
                        value: OnboardingGoal.clarity,
                        icon: Icons.pie_chart_outline,
                        title: 'Entender para onde vai meu dinheiro',
                        description: 'Clareza, sem surpresas no fim do mês',
                      ),
                      _Option(
                        value: OnboardingGoal.save,
                        icon: Icons.savings,
                        title: 'Juntar para um objetivo',
                        description: 'Viagem, casa, reserva, o que for seu',
                      ),
                      _Option(
                        value: OnboardingGoal.grow,
                        icon: Icons.trending_up,
                        title: 'Fazer meu dinheiro render mais',
                        description: 'Sobrar mais e investir melhor',
                      ),
                    ],
                    selected: ref.watch(
                        onboardingFlowProvider.select((s) => s.goal)),
                    onAnswer: (v) {
                      notifier.answerGoal(v, 0);
                      _goTo(1);
                    },
                    onSkip: () {
                      notifier.answerGoal(null, 0, skipped: true);
                      _goTo(1);
                    },
                    extraFooter: widget.mode == OnboardingFlowMode.preAuth
                        ? TextButton(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const LoginScreen()),
                            ),
                            child: const Text('Já tenho conta? Entrar'),
                          )
                        : TextButton(
                            onPressed: _defer,
                            child: const Text(
                                'Agora não, quero explorar antes'),
                          ),
                  ),

                  // ── T2 · q_current_method ──────────────────────────────
                  _QuestionPage<OnboardingMethod>(
                    header: _header(1),
                    title: 'Como você controla seus gastos hoje?',
                    subtitle:
                        'Sem julgamento — é só para começar do lugar certo.',
                    options: const [
                      _Option(
                        value: OnboardingMethod.none,
                        icon: Icons.psychology_alt,
                        title: 'Na cabeça (ou não controlo)',
                        description: 'A maioria começa assim',
                      ),
                      _Option(
                        value: OnboardingMethod.paper,
                        icon: Icons.edit_note,
                        title: 'Caderno ou anotações',
                        description: 'No papel ou no bloco de notas',
                      ),
                      _Option(
                        value: OnboardingMethod.sheet,
                        icon: Icons.table_chart,
                        title: 'Planilha',
                        description: 'Excel, Google Sheets',
                      ),
                      _Option(
                        value: OnboardingMethod.app,
                        icon: Icons.smartphone,
                        title: 'Outro aplicativo',
                        description: 'Já testei apps de finanças',
                      ),
                      _Option(
                        value: OnboardingMethod.bank,
                        icon: Icons.account_balance,
                        title: 'Só pelo app do banco',
                        description: 'Olho o saldo e o extrato',
                      ),
                    ],
                    selected: ref.watch(
                        onboardingFlowProvider.select((s) => s.currentMethod)),
                    onAnswer: (v) {
                      notifier.answerMethod(v, 1);
                      _goTo(2);
                    },
                    onSkip: () {
                      notifier.answerMethod(null, 1, skipped: true);
                      _goTo(2);
                    },
                  ),

                  // ── T3 · q_control_style ───────────────────────────────
                  _QuestionPage<OnboardingControlStyle>(
                    header: _header(2),
                    title: 'Que estilo de controle combina com você?',
                    subtitle: 'O Fintab se adapta ao seu jeito.',
                    options: const [
                      _Option(
                        value: OnboardingControlStyle.budget,
                        icon: Icons.donut_small,
                        title: 'Orçamento por categoria',
                        description: 'Limites claros para cada gasto',
                      ),
                      _Option(
                        value: OnboardingControlStyle.track,
                        icon: Icons.checklist,
                        title: 'Só lançar e acompanhar',
                        description: 'Registrar tudo, sem limites rígidos',
                      ),
                      _Option(
                        value: OnboardingControlStyle.goals,
                        icon: Icons.flag,
                        title: 'Metas',
                        description: 'Juntar dinheiro para conquistar algo',
                      ),
                      _Option(
                        value: OnboardingControlStyle.reminders,
                        icon: Icons.notifications_active,
                        title: 'Lembretes',
                        description: 'Nunca mais atrasar uma conta',
                      ),
                    ],
                    selected: ref.watch(
                        onboardingFlowProvider.select((s) => s.controlStyle)),
                    onAnswer: (v) {
                      notifier.answerControlStyle(v, 2);
                      _goTo(3);
                    },
                    onSkip: () {
                      notifier.answerControlStyle(null, 2, skipped: true);
                      _goTo(3);
                    },
                  ),

                  // ── T4 · q_literacy (absorve o dialog antigo) ──────────
                  _QuestionPage<FinancialLiteracyLevel>(
                    header: _header(3),
                    title: 'Como você se sente em relação a finanças?',
                    subtitle: 'Ajustamos as dicas do app ao seu nível.',
                    options: const [
                      _Option(
                        value: FinancialLiteracyLevel.beginner,
                        icon: Icons.emoji_objects_outlined,
                        title: 'Estou começando agora',
                        description: 'Quero aprender o básico no caminho',
                      ),
                      _Option(
                        value: FinancialLiteracyLevel.intermediate,
                        icon: Icons.trending_up_rounded,
                        title: 'Já me viro bem',
                        description: 'Conheço o essencial, quero constância',
                      ),
                      _Option(
                        value: FinancialLiteracyLevel.advanced,
                        icon: Icons.workspace_premium_outlined,
                        title: 'Domino o assunto',
                        description: 'Só quero ferramenta boa, sem tutorial',
                      ),
                    ],
                    selected: _literacySelected(),
                    onAnswer: (v) {
                      notifier.answerLiteracy(v, 3);
                      _goTo(4);
                    },
                    onSkip: () {
                      notifier.answerLiteracy(null, 3, skipped: true);
                      _goTo(4);
                    },
                  ),

                  // ── T5 · q_month_end ───────────────────────────────────
                  _QuestionPage<OnboardingMonthEnd>(
                    header: _header(4),
                    title: 'Como o seu mês costuma terminar?',
                    subtitle: 'Resposta honesta = plano honesto.',
                    options: const [
                      _Option(
                        value: OnboardingMonthEnd.surplus,
                        icon: Icons.sentiment_satisfied,
                        title: 'Sobra dinheiro',
                        description: 'Consigo guardar um pouco',
                      ),
                      _Option(
                        value: OnboardingMonthEnd.even,
                        icon: Icons.balance,
                        title: 'Empata',
                        description: 'Zero a zero, sem sobrar nem faltar',
                      ),
                      _Option(
                        value: OnboardingMonthEnd.deficit,
                        icon: Icons.trending_down,
                        title: 'Falta',
                        description: 'Entro no vermelho ou no limite',
                        empathyLine:
                            'Você não está sozinho(a). O plano vai te dar clareza.',
                      ),
                      _Option(
                        value: OnboardingMonthEnd.unknown,
                        icon: Icons.help_outline,
                        title: 'Sinceramente, não sei',
                        description: 'Nunca parei para medir',
                        empathyLine:
                            'Você não está sozinho(a). O plano vai te dar clareza.',
                      ),
                    ],
                    selected: ref.watch(
                        onboardingFlowProvider.select((s) => s.monthEnd)),
                    onAnswer: (v) {
                      notifier.answerMonthEnd(v, 4);
                      _goTo(5);
                    },
                    onSkip: () {
                      notifier.answerMonthEnd(null, 4, skipped: true);
                      _goTo(5);
                    },
                  ),

                  // ── T6 · q_leak ────────────────────────────────────────
                  _QuestionPage<OnboardingLeak>(
                    header: _header(5),
                    title: 'Onde você desconfia que o dinheiro mais escapa?',
                    subtitle: 'Chute honesto — vamos verificar juntos depois.',
                    options: const [
                      _Option(
                        value: OnboardingLeak.foodDelivery,
                        icon: Icons.restaurant,
                        title: 'Comida fora e delivery',
                      ),
                      _Option(
                        value: OnboardingLeak.subscriptions,
                        icon: Icons.subscriptions,
                        title: 'Assinaturas e serviços',
                      ),
                      _Option(
                        value: OnboardingLeak.impulse,
                        icon: Icons.shopping_bag,
                        title: 'Compras por impulso',
                      ),
                      _Option(
                        value: OnboardingLeak.fixed,
                        icon: Icons.home,
                        title: 'Contas fixas pesadas demais',
                      ),
                      _Option(
                        value: OnboardingLeak.unknown,
                        icon: Icons.help_outline,
                        title: 'Não faço ideia — e é isso que me assusta',
                      ),
                    ],
                    selected: ref
                        .watch(onboardingFlowProvider.select((s) => s.leak)),
                    onAnswer: (v) {
                      notifier.answerLeak(v, 5);
                      _goTo(6);
                    },
                    onSkip: () {
                      notifier.answerLeak(null, 5, skipped: true);
                      _goTo(6);
                    },
                  ),

                  // ── T7 · q_household ───────────────────────────────────
                  _QuestionPage<OnboardingHousehold>(
                    header: _header(6),
                    title:
                        'Você cuida do dinheiro sozinho(a) ou em conjunto?',
                    options: const [
                      _Option(
                        value: OnboardingHousehold.solo,
                        icon: Icons.person,
                        title: 'Sozinho(a)',
                      ),
                      _Option(
                        value: OnboardingHousehold.partner,
                        icon: Icons.favorite,
                        title: 'Com meu par',
                        description: 'Contas da casa em conjunto',
                      ),
                      _Option(
                        value: OnboardingHousehold.family,
                        icon: Icons.family_restroom,
                        title: 'Com a família',
                        description: 'Mais gente envolvida',
                      ),
                      _Option(
                        value: OnboardingHousehold.business,
                        icon: Icons.storefront,
                        title: 'Misturo pessoal com meu negócio',
                      ),
                    ],
                    selected: ref.watch(
                        onboardingFlowProvider.select((s) => s.household)),
                    onAnswer: (v) {
                      notifier.answerHousehold(v, 6);
                      _goTo(7);
                    },
                    onSkip: () {
                      notifier.answerHousehold(null, 6, skipped: true);
                      _goTo(7);
                    },
                  ),

                  // ── T8 · q_income (opcional por design) ────────────────
                  _QuestionPage<OnboardingIncomeBand?>(
                    header: _header(7),
                    title: 'Qual é a sua renda mensal aproximada?',
                    privacyNote:
                        'Opcional. Fica guardado só na sua conta — nunca sai '
                        'dela. Serve apenas para calcular seu plano em reais.',
                    options: const [
                      _Option(
                        value: OnboardingIncomeBand.upTo2k,
                        icon: Icons.payments,
                        title: 'Até R\$ 2.000',
                      ),
                      _Option(
                        value: OnboardingIncomeBand.from2to5k,
                        icon: Icons.payments,
                        title: 'R\$ 2.000 a R\$ 5.000',
                      ),
                      _Option(
                        value: OnboardingIncomeBand.from5to10k,
                        icon: Icons.payments,
                        title: 'R\$ 5.000 a R\$ 10.000',
                      ),
                      _Option(
                        value: OnboardingIncomeBand.over10k,
                        icon: Icons.payments,
                        title: 'Acima de R\$ 10.000',
                      ),
                      _Option(
                        value: null,
                        icon: Icons.lock_outline,
                        title: 'Prefiro não informar',
                        description: 'Seu plano sai em percentuais',
                      ),
                    ],
                    selected: _incomeSelected(),
                    onAnswer: (v) {
                      notifier.answerIncome(v, 7);
                      notifier.surveyCompleted();
                      _goTo(8);
                    },
                    onSkip: () {
                      notifier.answerIncome(null, 7, skipped: true);
                      notifier.surveyCompleted();
                      _goTo(8);
                    },
                  ),

                  // ── T9 · plan_result ───────────────────────────────────
                  _PlanResultPage(
                    onCommit: () => _goToStep(
                        widget.mode == OnboardingFlowMode.preAuth
                            ? 'auth_bridge'
                            : 'commitment'),
                    onSeeInApp: widget.mode == OnboardingFlowMode.preAuth
                        ? null
                        : _finishWithoutPaywall,
                    onBack: () => _goTo(_questionCount - 1),
                  ),
                  ],

                  if (widget.mode == OnboardingFlowMode.preAuth)
                    // ── T10 · ponte "salve seu plano" (cadastro) ─────────
                    _AuthBridgePage(onBack: () => _goToStep('plan_result'))
                  else ...[
                    // ── T10 · commitment (checkbox + confirmação) ────────
                    _CommitmentPage(
                      onConfirmed: () => _showPaywall(committed: true),
                      onSkipped: () {
                        notifier.skipCommitment();
                        _showPaywall(committed: false);
                      },
                      onBack: widget.mode == OnboardingFlowMode.postAuthFull
                          ? () => _goToStep('plan_result')
                          : null,
                    ),

                    // ── T11 · paywall (última página — rota única do
                    //    fluxo: o back nunca escapa sem desfecho) ─────────
                    OnboardingPaywallPage(
                      committed: _paywallCommitted,
                      onFinished: _finishFromPaywall,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// A pergunta de renda usa valor sentinela: null pode significar
  /// "não respondeu ainda" ou "prefiro não informar" — distinguido
  /// por [OnboardingAnswers.incomeAnswered].
  _SelectedValue<OnboardingIncomeBand?>? _incomeSelected() {
    final answers = ref.watch(onboardingFlowProvider);
    if (!answers.incomeAnswered) return null;
    return _SelectedValue(answers.incomeBand);
  }

  FinancialLiteracyLevel? _literacySelected() {
    final name =
        ref.watch(onboardingFlowProvider.select((s) => s.literacyLevel));
    if (name == null) return null;
    return FinancialLiteracyLevel.fromString(name);
  }

  _QuestionHeader _header(int questionIndex) => _QuestionHeader(
        current: questionIndex + 1,
        total: _questionCount,
        onBack: questionIndex == 0 ? null : _goBack,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Cabeçalho: voltar + barra de progresso + "N de 8"
// ─────────────────────────────────────────────────────────────────────────────

class _QuestionHeader extends StatelessWidget {
  final int current;
  final int total;
  final VoidCallback? onBack;

  const _QuestionHeader({
    required this.current,
    required this.total,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        if (onBack != null)
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Voltar',
          )
        else
          const SizedBox(width: 48),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: current / total,
              minHeight: 6,
              backgroundColor: cs.primary.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(cs.primary),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '$current de $total',
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
        const SizedBox(width: 16),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Página genérica de pergunta
// ─────────────────────────────────────────────────────────────────────────────

/// Wrapper para diferenciar "nada selecionado" de "selecionado = null"
/// (caso da opção "Prefiro não informar" na pergunta de renda).
class _SelectedValue<T> {
  final T value;
  const _SelectedValue(this.value);
}

class _Option<T> {
  final T value;
  final IconData icon;
  final String title;
  final String? description;

  /// Linha de empatia exibida inline no card após a seleção (q_month_end).
  final String? empathyLine;

  const _Option({
    required this.value,
    required this.icon,
    required this.title,
    this.description,
    this.empathyLine,
  });
}

class _QuestionPage<T> extends StatefulWidget {
  final _QuestionHeader header;
  final String? microHeader;
  final String title;
  final String? subtitle;
  final String? privacyNote;
  final List<_Option<T>> options;

  /// Valor previamente respondido (para destacar ao voltar). Para a pergunta
  /// de renda, um [_SelectedValue] embrulha o valor; para as demais o próprio
  /// valor é comparado diretamente.
  final Object? selected;
  final ValueChanged<T> onAnswer;
  final VoidCallback onSkip;
  final Widget? extraFooter;

  const _QuestionPage({
    super.key,
    required this.header,
    this.microHeader,
    required this.title,
    this.subtitle,
    this.privacyNote,
    required this.options,
    required this.selected,
    required this.onAnswer,
    required this.onSkip,
    this.extraFooter,
  });

  @override
  State<_QuestionPage<T>> createState() => _QuestionPageState<T>();
}

class _QuestionPageState<T> extends State<_QuestionPage<T>> {
  T? _pending;
  bool _answering = false;

  bool _isSelected(_Option<T> option) {
    if (_answering) return option.value == _pending;
    final sel = widget.selected;
    if (sel == null) return false;
    if (sel is _SelectedValue) return option.value == sel.value;
    return option.value == sel;
  }

  Future<void> _select(_Option<T> option) async {
    if (_answering) return;
    setState(() {
      _answering = true;
      _pending = option.value;
    });
    // Auto-avanço: 250 ms padrão; 1 s quando há linha de empatia.
    final delay = option.empathyLine != null
        ? const Duration(milliseconds: 1000)
        : const Duration(milliseconds: 250);
    await Future.delayed(delay);
    if (!mounted) return;
    setState(() => _answering = false);
    widget.onAnswer(option.value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      children: [
        const SizedBox(height: 8),
        widget.header,
        Expanded(
          // Centraliza o conteúdo verticalmente quando cabe na tela; quando é
          // maior (telas baixas / fonte grande), o IntrinsicHeight assume a
          // altura natural e a rolagem entra normalmente. crossAxisAlignment
          // fica em stretch para os cards de opção manterem a largura total.
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight:
                      (constraints.maxHeight - 24).clamp(0.0, double.infinity),
                ),
                child: IntrinsicHeight(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.microHeader != null) ...[
                        Text(
                          widget.microHeader!,
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Text(
                        widget.title,
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (widget.subtitle != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          widget.subtitle!,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                      if (widget.privacyNote != null) ...[
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.lock_outline,
                                size: 16, color: cs.onSurfaceVariant),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                widget.privacyNote!,
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: cs.onSurfaceVariant),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 20),
                      for (final option in widget.options) ...[
                        _OptionCard(
                          icon: option.icon,
                          title: option.title,
                          description: option.description,
                          empathyLine:
                              _isSelected(option) ? option.empathyLine : null,
                          selected: _isSelected(option),
                          onTap: () => _select(option),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Column(
            children: [
              TextButton(
                onPressed: _answering ? null : widget.onSkip,
                child: Text(
                  'Pular',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ),
              if (widget.extraFooter != null) widget.extraFooter!,
            ],
          ),
        ),
      ],
    );
  }
}

// Card de opção — mesmo padrão visual do `_LevelOption` do dialog antigo.
class _OptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final String? empathyLine;
  final bool selected;
  final VoidCallback onTap;

  const _OptionCard({
    required this.icon,
    required this.title,
    this.description,
    this.empathyLine,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? primary.withValues(alpha: 0.08)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                selected ? primary : theme.colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 20, color: primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (description != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          description!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: selected
                      ? primary
                      : theme.colorScheme.onSurfaceVariant,
                  size: 20,
                ),
              ],
            ),
            if (empathyLine != null) ...[
              const SizedBox(height: 8),
              Text(
                empathyLine!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// T9 — Reveal do plano (valor imediato, cascata sem teatro)
// ─────────────────────────────────────────────────────────────────────────────

class _PlanResultPage extends ConsumerWidget {
  final VoidCallback onCommit;

  /// Null no modo pré-cadastro (ver o plano "no app" exige conta).
  final VoidCallback? onSeeInApp;
  final VoidCallback onBack;

  const _PlanResultPage({
    required this.onCommit,
    required this.onSeeInApp,
    required this.onBack,
  });

  static const _archetypePhrases = {
    OnboardingArchetype.viraJogo:
        'Você decidiu encarar as contas de frente. Ver tudo é o primeiro '
            'passo da virada — e você acabou de dar.',
    OnboardingArchetype.detetive:
        'Você quer saber para onde vai cada real. O Fintab é a sua lupa.',
    OnboardingArchetype.sonho:
        'Você tem um destino. A partir de agora, cada gasto é uma escolha '
            'entre o hoje e ele.',
    OnboardingArchetype.estrategista:
        'Você já domina o básico. Agora é medir, ajustar e fazer render.',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final answers = ref.watch(onboardingFlowProvider);
    final plan = buildOnboardingPlan(answers);
    final projection = buildOnboardingProjection(answers);
    final fmt = ref.watch(currencyFormatterProvider);

    var phrase = _archetypePhrases[answers.archetype]!;
    if (answers.monthEnd == OnboardingMonthEnd.deficit ||
        answers.monthEnd == OnboardingMonthEnd.unknown) {
      phrase = '$phrase E olhar de frente já foi a parte mais difícil.';
    }

    var stagger = 0;
    Widget staggered(Widget child) =>
        _Staggered(order: stagger++, child: child);

    return Column(
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Voltar',
            ),
          ],
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight:
                      (constraints.maxHeight - 16).clamp(0.0, double.infinity),
                ),
                child: IntrinsicHeight(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      staggered(Text(
                        'Pronto. Este é o seu ponto de partida.',
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      )),
                      const SizedBox(height: 16),

                      // Chip do arquétipo
                      staggered(Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: cs.primary.withValues(alpha: 0.4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SEU PERFIL: '
                              '${answers.archetype.displayName.toUpperCase()}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                                color: cs.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(phrase, style: theme.textTheme.bodySmall),
                          ],
                        ),
                      )),
                      const SizedBox(height: 16),

                      // Card do plano modelo
                      staggered(
                          _PlanCard(plan: plan, answers: answers, fmt: fmt)),
                      const SizedBox(height: 16),

                      // Card da projeção
                      staggered(
                          _ProjectionCard(projection: projection, fmt: fmt)),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton(
                onPressed: onCommit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Quero me comprometer com isso'),
              ),
              if (onSeeInApp != null)
                TextButton(
                  onPressed: onSeeInApp,
                  child: const Text('Ver meu plano no app'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  final OnboardingPlan plan;
  final OnboardingAnswers answers;
  final String Function(double) fmt;

  const _PlanCard({
    required this.plan,
    required this.answers,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final income = plan.incomeReference;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Seu plano modelo de gastos',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              income != null
                  ? 'Baseado na regra 50/30/20 adaptada (50% necessidades · '
                      '20% desejos · 30% para guardar) e na sua faixa de '
                      'renda (referência: ${fmt(income)}). '
                      'Você ajusta tudo depois.'
                  : 'Baseado na regra 50/30/20 adaptada (50% necessidades · '
                      '20% desejos · 30% para guardar), em percentuais. '
                      'Informe sua renda quando quiser para ver os valores.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
            if (plan.attentionOnWholePlan) ...[
              const SizedBox(height: 10),
              const _AttentionChip(label: 'vamos descobrir juntos'),
            ],
            const SizedBox(height: 16),

            // Barras dos 3 grupos
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
                  value: group.percentage / 100,
                  minHeight: 8,
                  backgroundColor: cs.primary.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation(cs.primary),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Divider(color: cs.outlineVariant),
            const SizedBox(height: 4),

            // As 8 categorias
            for (final item in plan.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(item.categoryName,
                              style: theme.textTheme.bodyMedium),
                          if (item.highlighted)
                            const _AttentionChip(
                                label: 'seu ponto de atenção'),
                        ],
                      ),
                    ),
                    Text(
                      item.amount != null
                          ? fmt(item.amount!)
                          : '${item.percentage.toStringAsFixed(0)}%',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AttentionChip extends StatelessWidget {
  final String label;
  const _AttentionChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _kAmber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 13, color: Color(0xFFEF6C00)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFFEF6C00),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectionCard extends StatelessWidget {
  final OnboardingProjection projection;
  final String Function(double) fmt;

  const _ProjectionCard({required this.projection, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final floor = projection.incomeFloor;

    final String lead;
    final String secondary;
    if (floor == null) {
      lead = 'Este plano reserva 30% da sua renda — em 12 meses, '
          '3,6 rendas mensais guardadas.';
      secondary = 'Começando com 10%, são 1,2 renda no primeiro ano.';
    } else if (projection.thirtyLeads) {
      lead = 'Guardando os 30% do plano: ${fmt(projection.savings30!)} '
          'em 12 meses.';
      secondary =
          'Começando com só 10%: ${fmt(projection.savings10!)}.';
    } else {
      lead = 'Começando com só 10%: ${fmt(projection.savings10!)} '
          'em 12 meses.';
      secondary = 'Quando o plano engatar, os 30% viram '
          '${fmt(projection.savings30!)}.';
    }

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Seu potencial em 12 meses',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              lead,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              secondary,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
            if (floor != null) ...[
              const SizedBox(height: 10),
              Text(
                'Matemática simples: renda × percentual guardado × 12 meses '
                '— calculada com o piso da sua faixa (${fmt(floor)}), para '
                'nunca prometer demais. Nenhuma garantia: o resultado '
                'depende da sua constância.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant, height: 1.4),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Entrada em cascata (stagger 150 ms) — reveal instantâneo, sem loading.
class _Staggered extends StatelessWidget {
  final int order;
  final Widget child;

  const _Staggered({required this.order, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 250 + order * 150),
      curve: Interval(
        order * 150 / (250 + order * 150),
        1,
        curve: Curves.easeOut,
      ),
      builder: (context, value, c) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - value)),
          child: c,
        ),
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// T10 — Compromisso: checkbox + confirmação
// ─────────────────────────────────────────────────────────────────────────────

class _CommitmentPage extends ConsumerStatefulWidget {
  final VoidCallback onConfirmed;
  final VoidCallback onSkipped;

  /// Null no modo continuação (não há tela de plano atrás).
  final VoidCallback? onBack;

  const _CommitmentPage({
    required this.onConfirmed,
    required this.onSkipped,
    required this.onBack,
  });

  @override
  ConsumerState<_CommitmentPage> createState() => _CommitmentPageState();
}

class _CommitmentPageState extends ConsumerState<_CommitmentPage> {
  late final TextEditingController _nameController;
  bool _accepted = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authStateProvider).value;
    _nameController =
        TextEditingController(text: user?.displayName?.trim() ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _canConfirm =>
      _accepted && _nameController.text.trim().isNotEmpty;

  void _confirm() {
    ref
        .read(onboardingFlowProvider.notifier)
        .confirmCommitment(_nameController.text);
    HapticFeedback.mediumImpact();
    widget.onConfirmed();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final dateLocale = ref.watch(dateLocaleProvider);
    final today = DateFormat("d 'de' MMMM 'de' y", dateLocale)
        .format(DateTime.now());
    final name = _nameController.text.trim();

    return Column(
      children: [
        const SizedBox(height: 8),
        if (widget.onBack != null)
          Row(
            children: [
              IconButton(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Voltar',
              ),
            ],
          )
        else
          const SizedBox(height: 16),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight:
                      (constraints.maxHeight - 16).clamp(0.0, double.infinity),
                ),
                child: IntrinsicHeight(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Seu compromisso',
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Não é com o app. É com você.',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                      const SizedBox(height: 20),

                      // Moldura de "termo"
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: cs.outlineVariant),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.handshake_outlined,
                                size: 32, color: cs.primary),
                            const SizedBox(height: 12),
                            Text.rich(
                              TextSpan(
                                style: theme.textTheme.bodyLarge
                                    ?.copyWith(height: 1.5),
                                children: [
                                  const TextSpan(text: 'Eu, '),
                                  TextSpan(
                                    text: name.isEmpty ? '________' : name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700),
                                  ),
                                  const TextSpan(
                                    text:
                                        ', me comprometo a olhar para o meu '
                                        'dinheiro sem medo, registrar meus '
                                        'gastos com honestidade e dar pelo '
                                        'menos um passo por mês em direção à '
                                        'minha liberdade financeira.',
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _nameController,
                              textCapitalization: TextCapitalization.words,
                              onChanged: (_) => setState(() {}),
                              decoration: const InputDecoration(
                                labelText: 'Seu nome',
                                isDense: true,
                              ),
                            ),
                            const SizedBox(height: 12),
                            CheckboxListTile(
                              value: _accepted,
                              onChanged: (v) =>
                                  setState(() => _accepted = v ?? false),
                              controlAffinity:
                                  ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              title: Text(
                                'Li e assumo este compromisso comigo '
                                'mesmo(a).',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                            if (_accepted)
                              Padding(
                                padding:
                                    const EdgeInsets.only(left: 4, top: 2),
                                child: Text(
                                  'Confirmado em $today',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Seu compromisso fica guardado na sua conta — só o '
                        'seu nome e a data.',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton(
                onPressed: _canConfirm ? _confirm : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Confirmar meu compromisso'),
              ),
              TextButton(
                onPressed: widget.onSkipped,
                child: Text(
                  'Agora não',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// T10 (pré-cadastro) — ponte "salve seu plano": a conta é criada no pico de
// motivação, como o jeito de guardar o plano que o usuário acabou de montar.
// ─────────────────────────────────────────────────────────────────────────────

class _AuthBridgePage extends StatelessWidget {
  final VoidCallback onBack;
  const _AuthBridgePage({required this.onBack});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Voltar',
            ),
          ],
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight:
                      (constraints.maxHeight - 16).clamp(0.0, double.infinity),
                ),
                child: IntrinsicHeight(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(Icons.cloud_done_outlined,
                          size: 48, color: cs.primary),
                      const SizedBox(height: 16),
                      Text(
                        'Salve seu plano',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Crie sua conta grátis para guardar seu plano e suas '
                        'respostas — e continuar de onde parou, no celular ou '
                        'no computador.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: cs.onSurfaceVariant, height: 1.4),
                      ),
                      const SizedBox(height: 24),
                      const _BridgeItem(
                        icon: Icons.savings_outlined,
                        text: 'Seu plano modelo fica guardado na sua conta',
                      ),
                      const _BridgeItem(
                        icon: Icons.lock_outline,
                        text:
                            'Suas respostas ficam só na sua conta — nunca saem '
                            'dela',
                      ),
                      const _BridgeItem(
                        icon: Icons.devices_outlined,
                        text: 'Continue no celular e na web com o mesmo login',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Criar conta grátis'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                ),
                child: const Text('Já tenho conta'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BridgeItem extends StatelessWidget {
  final IconData icon;
  final String text;
  const _BridgeItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: cs.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
