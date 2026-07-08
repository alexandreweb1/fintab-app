import 'package:flutter/material.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/services/review_prompt_service.dart';
import '../../../../core/utils/animated_dialog.dart';
import '../../../../core/utils/platform_store.dart';

/// "Está gostando do Fintab?" — store-review nudge shown on app open (see
/// [ReviewPromptService] for the when/until rules).
Future<void> showReviewPromptDialog(BuildContext context) {
  return showAnimatedDialog<void>(
    context: context,
    builder: (_) => const _ReviewPromptDialog(),
  );
}

class _ReviewPromptDialog extends StatelessWidget {
  const _ReviewPromptDialog();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    const amber = Color(0xFFFFB300);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: amber.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.star_rounded, size: 34, color: amber),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.reviewPromptTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      content: Text(
        // storeName is platform-aware ("App Store" / "Google Play") — the iOS
        // binary must not mention Google Play (Guideline 2.3.10).
        l10n.reviewPromptBody(storeName),
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              icon: const Icon(Icons.star_rounded, size: 18),
              label: Text(l10n.reviewPromptRate),
              onPressed: () {
                Navigator.of(context).pop();
                ReviewPromptService.instance.rate();
              },
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                ReviewPromptService.instance.markAlreadyRated();
              },
              child: Text(l10n.reviewPromptAlreadyRated),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                ReviewPromptService.instance.logDismissed();
              },
              child: Text(
                l10n.reviewPromptLater,
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
