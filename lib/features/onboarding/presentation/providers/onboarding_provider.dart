import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/providers/app_settings_provider.dart';
import '../../../../core/providers/effective_user_provider.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../budget/presentation/providers/budget_provider.dart';
import '../../../categories/presentation/providers/categories_provider.dart';
import '../../domain/onboarding_profile.dart';

/// Eventos de funil do onboarding. Envolto em try/catch: analytics nunca
/// pode derrubar o fluxo (ex.: Firebase indisponível, testes de widget).
void logOnboardingEvent(String name, [Map<String, Object>? params]) {
  try {
    // catchError cobre a falha assíncrona do plugin; o try, a síncrona
    // (ex.: Firebase não inicializado em testes de widget).
    AnalyticsService.instance.logEvent(name, params).catchError((_) {});
  } catch (_) {
    // Telemetria é melhor-esforço.
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status — decide se o fluxo de onboarding deve ser exibido.
//
// Tri-state: null enquanto o perfil ainda carrega (não mostrar nada),
// true quando o fluxo deve abrir, false caso contrário.
// ─────────────────────────────────────────────────────────────────────────────

/// Respostas coletadas ANTES do cadastro, guardadas no aparelho até a conta
/// existir. null = sem pendência. Invalidar após consumir/limpar o stash.
final onboardingStashProvider = FutureProvider<Map<String, dynamic>?>(
  (ref) => OnboardingFlowNotifier.readStash(),
);

final needsOnboardingProvider = Provider<bool?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return false;

  final profileAsync = ref.watch(userProfileStreamProvider);
  final stashAsync = ref.watch(onboardingStashProvider);
  if (profileAsync.isLoading || stashAsync.isLoading) return null;

  final onb =
      (profileAsync.value?['onboardingProfile'] as Map<String, dynamic>?);

  // Já completou ou adiou explicitamente → nunca reabrir sozinho.
  if (onb?['completedAt'] != null || onb?['deferredAt'] != null) return false;

  // Pesquisa respondida antes do cadastro → continuar (compromisso+paywall).
  if (stashAsync.value?['surveyDone'] == true) return true;

  // Começou e abandonou no meio → retomar na próxima abertura.
  if (onb?['startedAt'] != null) return true;

  // Usuário novo neste aparelho: o marcador é o mesmo do dialog antigo
  // (nível de familiaridade ainda não respondido).
  final literacy = ref.watch(
    appSettingsProvider.select((s) => s.literacyLevel),
  );
  return literacy == FinancialLiteracyLevel.unset;
});

/// Respostas do onboarding reconstruídas de users/{uid}.onboardingProfile, ou
/// null se a pesquisa ainda não foi concluída (sem arquétipo gravado). Alimenta
/// o card "Seu plano" do dashboard e o gate que decide exibi-lo.
final onboardingPlanAnswersProvider = Provider<OnboardingAnswers?>((ref) {
  final profile = ref.watch(userProfileStreamProvider).value;
  final onb = profile?['onboardingProfile'] as Map<String, dynamic>?;
  if (onb == null || onb['archetype'] == null) return null;
  return OnboardingAnswers.fromProfileMap(onb);
});

// ─────────────────────────────────────────────────────────────────────────────
// Fluxo — respostas em memória + persistência incremental no Firestore.
//
// Todas as escritas usam SetOptions(merge: true) no doc users/{uid}
// (nunca tocar em masterUserId) e são fire-and-forget: uma falha de rede
// não pode travar o onboarding.
// ─────────────────────────────────────────────────────────────────────────────

class OnboardingFlowNotifier extends StateNotifier<OnboardingAnswers> {
  static const _kStashKey = 'onboarding_preauth_answers';

  final Ref _ref;
  DateTime? _startedAt;
  bool _startPersisted = false;
  bool _abandonLogged = false;
  bool _surveyDone = false;
  final Set<String> _answeredSteps = {};

  OnboardingFlowNotifier(this._ref) : super(const OnboardingAnswers());

