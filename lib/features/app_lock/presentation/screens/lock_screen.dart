import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/app_lock_provider.dart';
import '../widgets/pin_pad.dart';

/// Full-screen lock displayed above the app content when [appLockProvider]
/// reports `locked == true`. Blocks back navigation.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  String _pin = '';
  String? _error;
  bool _biometricAttempted = false;

  @override
  void initState() {
    super.initState();
    // Offer biometric prompt immediately after first frame if available.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybePromptBiometric());
  }

  Future<void> _maybePromptBiometric() async {
    if (_biometricAttempted) return;
    _biometricAttempted = true;
    final state = ref.read(appLockProvider);
    if (!state.biometricEnabled || !state.biometricAvailable) return;
    final l10n = AppLocalizations.of(context);
    final ok = await ref
        .read(appLockProvider.notifier)
        .authenticateWithBiometrics(l10n.unlockWithBiometricsReason);
    if (!mounted) return;
    if (ok) ref.read(appLockProvider.notifier).unlock();
  }

  Future<void> _onPinChanged(String pin) async {
    setState(() {
      _pin = pin;
      _error = null;
    });
    if (pin.length == 4) {
      final ok = await ref.read(appLockProvider.notifier).verifyPin(pin);
      if (!mounted) return;
      if (ok) {
        ref.read(appLockProvider.notifier).unlock();
      } else {
        final l10n = AppLocalizations.of(context);
        setState(() {
          _pin = '';
          _error = l10n.pinIncorrect;
        });
      }
    }
  }

  Future<void> _forgotPin() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.forgotPinTitle),
        content: Text(l10n.forgotPinMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.logout),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    // Sign out of Firebase AND reset the app lock.
    await ref.read(appLockProvider.notifier).disable();
    await ref.read(authNotifierProvider.notifier).signOut();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(appLockProvider);

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 24),
                    Icon(
                      Icons.lock_rounded,
                      size: 56,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      l10n.enterPinTitle,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.enterPinSubtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 36),
                    PinPad(
                      value: _pin,
                      onChanged: _onPinChanged,
                      errorText: _error,
                      onBiometric:
                          (state.biometricEnabled && state.biometricAvailable)
                              ? _maybePromptBiometric
                              : null,
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: _forgotPin,
                      child: Text(l10n.forgotPin),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
