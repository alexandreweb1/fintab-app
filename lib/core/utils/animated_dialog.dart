import 'package:flutter/material.dart';

/// Shows a dialog with a smooth entrance animation.
///
/// Drop-in replacement for [showDialog] across the app. When [sourceRect] (the
/// on-screen rect of the widget that triggered it, in global coordinates) is
/// provided, the dialog appears to grow OUT of that widget — a lightweight
/// container-transform used by the "+" button. Without it, it falls back to the
/// centered scale + fade used everywhere else.
Future<T?> showAnimatedDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  bool useRootNavigator = true,
  Rect? sourceRect,
}) {
  final theme = Theme.of(context);
  final mediaQuery = MediaQuery.of(context);
  final screenSize = mediaQuery.size;

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: barrierColor ?? Colors.black54,
    transitionDuration: const Duration(milliseconds: 300),
    useRootNavigator: useRootNavigator,
    pageBuilder: (ctx, anim, secAnim) => MediaQuery(
      data: mediaQuery,
      child: Theme(
        data: theme,
        child: builder(ctx),
      ),
    ),
    transitionBuilder: (ctx, anim, secAnim, child) {
      final curved = CurvedAnimation(
        parent: anim,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );

      if (sourceRect == null) {
        // Centered scale + fade (default across the app).
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.90, end: 1.0).animate(curved),
            child: child,
          ),
        );
      }

      // Grow from the trigger: translate from the button's center toward the
      // screen center (where dialogs sit) while scaling up from a small seed.
      final screenCenter = Offset(screenSize.width / 2, screenSize.height / 2);
      final delta = sourceRect.center - screenCenter;
      return AnimatedBuilder(
        animation: curved,
        builder: (_, animatedChild) {
          final t = curved.value;
          final offset = delta * (1 - t);
          final scale = 0.35 + 0.65 * t;
          return Opacity(
            opacity: (t * 1.6).clamp(0.0, 1.0),
            child: Transform.translate(
              offset: offset,
              child: Transform.scale(scale: scale, child: animatedChild),
            ),
          );
        },
        child: child,
      );
    },
  );
}