  bool get _isPreAuth => _ref.read(authStateProvider).value == null;

  // ── Stash pré-cadastro (SharedPreferences) ─────────────────────────────────
  // Antes de existir conta, as respostas vivem no aparelho; ao criar a conta
  // são gravadas de uma vez no Firestore e o stash é limpo.

  static Future<Map<String, dynamic>?> readStash() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kStashKey);
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearStash() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kStashKey);
    } catch (_) {}
  }

  void _stash() {
    if (!_isPreAuth) return;
    final s = state;
    final map = <String, dynamic>{
      'goal': s.goal?.id,
      'currentMethod': s.currentMethod?.id,
      'controlStyle': s.controlStyle?.id,
      'literacyLevel': s.literacyLevel,
      'monthEnd': s.monthEnd?.id,
      'leak': s.leak?.id,
      'household': s.household?.id,
      'incomeBand': s.incomeBand?.id,
      'incomeAnswered': s.incomeAnswered,
      'answered': _answeredSteps.toList(),
      'surveyDone': _surveyDone,
      'startedAtMs': _startedAt?.millisecondsSinceEpoch,
    };
    SharedPreferences.getInstance()
        .then((prefs) => prefs.setString(_kStashKey, jsonEncode(map)))
        .catchError((_) => true);
  }

  /// Carrega respostas de uma sessão anterior — tanto do stash pré-cadastro
  /// quanto do mapa `onboardingProfile` do Firestore (mesmos nomes de campo).
  void hydrate(Map<String, dynamic> data) {
    state = OnboardingAnswers.fromProfileMap(data);
    _answeredSteps
      ..clear()
      ..addAll(((data['answered'] as List?) ?? const []).whereType<String>());
    _surveyDone = data['surveyDone'] == true || data['archetype'] != null;
    final ms = data['startedAtMs'];
    if (ms is int) _startedAt = DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// Pós-cadastro: grava de uma vez as respostas coletadas antes da conta
  /// existir e limpa o stash do aparelho.
  void persistPreAuthAnswers() {
    final s = state;
    _startPersisted = true;
    _merge({
      'version': 1,
      'startedAt': FieldValue.serverTimestamp(),
      'goal': s.goal?.id,
      'currentMethod': s.currentMethod?.id,
      'controlStyle': s.controlStyle?.id,
      'literacyLevel': s.literacyLevel,
      'monthEnd': s.monthEnd?.id,
      'leak': s.leak?.id,
      'household': s.household?.id,
      'incomeBand': s.incomeBand?.id,
      'archetype': s.archetype.id,
      'lastStepId': 'commitment',
      'lastStepIndex': 0,
    });
    clearStash();
    _ref.invalidate(onboardingStashProvider);
  }

  /// Fire-and-forget DE VERDADE: o Future do set() só resolve com ack do
  /// servidor (offline fica pendente para sempre), então nunca o aguardamos —
  /// a persistência offline do Firestore enfileira e sincroniza depois.
  /// Nenhum botão de saída do fluxo pode depender de rede.
  void _merge(Map<String, dynamic> profileFields) {
    final uid = _ref.read(authStateProvider).value?.id;
    if (uid == null) return;
    try {
      _ref
          .read(firestoreProvider)
          .collection('users')
          .doc(uid)
          .set(
            {'onboardingProfile': profileFields},
            SetOptions(merge: true),
          )
          .catchError((_) {});
    } catch (_) {
      // As respostas são regraváveis na retomada.
    }
  }

  void _logStep(String stepId, int stepIndex, {bool? skipped}) {
    logOnboardingEvent('onboarding_step_completed', {
      'step_id': stepId,
      'step_index': stepIndex,
      // EXCEÇÃO q_income: `skipped` é OMITIDO — revelaria se a renda foi
      // informada (dado financeiro proibido no analytics pela política).
      if (skipped != null && stepId != 'q_income') 'skipped': skipped,
    });
  }

  void logStepViewed(String stepId, int stepIndex) {
    logOnboardingEvent('onboarding_step_viewed', {
      'step_id': stepId,
      'step_index': stepIndex,
    });
  }

  /// Grava `startedAt` uma única vez e loga o início do funil.
  /// Pré-cadastro o `_merge` é no-op (sem uid) — o stash guarda o início.
  void markStarted({required bool alreadyStartedBefore}) {
    _startedAt ??= DateTime.now();
    if (_startPersisted) return;
    _startPersisted = true;
    if (alreadyStartedBefore) {
      logOnboardingEvent('onboarding_resumed');
      return;
    }
    logOnboardingEvent('onboarding_started');
    _merge({'version': 1, 'startedAt': FieldValue.serverTimestamp()});
    _stash();
  }

  /// Chamado pelo gate quando encontra um fluxo começado e não concluído
  /// de uma sessão anterior (dispara uma única vez por sessão).
  void maybeLogAbandoned(Map<String, dynamic>? onb) {
    if (_abandonLogged || onb == null) return;
    if (onb['startedAt'] == null ||
        onb['completedAt'] != null ||
        onb['deferredAt'] != null) {
      return;
    }
    _abandonLogged = true;
    logOnboardingEvent('onboarding_flow_abandoned', {
      if (onb['lastStepId'] is String) 'last_step_id': onb['lastStepId'],
      if (onb['lastStepIndex'] is int) 'last_step_index': onb['lastStepIndex'],
    });
  }

  /// "Agora não, quero explorar antes" na 1ª pergunta.
  void defer() {
    logOnboardingEvent('onboarding_deferred');
    _merge({
      'version': 1,
      'deferredAt': FieldValue.serverTimestamp(),
    });
  }

  /// Registra a chegada às telas pós-pesquisa (plan_result/commitment) para
  /// que o onboarding_flow_abandoned aponte o passo certo.
  void markStepReached(String stepId, int stepIndex) {
    _merge({'lastStepId': stepId, 'lastStepIndex': stepIndex});
  }

  void _saveAnswer(
    String stepId,
    int stepIndex,
    Map<String, dynamic> fields, {
    required bool skipped,
  }) {
    if (skipped) {
      _answeredSteps.remove(stepId);
    } else {
      _answeredSteps.add(stepId);
    }
    _logStep(stepId, stepIndex, skipped: skipped);
    _merge({
      ...fields,
      'lastStepId': stepId,
      'lastStepIndex': stepIndex,
    });
    _stash();
  }

  void answerGoal(OnboardingGoal? goal, int stepIndex,
      {bool skipped = false}) {
    final effective = goal ?? OnboardingGoal.clarity;
    state = state.copyWith(goal: effective);
    _saveAnswer('q_goal', stepIndex, {'goal': effective.id},
        skipped: skipped);
  }

  void answerMethod(OnboardingMethod? method, int stepIndex,
      {bool skipped = false}) {
    state = state.copyWith(
        currentMethod: method, clearCurrentMethod: method == null);
    _saveAnswer('q_current_method', stepIndex, {'currentMethod': method?.id},
        skipped: skipped);
  }

  void answerControlStyle(OnboardingControlStyle? style, int stepIndex,
      {bool skipped = false}) {
    final effective = style ?? OnboardingControlStyle.track;
    state = state.copyWith(controlStyle: effective);
    _saveAnswer('q_control_style', stepIndex, {'controlStyle': effective.id},
        skipped: skipped);
  }

  void answerLiteracy(FinancialLiteracyLevel? level, int stepIndex,
      {bool skipped = false}) {
    final effective = level ?? FinancialLiteracyLevel.beginner;
    state = state.copyWith(literacyLevel: effective.name);
    // Mesmo mecanismo do dialog antigo: controla as dicas contextuais
    // e impede que o dialog reapareça.
    _ref.read(appSettingsProvider.notifier).setLiteracyLevel(effective);
    _saveAnswer('q_literacy', stepIndex, {'literacyLevel': effective.name},
        skipped: skipped);
  }

  void answerMonthEnd(OnboardingMonthEnd? monthEnd, int stepIndex,
      {bool skipped = false}) {
    state =
        state.copyWith(monthEnd: monthEnd, clearMonthEnd: monthEnd == null);
    _saveAnswer('q_month_end', stepIndex, {'monthEnd': monthEnd?.id},
        skipped: skipped);
  }

  void answerLeak(OnboardingLeak? leak, int stepIndex,
      {bool skipped = false}) {
    state = state.copyWith(leak: leak, clearLeak: leak == null);
    _saveAnswer('q_leak', stepIndex, {'leak': leak?.id}, skipped: skipped);
  }

  void answerHousehold(OnboardingHousehold? household, int stepIndex,
      {bool skipped = false}) {
    state = state.copyWith(
        household: household, clearHousehold: household == null);
    _saveAnswer('q_household', stepIndex, {'household': household?.id},
        skipped: skipped);
  }

  void answerIncome(OnboardingIncomeBand? band, int stepIndex,
      {bool skipped = false}) {
    state = state.copyWith(
      incomeBand: band,
      clearIncomeBand: band == null,
      incomeAnswered: true,
    );
    // `skipped` NUNCA é logado neste passo (ver _logStep).
    _saveAnswer('q_income', stepIndex, {'incomeBand': band?.id},
        skipped: skipped);
  }

  /// Fim da pesquisa (antes do reveal do plano). A contagem usa os passos
  /// EFETIVAMENTE respondidos (pular com default gravado não conta) e
  /// exclui q_income por política de privacidade.
  void surveyCompleted() {
    final answered = _answeredSteps.where((id) => id != 'q_income').length;
    logOnboardingEvent('onboarding_survey_completed', {
      'answered_count': answered,
    });
    _surveyDone = true;
    _merge({'archetype': state.archetype.id});
    _stash();
  }

  /// Confirmação do compromisso (checkbox + botão).
  void confirmCommitment(String name) {
    logOnboardingEvent('commitment_signed', {'method': 'checkbox'});
    _merge({
      'commitment': {
        'signed': true,
        'signedAt': FieldValue.serverTimestamp(),
        'name': name.trim(),
      },
    });
  }

  void skipCommitment() {
    logOnboardingEvent('commitment_skipped');
  }

  /// Fim do fluxo (após o paywall, comprado ou pulado).
  void complete() {
    final elapsed = _startedAt == null
        ? 0
        : DateTime.now().difference(_startedAt!).inSeconds;
    logOnboardingEvent('onboarding_completed', {'elapsed_seconds': elapsed});
    _merge({'completedAt': FieldValue.serverTimestamp()});
    // Materializa o plano modelo como orçamentos reais do mês corrente, para o
    // usuário já encontrar tudo pronto na Home. Fire-and-forget: nunca trava a
    // saída do fluxo.
    _autoCreatePlanBudgets();
  }

  /// Cria os orçamentos do plano modelo (regra 50/30/20 adaptada) a partir das
  /// respostas, no mês corrente. Idempotente: o id do orçamento é
  /// determinístico por categoria+mês, então re-execuções sobrescrevem em vez
  /// de duplicar. Só roda quando o usuário informou a renda — sem renda o plano
  /// é apenas percentual, sem valor a orçar. Melhor-esforço: uma falha (rede,
  /// ou categorias padrão ainda não semeadas) nunca derruba o fim do
  /// onboarding.
  Future<void> _autoCreatePlanBudgets() async {
    final plan = buildOnboardingPlan(state);
    if (plan.incomeReference == null) return;
    try {
      // As categorias padrão batem 1:1 com o template do plano, mas são
      // semeadas de forma preguiçosa quando a MainScreen monta. Esperamos elas
      // existirem antes de mapear nome→id, evitando orçamentos órfãos.
      var categories = _ref.read(expenseCategoriesProvider);
      for (var attempt = 0; attempt < 12 && categories.isEmpty; attempt++) {
        await Future.delayed(const Duration(milliseconds: 300));
        categories = _ref.read(expenseCategoriesProvider);
      }
      if (categories.isEmpty) return;
      final byName = {
        for (final c in categories) c.name.toLowerCase().trim(): c,
      };
      final month = DateTime.now();
      // Dispara as escritas concorrentemente: cada set() enfileira a escrita
      // local do Firestore de imediato, então mesmo offline — ou se o app for
      // fechado logo após o onboarding — as 8 já entram na fila de
      // sincronização (o laço sequencial deixava de fora as não-alcançadas, e
      // fazia os orçamentos "pingarem" na Home ao longo de vários segundos).
      // Relê o notifier por chamada para sobreviver a uma reconstrução do
      // provider (ex.: troca de workspace) no meio.
      final writes = <Future<void>>[];
      for (final item in plan.items) {
        final amount = item.amount;
        if (amount == null || amount <= 0) continue;
        final category = byName[item.categoryName.toLowerCase().trim()];
        if (category == null) continue;
        writes.add(
          _ref.read(budgetNotifierProvider.notifier).set(
                categoryId: category.id,
                categoryName: category.name,
                limitAmount: amount,
                month: month,
              ),
        );
      }
      await Future.wait(writes);
    } catch (_) {
      // Auto-criação é melhor-esforço; o usuário pode criar manualmente depois.
    }
  }
}

