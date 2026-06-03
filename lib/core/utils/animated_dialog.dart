import 'package:flutter/material.dart';

/// Shows a dialog with a smooth scale + fade entrance animation.
///
/// Drop-in replacement for [showDialog] across the app.
Future<T?> showAnimatedDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  bool useRootNavigator = true,
}) {
  final theme = Theme.of(context);
  final mediaQuery = MediaQuery.of(context);

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: barrierColor ?? Colors.black54,
    transitionDuration: const Duration(milliseconds: 240),
    useRootNavigator: useRootNavigator,
    pageBuilder: (ctx, anim, secAnim) => MediaQuery(
      data: mediaQuery,
      child: Theme(
        data: theme,
        child: builder(ctx),
      ),
    ),
    transitionBuilder: (ctx, anim, secAnim, child) {
      final fade = CurvedAnimation(parent: anim, curve: Curves.easeOut);
      final scale = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: fade,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.90, end: 1.0).animate(scale),
          child: child,
        ),
      );
    },
  );
}
