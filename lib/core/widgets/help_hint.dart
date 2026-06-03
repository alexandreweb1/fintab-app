import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/app_settings_provider.dart';

/// Ícone "?" sutil que abre um balão (popover) explicando um conceito.
///
/// A visibilidade depende do nível de familiaridade financeira do usuário
/// (definido no onboarding):
///   • beginner     → sempre visível
///   • intermediate → só visível quando [showForIntermediate] = true
///   • advanced     → sempre oculto
///   • unset        → tratado como beginner (até o usuário responder)
class HelpHint extends ConsumerWidget {
  final String title;
  final String body;

  /// Se `true`, mostra também para usuários intermediários. Reserve para
  /// conceitos não-triviais (Saúde Financeira, Tags, etc.).
  final bool showForIntermediate;

  /// Tamanho do ícone "?" (default 16, bem discreto).
  final double size;

  /// Cor do ícone. Se `null`, usa onSurfaceVariant do tema (sutil).
  final Color? color;

  const HelpHint({
    super.key,
    required this.title,
    required this.body,
    this.showForIntermediate = false,
    this.size = 16,
    this.color,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final level = ref.watch(
      appSettingsProvider.select((s) => s.literacyLevel),
    );

    final visible = switch (level) {
      FinancialLiteracyLevel.beginner => true,
      FinancialLiteracyLevel.unset => true,
      FinancialLiteracyLevel.intermediate => showForIntermediate,
      FinancialLiteracyLevel.advanced => false,
    };

    if (!visible) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final iconColor = color ?? theme.colorScheme.onSurfaceVariant;
    final l10n = AppLocalizations.of(context);

    return Semantics(
      button: true,
      label: l10n.helpHintLabel,
      child: _HelpHintAnchor(
        title: title,
        body: body,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Icon(
            Icons.help_outline_rounded,
            size: size,
            color: iconColor.withValues(alpha: 0.75),
          ),
        ),
      ),
    );
  }
}

/// Mostra o balão posicionado próximo ao ícone usando uma OverlayEntry.
class _HelpHintAnchor extends StatefulWidget {
  final String title;
  final String body;
  final Widget child;

  const _HelpHintAnchor({
    required this.title,
    required this.body,
    required this.child,
  });

  @override
  State<_HelpHintAnchor> createState() => _HelpHintAnchorState();
}

class _HelpHintAnchorState extends State<_HelpHintAnchor> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;

  void _toggle() {
    if (_entry != null) {
      _close();
    } else {
      _open();
    }
  }

  void _open() {
    final overlay = Overlay.of(context, rootOverlay: true);
    _entry = OverlayEntry(builder: _buildOverlay);
    overlay.insert(_entry!);
    setState(() {});
  }

  void _close() {
    _entry?.remove();
    _entry = null;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _entry?.remove();
    _entry = null;
    super.dispose();
  }

  Widget _buildOverlay(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final maxBalloonWidth =
        (screenWidth - 24).clamp(220.0, 320.0);

    return Stack(
      children: [
        // Camada transparente para fechar ao tocar fora.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _close,
            child: const SizedBox.expand(),
          ),
        ),
        CompositedTransformFollower(
          link: _link,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomCenter,
          followerAnchor: Alignment.topCenter,
          offset: const Offset(0, 6),
          child: Material(
            color: Colors.transparent,
            child: _HelpBalloon(
              title: widget.title,
              body: widget.body,
              maxWidth: maxBalloonWidth,
              onClose: _close,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: InkResponse(
        onTap: _toggle,
        radius: 16,
        containedInkWell: true,
        customBorder: const CircleBorder(),
        child: widget.child,
      ),
    );
  }
}

class _HelpBalloon extends StatelessWidget {
  final String title;
  final String body;
  final double maxWidth;
  final VoidCallback onClose;

  const _HelpBalloon({
    required this.title,
    required this.body,
    required this.maxWidth,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(
          color: isDark
              ? theme.colorScheme.surfaceContainerHigh
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outlineVariant,
          ),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lightbulb_outline_rounded,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                InkResponse(
                  onTap: onClose,
                  radius: 14,
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: theme.textTheme.bodySmall?.copyWith(
                height: 1.35,
                color: theme.colorScheme.onSurface
                    .withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onClose,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  minimumSize: const Size(0, 32),
                ),
                child: Text(l10n.gotIt),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