/// Recriado a cada troca de usuário: respostas e flags (_startPersisted,
/// _answeredSteps…) de uma conta jamais podem vazar para outra na mesma
/// sessão do app.
final onboardingFlowProvider =
    StateNotifierProvider<OnboardingFlowNotifier, OnboardingAnswers>((ref) {
  ref.watch(authStateProvider.select((auth) => auth.value?.id));
  return OnboardingFlowNotifier(ref);
});

// ─────────────────────────────────────────────────────────────────────────────
// Personalização do paywall — headline + 4 benefícios rankeados
// ─────────────────────────────────────────────────────────────────────────────

class OnboardingBenefit {
  final IconData icon;
  final String title;
  const OnboardingBenefit(this.icon, this.title);
}

const _bCredit = OnboardingBenefit(
    Icons.credit_card_rounded, 'Cartão de crédito: fatura e parcelas');
const _bBudgets = OnboardingBenefit(
    Icons.pie_chart_outline_rounded, 'Orçamentos por categoria com alertas');
const _bHealth = OnboardingBenefit(
    Icons.monitor_heart_rounded, 'Saúde financeira: score de 0 a 100');
const _bRecurring =
    OnboardingBenefit(Icons.repeat_rounded, 'Transações recorrentes');
const _bAccounts = OnboardingBenefit(
    Icons.account_balance_wallet_rounded, 'Múltiplas contas');
