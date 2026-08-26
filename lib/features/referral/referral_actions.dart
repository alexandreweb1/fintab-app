import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/services/analytics_service.dart';
import '../../core/services/referral_service.dart';
import '../../core/utils/animated_dialog.dart';
import '../../core/utils/platform_store.dart';
import '../auth/presentation/providers/auth_provider.dart';

/// Ações de indicação compartilhadas entre Configurações, Home, paywall e
/// pós-compra. A lógica de código/atribuição vive em [ReferralService]; a
/// recompensa (1 mês de Pro pro indicador) é concedida server-side pela
/// Cloud Function `grantReferralReward` quando o convidado ativa.
///
/// [origin] identifica o ponto de entrada no Analytics
/// (settings | home_card | paywall | post_purchase | onboarding_paywall).

/// Abre o share sheet nativo com a mensagem de convite + código.
Future<void> shareReferralInvite(WidgetRef ref, {required String origin}) async {
  final uid = ref.read(authStateProvider).value?.id;
  var codeLine = '';
  if (uid != null) {
    final code = await ReferralService.instance.ensureReferralCode(uid);
    codeLine = '\n\nUse meu código de indicação no primeiro acesso '
        '(ou em Configurações → Compartilhamento): $code';
  }
  await Share.share(
    'Tô usando o Fintab pra organizar minhas finanças e queria te convidar '
    'a usar também. Baixe aqui: $storeUrl$codeLine',
    subject: 'Conheça o Fintab',
  );
  AnalyticsService.instance.logEvent('invite_shared', {'origin': origin});
}

/// Dialog "Tenho um código de indicação". Loga `referral_redeemed` no sucesso.
Future<void> showRedeemReferralDialog(
  BuildContext context,
  WidgetRef ref, {
  required String origin,
}) async {
  final controller = TextEditingController();
  final code = await showAnimatedDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Tenho um código de indicação'),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.characters,
        decoration: const InputDecoration(
          labelText: 'Código de indicação',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(controller.text),
          child: const Text('Resgatar'),
        ),
      ],
    ),
  );
  if (code == null || code.trim().isEmpty) return;
  final uid = ref.read(authStateProvider).value?.id;
  if (uid == null) return;
  final error = await ReferralService.instance.redeemCode(uid, code);
  if (error == null) {
    AnalyticsService.instance.logEvent('referral_redeemed', {'origin': origin});
  }
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(error ??
          'Código aplicado! Ao usar o app, quem te indicou ganha 1 mês de '
              'Pro grátis.'),
      backgroundColor: error != null ? Colors.red.shade700 : null,
    ),
  );
}

/// Agradecimento pós-compra com o convite pronto para compartilhar.
/// Chamado quando `purchaseSuccess` vira true na ProScreen.
Future<void> showPostPurchaseReferralDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  AnalyticsService.instance
      .logEvent('referral_prompt_shown', {'origin': 'post_purchase'});
  await showAnimatedDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.celebration_outlined, size: 40),
      title: const Text('Bem-vindo(a) ao Pro!'),
      content: const Text(
        'Obrigado por apoiar o Fintab. Que tal ganhar seu próximo mês de '
        'graça? Indique um amigo: quando ele começar a usar o app, você '
        'ganha 1 mês de Pro.',
        textAlign: TextAlign.center,
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Agora não'),
        ),
        FilledButton.icon(
          onPressed: () {
            Navigator.of(ctx).pop();
            shareReferralInvite(ref, origin: 'post_purchase');
          },
          icon: const Icon(Icons.ios_share, size: 18),
          label: const Text('Convidar amigos'),
        ),
      ],
    ),
  );
}
