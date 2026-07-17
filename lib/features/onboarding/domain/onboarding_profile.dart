import '../../budget/domain/ideal_budget.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Respostas da pesquisa de onboarding — ids estáveis gravados em
// users/{uid}.onboardingProfile (NUNCA em eventos de analytics).
// ─────────────────────────────────────────────────────────────────────────────

enum OnboardingGoal {
  debts('goal_debts'),
  clarity('goal_clarity'),
  save('goal_save'),
  grow('goal_grow');

  final String id;
  const OnboardingGoal(this.id);

  static OnboardingGoal? fromId(String? id) {
    for (final v in values) {
      if (v.id == id) return v;
    }
    return null;
  }
}

enum OnboardingMethod {
  none('method_none'),
  paper('method_paper'),
  sheet('method_sheet'),
  app('method_app'),
  bank('method_bank');

  final String id;
  const OnboardingMethod(this.id);

  static OnboardingMethod? fromId(String? id) {
    for (final v in values) {
      if (v.id == id) return v;
    }
    return null;
  }
}

enum OnboardingControlStyle {
  budget('style_budget'),
  track('style_track'),
  goals('style_goals'),
  reminders('style_reminders');

  final String id;
  const OnboardingControlStyle(this.id);

  static OnboardingControlStyle? fromId(String? id) {
    for (final v in values) {
      if (v.id == id) return v;
    }
    return null;
  }
}

enum OnboardingMonthEnd {
  surplus('monthend_surplus'),
  even('monthend_even'),
  deficit('monthend_deficit'),
  unknown('monthend_unknown');

  final String id;
  const OnboardingMonthEnd(this.id);

  static OnboardingMonthEnd? fromId(String? id) {
    for (final v in values) {
      if (v.id == id) return v;
    }
    return null;
  }
}

enum OnboardingLeak {
  foodDelivery('leak_food_delivery'),
  subscriptions('leak_subscriptions'),
  impulse('leak_impulse'),
  fixed('leak_fixed'),
  unknown('leak_unknown');

  final String id;
  const OnboardingLeak(this.id);

  static OnboardingLeak? fromId(String? id) {
    for (final v in values) {
      if (v.id == id) return v;
    }
    return null;
  }
}

enum OnboardingHousehold {
  solo('household_solo'),
  partner('household_partner'),
  family('household_family'),
  business('household_business');

  final String id;
  const OnboardingHousehold(this.id);

  static OnboardingHousehold? fromId(String? id) {
    for (final v in values) {
      if (v.id == id) return v;
    }
    return null;
  }
}

/// Faixas de renda. [reference] = ponto médio usado nos valores do plano;
/// [floor] = piso da faixa, usado SÓ na projeção para nunca inflar promessa.
enum OnboardingIncomeBand {
  upTo2k('income_upto2k', reference: 1500, floor: 1500),
  from2to5k('income_2to5k', reference: 3500, floor: 2000),
  from5to10k('income_5to10k', reference: 7500, floor: 5000),
  over10k('income_over10k', reference: 12000, floor: 10000);

  final String id;
  final double reference;
  final double floor;
  const OnboardingIncomeBand(this.id,
      {required this.reference, required this.floor});

  static OnboardingIncomeBand? fromId(String? id) {
    for (final v in values) {
      if (v.id == id) return v;
    }
    return null;
  }
}

enum OnboardingArchetype {
  viraJogo('vira_jogo'),
  detetive('detetive'),
  sonho('sonho'),
  estrategista('estrategista');

  final String id;
  const OnboardingArchetype(this.id);
}

// ─────────────────────────────────────────────────────────────────────────────
// Estado das respostas durante o fluxo
// ─────────────────────────────────────────────────────────────────────────────

class OnboardingAnswers {
  final OnboardingGoal? goal;
  final OnboardingMethod? currentMethod;
  final OnboardingControlStyle? controlStyle;

  /// Espelha [FinancialLiteracyLevel] (beginner/intermediate/advanced).
  /// Guardado como string para não acoplar o domain ao AppSettings.
  final String? literacyLevel;
  final OnboardingMonthEnd? monthEnd;
  final OnboardingLeak? leak;
  final OnboardingHousehold? household;
  final OnboardingIncomeBand? incomeBand;

  /// True quando o usuário respondeu a pergunta de renda (mesmo escolhendo
  /// "Prefiro não informar", caso em que [incomeBand] fica null).
  final bool incomeAnswered;

  const OnboardingAnswers({
    this.goal,
    this.currentMethod,
    this.controlStyle,
    this.literacyLevel,
    this.monthEnd,
    this.leak,
    this.household,
    this.incomeBand,
    this.incomeAnswered = false,
  });

  /// Os flags `clearX` permitem retratar uma resposta ("Pular" depois de já
  /// ter respondido): `copyWith(campo: null)` sozinho seria no-op.
  OnboardingAnswers copyWith({
    OnboardingGoal? goal,
    OnboardingMethod? currentMethod,
    bool clearCurrentMethod = false,
    OnboardingControlStyle? controlStyle,
    String? literacyLevel,
    OnboardingMonthEnd? monthEnd,
    bool clearMonthEnd = false,
    OnboardingLeak? leak,
    bool clearLeak = false,
    OnboardingHousehold? household,
    bool clearHousehold = false,
    OnboardingIncomeBand? incomeBand,
    bool clearIncomeBand = false,
    bool? incomeAnswered,
  }) =>
      OnboardingAnswers(
        goal: goal ?? this.goal,
        currentMethod: clearCurrentMethod
            ? null
            : (currentMethod ?? this.currentMethod),
        controlStyle: controlStyle ?? this.controlStyle,
        literacyLevel: literacyLevel ?? this.literacyLevel,
        monthEnd: clearMonthEnd ? null : (monthEnd ?? this.monthEnd),
        leak: clearLeak ? null : (leak ?? this.leak),
        household: clearHousehold ? null : (household ?? this.household),
        incomeBand:
            clearIncomeBand ? null : (incomeBand ?? this.incomeBand),
        incomeAnswered: incomeAnswered ?? this.incomeAnswered,
      );