const _bImport = OnboardingBenefit(
    Icons.file_download_rounded, 'Importação de extratos (OFX/CSV)');
const _bCategories =
    OnboardingBenefit(Icons.category_rounded, 'Categorias personalizadas');
const _bTags = OnboardingBenefit(
    Icons.label_outline_rounded, 'Tags para cruzar seus gastos');
const _bGoals =
    OnboardingBenefit(Icons.savings_rounded, 'Metas com progresso visual');
const _bRollover = OnboardingBenefit(
    Icons.pie_chart_outline_rounded, 'Orçamentos com rollover mensal');
const _bAnnual =
    OnboardingBenefit(Icons.calendar_month_rounded, 'Visão anual completa');
const _bExport = OnboardingBenefit(
    Icons.ios_share_rounded, 'Exportação de relatórios (PDF/Excel)');
const _bCurrency = OnboardingBenefit(
    Icons.currency_exchange_rounded, 'Conversor de moedas com cotação real');
const _bSharing = OnboardingBenefit(Icons.people_rounded,
    'Compartilhamento: Carteiras com quem divide a vida com você');
const _bPfPj = OnboardingBenefit(Icons.business_center_rounded,
    'Carteiras PF e PJ: separe o pessoal do seu negócio');
const _bSubsDetection = OnboardingBenefit(Icons.subscriptions_rounded,
    'Recorrentes + detecção de assinaturas');

