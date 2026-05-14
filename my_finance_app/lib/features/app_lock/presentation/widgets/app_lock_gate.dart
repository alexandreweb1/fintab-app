import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_lock_provider.dart';
import '../screens/lock_screen.dart';

/// Renders [LockScreen] on top of [child] while locked.
///
/// O bloqueio só ocorre na inicialização do app (cold start, definido em
/// [AppLockNotifier._refresh]). Voltar de outro aplicativo NÃO re-tranca,
/// para não pedir biometria a cada alternância de app.
class AppLockGate extends ConsumerWidget {
  final Widget child;
  const AppLockGate({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locked = ref.watch(appLockProvider.select((s) => s.locked));
    return Stack(
      children: [
        child,
        if (locked) const LockScreen(),
      ],
    );
  }
}