  /// Arquétipo derivado do objetivo (default: Detetive, o mesmo de
  /// `goal_clarity`, que também é o default de quem pula a pergunta).
  OnboardingArchetype get archetype {
    switch (goal) {
      case OnboardingGoal.debts:
        return OnboardingArchetype.viraJogo;
      case OnboardingGoal.save:
        return OnboardingArchetype.sonho;
      case OnboardingGoal.grow:
        return OnboardingArchetype.estrategista;
      case OnboardingGoal.clarity:
      case null:
        return OnboardingArchetype.detetive;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Plano modelo — deriva do motor existente (kIdealBudgetTemplate: 50/20/30)
// ─────────────────────────────────────────────────────────────────────────────

class OnboardingPlanGroup {
  final String name;
  final double percentage;

  /// Null quando o usuário não informou a renda (plano em percentuais).
  final double? amount;

  const OnboardingPlanGroup({
    required this.name,
    required this.percentage,
    this.amount,
  });
}

class OnboardingPlanItem {
  final String categoryName;
  final String group;
  final double percentage;
  final double? amount;

  /// "Seu ponto de atenção" — categoria mapeada a partir de `q_leak`.
  final bool highlighted;

  const OnboardingPlanItem({
    required this.categoryName,
    required this.group,
    required this.percentage,
    this.amount,
    this.highlighted = false,
  });
}

class OnboardingPlan {
  final List<OnboardingPlanGroup> groups;
  final List<OnboardingPlanItem> items;

  /// Renda de referência usada nos valores (ponto médio da faixa), ou null.
  final double? incomeReference;

  /// True quando o ponto de atenção é o plano inteiro (`leak_unknown`).
  final bool attentionOnWholePlan;

  const OnboardingPlan({
    required this.groups,
    required this.items,
    this.incomeReference,
    this.attentionOnWholePlan = false,
  });
}

/// Categoria destacada pelo "vazamento" declarado (chip âmbar no plano).
String? leakCategoryName(OnboardingLeak? leak) {
  switch (leak) {
    case OnboardingLeak.foodDelivery:
      return 'Alimentação';
    case OnboardingLeak.subscriptions:
      return 'Lazer';
    case OnboardingLeak.impulse:
      return 'Vestuário';
    case OnboardingLeak.fixed:
      return 'Moradia';
    case OnboardingLeak.unknown:
    case null:
      return null;
  }
}

/// Monta o plano modelo a partir do template 50/30/20 adaptado
/// (50% necessidades · 20% desejos · 30% para guardar).
/// Valores arredondados a múltiplos de R$ 10.
OnboardingPlan buildOnboardingPlan(OnboardingAnswers answers) {
  final income = answers.incomeBand?.reference;
  final highlight = leakCategoryName(answers.leak);

  double? amountFor(double percentage) {
    if (income == null) return null;
    return ((income * percentage / 100.0) / 10.0).round() * 10.0;
  }

  final saveLabel = answers.goal == OnboardingGoal.debts
      ? 'Quitar dívidas + reserva'
      : 'Livre para guardar';

  final needsPct = kIdealBudgetTemplate
      .where((i) => i.group == 'Necessidades')
      .fold(0.0, (s, i) => s + i.percentage);
  final wantsPct = kIdealBudgetTemplate
      .where((i) => i.group == 'Desejos')
      .fold(0.0, (s, i) => s + i.percentage);

  return OnboardingPlan(
    incomeReference: income,
    attentionOnWholePlan: answers.leak == OnboardingLeak.unknown,
    groups: [
      OnboardingPlanGroup(
        name: 'Necessidades',
        percentage: needsPct,
        amount: amountFor(needsPct),
      ),
      OnboardingPlanGroup(
        name: 'Desejos',
        percentage: wantsPct,
        amount: amountFor(wantsPct),
      ),
      OnboardingPlanGroup(
        name: saveLabel,
        percentage: kIdealSavingsPercent,
        amount: amountFor(kIdealSavingsPercent),
      ),
    ],
    items: [
      for (final item in kIdealBudgetTemplate)
        OnboardingPlanItem(
          categoryName: item.categoryName,
          group: item.group,
          percentage: item.percentage,
          amount: amountFor(item.percentage),
          highlighted: item.categoryName == highlight,
        ),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Projeção de 12 meses — só aritmética, sempre com o PISO da faixa
// ─────────────────────────────────────────────────────────────────────────────

class OnboardingProjection {
  /// Piso da faixa de renda usado na conta, ou null (sem renda → texto em %).
  final double? incomeFloor;
  final double? savings30;
  final double? savings10;

  /// True quando a projeção de 30% lidera (mês fecha com sobra).
  final bool thirtyLeads;

  const OnboardingProjection({
    this.incomeFloor,
    this.savings30,
    this.savings10,
    required this.thirtyLeads,
  });
}

OnboardingProjection buildOnboardingProjection(OnboardingAnswers answers) {
  final floor = answers.incomeBand?.floor;
  return OnboardingProjection(
    incomeFloor: floor,
    savings30: floor == null ? null : floor * 0.30 * 12,
    savings10: floor == null ? null : floor * 0.10 * 12,
    thirtyLeads: answers.monthEnd == OnboardingMonthEnd.surplus,
  );
}