/// Lista final SEMPRE com 4 benefícios (teto de destaques da spec).
List<OnboardingBenefit> buildPaywallBenefits(OnboardingAnswers answers) {
  final goal = answers.goal ?? OnboardingGoal.clarity;

  var list = <OnboardingBenefit>[
    ...switch (goal) {
      OnboardingGoal.debts => [_bCredit, _bBudgets, _bHealth, _bRecurring],
      OnboardingGoal.clarity => [_bAccounts, _bImport, _bCategories, _bTags],
      OnboardingGoal.save => [_bGoals, _bRollover, _bAnnual, _bHealth],
      OnboardingGoal.grow => [_bHealth, _bAnnual, _bExport, _bCurrency],
    },
  ];

  void insertAt(int index, OnboardingBenefit benefit) {
    list.removeWhere((b) => b.title == benefit.title);
    final i = index.clamp(0, list.length);
    list.insert(i, benefit);
    // Teto de 4 destaques: cada injeção descarta o último item — mas nunca
    // o recém-injetado (caso das injeções na última posição).
    if (list.length > 4) {
      list.removeAt(i == list.length - 1 ? list.length - 2 : list.length - 1);
    }
  }

  // 1. Estilo de controle casa com um benefício → posição 1.
  if (answers.controlStyle == OnboardingControlStyle.budget) {
    insertAt(0, goal == OnboardingGoal.save ? _bRollover : _bBudgets);
  } else if (answers.controlStyle == OnboardingControlStyle.goals) {
    insertAt(0, _bGoals);
  }

  // 2. Quem divide a vida/negócio → posição 2.
  var householdInjected = false;
  if (answers.household == OnboardingHousehold.partner ||
      answers.household == OnboardingHousehold.family) {
    insertAt(1, _bSharing);
    householdInjected = true;
  } else if (answers.household == OnboardingHousehold.business) {
    insertAt(1, _bPfPj);
    householdInjected = true;
  }

  // 3. Vem de planilha/outro app → importação em destaque.
  if (answers.currentMethod == OnboardingMethod.sheet ||
      answers.currentMethod == OnboardingMethod.app) {
    insertAt(householdInjected ? 2 : 1, _bImport);
  }

  // 4. Vazamento declarado.
  if (answers.leak == OnboardingLeak.subscriptions) {
    insertAt(list.length, _bSubsDetection);
  } else if (answers.leak == OnboardingLeak.impulse &&
      !list.any((b) => b.title == _bBudgets.title ||
          b.title == _bRollover.title)) {
    insertAt(list.length, _bBudgets);
  }

  if (list.length > 4) list = list.sublist(0, 4);
  return list;
}

/// Headline do paywall por objetivo × compromisso confirmado ou não.
String paywallHeadline(OnboardingAnswers answers, {required bool committed}) {
  final goal = answers.goal;
  if (goal == null && !committed) {
    return 'Seu plano está pronto. O Pro coloca ele para trabalhar por você.';
  }
  switch (goal ?? OnboardingGoal.clarity) {
    case OnboardingGoal.debts:
      return committed
          ? 'Você se comprometeu com a virada. O Pro te dá o mapa dela.'
          : 'Você quer a virada. O Pro te dá o mapa.';
    case OnboardingGoal.clarity:
      return committed
          ? 'Você se comprometeu com a clareza. O Pro enxerga tudo.'
          : 'Você quer clareza. O Pro enxerga tudo.';
    case OnboardingGoal.save:
      return committed
          ? 'Você se comprometeu com o seu objetivo. O Pro encurta o caminho.'
          : 'Você tem um objetivo. O Pro encurta o caminho.';
    case OnboardingGoal.grow:
      return committed
          ? 'Você se comprometeu a render mais. O Pro mede cada passo.'
          : 'Você quer render mais. O Pro mede cada passo.';
  }
}
