import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/subscription_provider.dart';
import '../screens/pro_screen.dart';

const _kGreen = Color(0xFF00D887);

/// Envolve qualquer widget com um gate de assinatura Pro.
/// - Se o usuário é Pro: exibe o [child] normalmente.
/// - Se não é Pro: exibe o [child] com opacidade + overlay de bloqueio.
class ProGateWidget extends ConsumerWidget {
  final Widget child;
  final String featureName;
  final String featureDescription;
  final IconData featureIcon;

  const ProGateWidget({
    super.key,
    required this.child,
    required this.featureName,
    required this.featureDescription,
    required this.featureIcon,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(isSubscriptionLoadingProvider);

    // Enquanto o Firestore ainda está respondendo, bloqueia interação
    // mas não exibe o gate de compra (evita falso bloqueio para usuários Pro).
    if (isLoading) {
      return Stack(
        alignment: Alignment.center,
        children: [
          Opacity(opacity: 0.4, child: IgnorePointer(child: child)),
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ],
      );
    }

    final isPro = ref.watch(isProProvider);

    if (isPro) return child;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Conteúdo bloqueado — visualmente opaco e não interativo
        Opacity(
          opacity: 0.3,
          child: IgnorePointer(child: child),
        ),
        // Overlay de bloqueio
        GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ProScreen()),
          ),
          child: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _kGreen.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_rounded,
                      size: 24, color: _kGreen),
                ),
                const SizedBox(height: 10),
                Text(
                  featureName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  featureDescription,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ProScreen()),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: _kGreen,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.workspace_premium_rounded, size: 18),
                  label: const Text('Seja Pro',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Mostra um bottom sheet de gate leve — usado quando o gate é numa ação pontual
/// (ex: selecionar item de dropdown).
/// Não exibe nada se o status de assinatura ainda está carregando.
void showProGateBottomSheet(
  BuildContext context, {
  required String featureName,
  required String featureDescription,
  required IconData featureIcon,
}) {
  // Evita exibir o gate de compra para usuários Pro cujo status
  // ainda não chegou do Firestore.
  final container = ProviderScope.containerOf(context);
  if (container.read(isSubscriptionLoadingProvider)) return;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _ProGateSheet(
      featureName: featureName,
      featureDescription: featureDescription,
      featureIcon: featureIcon,
    ),
  );
}

class _ProGateSheet extends StatelessWidget {
  final String featureName;
  final String featureDescription;
  final IconData featureIcon;

  const _ProGateSheet({
    required this.featureName,
    required this.featureDescription,
    required this.featureIcon,
  });

  @override
  Widget build(BuildContext context) {
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
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _kGreen.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(featureIcon, size: 32, color: _kGreen),
          ),
          const SizedBox(height: 16),
          Text(
            featureName,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            featureDescription,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Disponível no plano Pro',
            style: TextStyle(
              color: _kGreen,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProScreen()),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: _kGreen,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.workspace_premium_rounded),
              label: const Text(
                'Ver planos Pro',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Agora não',
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
