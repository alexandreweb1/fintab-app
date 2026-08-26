import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/analytics_service.dart';
import '../transactions/presentation/providers/transactions_provider.dart';
import 'referral_actions.dart';

const _kDismissedKey = 'referral_home_card_dismissed';

/// Telemetria é best-effort: nunca pode derrubar a interação (e em testes de
/// widget o Firebase nem está inicializado).
void _logEvent(String name, [Map<String, Object>? params]) {
  try {
    AnalyticsService.instance.logEvent(name, params);
  } catch (_) {}
}

/// Se o usuário já dispensou o card de indicação da Home (persistido).
final referralCardDismissedProvider =
    StateNotifierProvider<_DismissedNotifier, bool?>(
  (ref) => _DismissedNotifier(),
);

class _DismissedNotifier extends StateNotifier<bool?> {
  // null = ainda carregando das prefs; evita o card piscar no primeiro frame.
  _DismissedNotifier() : super(null) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_kDismissedKey) ?? false;
  }

  Future<void> dismiss() async {
    state = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDismissedKey, true);
  }
}

/// Card "indique e ganhe 1 mês de Pro" da Home.
///
/// Descoberta do sistema de indicação (F0.9): só aparece para quem já criou
/// hábito (≥5 transações) e some para sempre no X. Não é gate de Pro — todo
/// mundo pode indicar.
class ReferralHomeCard extends ConsumerWidget {
  const ReferralHomeCard({super.key});

  static const _minTransactions = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dismissed = ref.watch(referralCardDismissedProvider);
    if (dismissed != false) return const SizedBox.shrink();

    final txCount =
        ref.watch(transactionsStreamProvider).value?.length ?? 0;
    if (txCount < _minTransactions) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            Icon(Icons.card_giftcard_outlined,
                color: colorScheme.primary, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Indique e ganhe 1 mês de Pro',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Convide um amigo; quando ele começar a usar o app, '
                    'seu mês grátis é ativado sozinho.',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonalIcon(
                    onPressed: () {
                      _logEvent('referral_card_cta', {'origin': 'home_card'});
                      shareReferralInvite(ref, origin: 'home_card');
                    },
                    icon: const Icon(Icons.ios_share, size: 16),
                    label: const Text('Convidar'),
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Não mostrar de novo',
              icon: Icon(Icons.close,
                  size: 18, color: colorScheme.onSurfaceVariant),
              onPressed: () {
                _logEvent('referral_card_dismissed');
                ref.read(referralCardDismissedProvider.notifier).dismiss();
              },
            ),
          ],
        ),
      ),
    );
  }
}
