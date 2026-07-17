import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_finance_app/core/providers/app_settings_provider.dart';
import 'package:my_finance_app/core/providers/effective_user_provider.dart';
import 'package:my_finance_app/features/auth/domain/entities/user_entity.dart';
import 'package:my_finance_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:my_finance_app/features/onboarding/domain/onboarding_profile.dart';
import 'package:my_finance_app/features/onboarding/presentation/providers/onboarding_provider.dart';

void main() {
  // ───────────────────────────────────────────────────────────────────────────
  // Plano modelo (50/20/30 sobre o ponto MÉDIO da faixa)
  // ───────────────────────────────────────────────────────────────────────────

  group('buildOnboardingPlan', () {
    test('com renda: grupos 50/20/30 sobre o ponto médio, múltiplos de 10',
        () {
      const answers = OnboardingAnswers(
        incomeBand: OnboardingIncomeBand.from2to5k, // ref 3500
        incomeAnswered: true,
      );
      final plan = buildOnboardingPlan(answers);

      expect(plan.incomeReference, 3500);
      expect(plan.groups.map((g) => g.percentage), [50, 20, 30]);
      expect(plan.groups[0].amount, 1750); // necessidades
      expect(plan.groups[1].amount, 700); // desejos
      expect(plan.groups[2].amount, 1050); // guardar

      // Cada categoria arredondada a múltiplos de R$ 10.
      for (final item in plan.items) {
        expect(item.amount! % 10, 0);
      }
      final moradia =
          plan.items.firstWhere((i) => i.categoryName == 'Moradia');
      expect(moradia.amount, 880); // 3500 × 25% = 875 → 880
    });

    test('sem renda: tudo em percentuais (amounts nulos)', () {
      const answers = OnboardingAnswers();
      final plan = buildOnboardingPlan(answers);
      expect(plan.incomeReference, isNull);
      expect(plan.groups.every((g) => g.amount == null), isTrue);
      expect(plan.items.every((i) => i.amount == null), isTrue);
    });

    test('leak destaca a categoria mapeada', () {
      const answers = OnboardingAnswers(leak: OnboardingLeak.subscriptions);
      final plan = buildOnboardingPlan(answers);
      final highlighted =
          plan.items.where((i) => i.highlighted).map((i) => i.categoryName);
      expect(highlighted, ['Lazer']);
      expect(plan.attentionOnWholePlan, isFalse);
    });

    test('leak_unknown: atenção no plano inteiro, nenhuma categoria', () {
      const answers = OnboardingAnswers(leak: OnboardingLeak.unknown);
      final plan = buildOnboardingPlan(answers);
      expect(plan.items.any((i) => i.highlighted), isFalse);
      expect(plan.attentionOnWholePlan, isTrue);
    });

    test('goal_debts renomeia o grupo de 30%', () {
      const answers = OnboardingAnswers(goal: OnboardingGoal.debts);
      final plan = buildOnboardingPlan(answers);
      expect(plan.groups[2].name, 'Quitar dívidas + reserva');
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Projeção (sempre com o PISO da faixa; 30% lidera só com sobra)
  // ───────────────────────────────────────────────────────────────────────────

  group('buildOnboardingProjection', () {
    test('usa o piso da faixa, nunca o ponto médio', () {
      const answers = OnboardingAnswers(
        incomeBand: OnboardingIncomeBand.from2to5k, // piso 2000
        monthEnd: OnboardingMonthEnd.surplus,
      );
      final p = buildOnboardingProjection(answers);
      expect(p.incomeFloor, 2000);
      expect(p.savings30, 7200); // 2000 × 0,30 × 12
      expect(p.savings10, 2400);
      expect(p.thirtyLeads, isTrue);
    });

    test('sem sobra (ou sem resposta) → 10% lidera', () {
      for (final monthEnd in [
        OnboardingMonthEnd.even,
        OnboardingMonthEnd.deficit,
        OnboardingMonthEnd.unknown,
        null,
      ]) {
        final p = buildOnboardingProjection(
            OnboardingAnswers(monthEnd: monthEnd));
        expect(p.thirtyLeads, isFalse, reason: 'monthEnd=$monthEnd');
      }
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Arquétipo
  // ───────────────────────────────────────────────────────────────────────────

  test('arquétipo deriva do objetivo; default = detetive', () {
    expect(
        const OnboardingAnswers(goal: OnboardingGoal.debts).archetype,
        OnboardingArchetype.viraJogo);
    expect(const OnboardingAnswers(goal: OnboardingGoal.save).archetype,
        OnboardingArchetype.sonho);
    expect(const OnboardingAnswers(goal: OnboardingGoal.grow).archetype,
        OnboardingArchetype.estrategista);
    expect(const OnboardingAnswers().archetype, OnboardingArchetype.detetive);
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Benefícios do paywall (sempre 4, sem duplicatas, injeções ordenadas)
  // ───────────────────────────────────────────────────────────────────────────

  group('buildPaywallBenefits', () {
    test('sempre 4 benefícios, sem duplicatas, em qualquer combinação', () {
      for (final goal in [...OnboardingGoal.values, null]) {
        for (final style in [...OnboardingControlStyle.values, null]) {
          for (final household in [...OnboardingHousehold.values, null]) {
            for (final method in [...OnboardingMethod.values, null]) {
              for (final leak in [...OnboardingLeak.values, null]) {
                final list = buildPaywallBenefits(OnboardingAnswers(
                  goal: goal,
                  controlStyle: style,
                  household: household,
                  currentMethod: method,
                  leak: leak,
                ));
                expect(list.length, 4);
                expect(list.map((b) => b.title).toSet().length, 4,
                    reason: 'dup em goal=$goal style=$style '
                        'household=$household method=$method leak=$leak');
              }
            }
          }
        }
      }
    });

    test('estilo orçamento sobe para a 1ª posição', () {
      final list = buildPaywallBenefits(const OnboardingAnswers(
        goal: OnboardingGoal.grow,
        controlStyle: OnboardingControlStyle.budget,
      ));
      expect(list.first.title.toLowerCase(), contains('orçamento'));
    });

    test('household business injeta Carteiras PF/PJ na posição 2', () {
      final list = buildPaywallBenefits(const OnboardingAnswers(
        goal: OnboardingGoal.debts,
        household: OnboardingHousehold.business,
      ));
      expect(list[1].title, contains('PF e PJ'));
    });

    test('quem vem de planilha vê importação em destaque', () {
      final list = buildPaywallBenefits(const OnboardingAnswers(
        goal: OnboardingGoal.debts,
        currentMethod: OnboardingMethod.sheet,
      ));
      expect(list.map((b) => b.title).any((t) => t.contains('OFX')), isTrue);
    });

    test('leak de assinaturas injeta detecção na última posição', () {
      final list = buildPaywallBenefits(const OnboardingAnswers(
        goal: OnboardingGoal.clarity,
        leak: OnboardingLeak.subscriptions,
      ));
      expect(list.last.title.toLowerCase(), contains('assinaturas'));
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Headlines do paywall
  // ───────────────────────────────────────────────────────────────────────────

  group('paywallHeadline', () {
    test('objetivo pulado + compromisso pulado → genérica', () {
      expect(
        paywallHeadline(const OnboardingAnswers(), committed: false),
        'Seu plano está pronto. O Pro coloca ele para trabalhar por você.',
      );
    });

    test('compromisso confirmado referencia o ato real', () {
      final h = paywallHeadline(
        const OnboardingAnswers(goal: OnboardingGoal.debts),
        committed: true,
      );
      expect(h, contains('se comprometeu'));
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Gate: needsOnboardingProvider (tri-state)
  // ───────────────────────────────────────────────────────────────────────────

  group('needsOnboardingProvider', () {
    const user = UserEntity(id: 'u1', email: 'u1@test.dev');

    ProviderContainer makeContainer({
      required Map<String, dynamic>? profile,
      Map<String, dynamic>? stash,
      FinancialLiteracyLevel literacy = FinancialLiteracyLevel.unset,
      bool profileLoading = false,
      bool loggedOut = false,
    }) {
      return ProviderContainer(overrides: [
        authStateProvider.overrideWith(
          (ref) => Stream.value(loggedOut ? null : user),
        ),
        userProfileStreamProvider.overrideWith(
          (ref) => profileLoading
              ? const Stream<Map<String, dynamic>?>.empty()
              : Stream.value(profile),
        ),
        onboardingStashProvider.overrideWith((ref) async => stash),
        appSettingsProvider.overrideWith(
          (ref) => AppSettingsNotifier(AppSettings(literacyLevel: literacy)),
        ),
      ]);
    }

    test('perfil carregando → null (não mostrar nada ainda)', () async {
      final c = makeContainer(profile: null, profileLoading: true);
      await c.read(authStateProvider.future);
      expect(c.read(needsOnboardingProvider), isNull);
      c.dispose();
    });

    test('usuário novo (sem perfil, literacy unset) → true', () async {
      final c = makeContainer(profile: null);
      await c.read(authStateProvider.future);
      await c.read(userProfileStreamProvider.future);
      await c.read(onboardingStashProvider.future);
      expect(c.read(needsOnboardingProvider), isTrue);
      c.dispose();
    });

    test(
        'pesquisa feita ANTES do cadastro (stash surveyDone) → true, '
        'mesmo com literacy já definida no aparelho', () async {
      final c = makeContainer(
        profile: null,
        stash: {'surveyDone': true, 'goal': 'goal_debts'},
        literacy: FinancialLiteracyLevel.beginner,
      );
      await c.read(authStateProvider.future);
      await c.read(userProfileStreamProvider.future);
      await c.read(onboardingStashProvider.future);
      expect(c.read(needsOnboardingProvider), isTrue);
      c.dispose();
    });

    test('stash parcial (sem surveyDone) não força continuação sozinho',
        () async {
      final c = makeContainer(
        profile: null,
        stash: {'surveyDone': false, 'goal': 'goal_debts'},
        literacy: FinancialLiteracyLevel.intermediate,
      );
      await c.read(authStateProvider.future);
      await c.read(userProfileStreamProvider.future);
      await c.read(onboardingStashProvider.future);
      expect(c.read(needsOnboardingProvider), isFalse);
      c.dispose();
    });

    test('conta que já completou ignora stash antigo → false', () async {
      final c = makeContainer(
        profile: {
          'onboardingProfile': {'completedAt': 1},
        },
        stash: {'surveyDone': true},
      );
      await c.read(authStateProvider.future);
      await c.read(userProfileStreamProvider.future);
      await c.read(onboardingStashProvider.future);
      expect(c.read(needsOnboardingProvider), isFalse);
      c.dispose();
    });

    test('usuário antigo neste aparelho (literacy definida) → false',
        () async {
      final c = makeContainer(
        profile: null,
        literacy: FinancialLiteracyLevel.intermediate,
      );
      await c.read(authStateProvider.future);
      await c.read(userProfileStreamProvider.future);
      await c.read(onboardingStashProvider.future);
      expect(c.read(needsOnboardingProvider), isFalse);
      c.dispose();
    });

    test('fluxo completado → false, mesmo com literacy unset', () async {
      final c = makeContainer(profile: {
        'onboardingProfile': {'completedAt': 1, 'startedAt': 1},
      });
      await c.read(authStateProvider.future);
      await c.read(userProfileStreamProvider.future);
      await c.read(onboardingStashProvider.future);
      expect(c.read(needsOnboardingProvider), isFalse);
      c.dispose();
    });

    test('fluxo adiado ("Agora não") → false', () async {
      final c = makeContainer(profile: {
        'onboardingProfile': {'deferredAt': 1},
      });
      await c.read(authStateProvider.future);
      await c.read(userProfileStreamProvider.future);
      await c.read(onboardingStashProvider.future);
      expect(c.read(needsOnboardingProvider), isFalse);
      c.dispose();
    });

    test('fluxo abandonado no meio → true (retomar), mesmo com literacy já '
        'definida no meio do fluxo', () async {
      final c = makeContainer(
        profile: {
          'onboardingProfile': {'startedAt': 1, 'lastStepId': 'q_leak'},
        },
        literacy: FinancialLiteracyLevel.beginner,
      );
      await c.read(authStateProvider.future);
      await c.read(userProfileStreamProvider.future);
      await c.read(onboardingStashProvider.future);
      expect(c.read(needsOnboardingProvider), isTrue);
      c.dispose();
    });

    test('deslogado → false', () async {
      final c = makeContainer(profile: null, loggedOut: true);
      await c.read(authStateProvider.future);
      expect(c.read(needsOnboardingProvider), isFalse);
      c.dispose();
    });
  });
}
