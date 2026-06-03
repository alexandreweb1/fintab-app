import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/providers/app_settings_provider.dart';

/// Modal não-fechável que pergunta o nível de familiaridade do usuário com
/// finanças. Aparece uma única vez (na 1ª abertura após login/cadastro)
/// quando [AppSettings.literacyLevel] é [FinancialLiteracyLevel.unset].
class LiteracyOnboardingDialog extends ConsumerStatefulWidget {
  const LiteracyOnboardingDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const LiteracyOnboardingDialog(),
    );
  }

  @override
  ConsumerState<LiteracyOnboardingDialog> createState() =>
      _LiteracyOnboardingDialogState();
}

class _LiteracyOnboardingDialogState
    extends ConsumerState<LiteracyOnboardingDialog> {
  FinancialLiteracyLevel? _selected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      child: Dialog(
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.school_outlined,
                  size: 40,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.literacyOnboardingTitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.literacyOnboardingSubtitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                _LevelOption(
                  level: FinancialLiteracyLevel.beginner,
                  icon: Icons.emoji_objects_outlined,
                  title: l10n.literacyLevelBeginner,
                  description: l10n.literacyLevelBeginnerDesc,
                  selected: _selected == FinancialLiteracyLevel.beginner,
                  onTap: () => setState(
                      () => _selected = FinancialLiteracyLevel.beginner),
                ),
                const SizedBox(height: 10),
                _LevelOption(
                  level: FinancialLiteracyLevel.intermediate,
                  icon: Icons.trending_up_rounded,
                  title: l10n.literacyLevelIntermediate,
                  description: l10n.literacyLevelIntermediateDesc,
                  selected:
                      _selected == FinancialLiteracyLevel.intermediate,
                  onTap: () => setState(() =>
                      _selected = FinancialLiteracyLevel.intermediate),
                ),
                const SizedBox(height: 10),
                _LevelOption(
                  level: FinancialLiteracyLevel.advanced,
                  icon: Icons.workspace_premium_outlined,
                  title: l10n.literacyLevelAdvanced,
                  description: l10n.literacyLevelAdvancedDesc,
                  selected: _selected == FinancialLiteracyLevel.advanced,
                  onTap: () => setState(
                      () => _selected = FinancialLiteracyLevel.advanced),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _selected == null
                      ? null
                      : () async {
                          await ref
                              .read(appSettingsProvider.notifier)
                              .setLiteracyLevel(_selected!);
                          if (!context.mounted) return;
                          Navigator.of(context).pop();
                        },
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: Text(l10n.continueAction),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LevelOption extends StatelessWidget {
  final FinancialLiteracyLevel level;
  final IconData icon;
  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  const _LevelOption({
    required this.level,
    required this.icon,
    required this.title,
    required this.description,
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
            color: selected
                ? primary
                : theme.colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.3,
                    ),
                  ),
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
      ),
    );
  }
}
