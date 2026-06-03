import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../providers/app_lock_provider.dart';
import '../widgets/pin_pad.dart';

/// Two-step PIN setup: enter PIN → confirm PIN → save.
class SetupPinScreen extends ConsumerStatefulWidget {
  const SetupPinScreen({super.key});

  @override
  ConsumerState<SetupPinScreen> createState() => _SetupPinScreenState();
}

enum _SetupStep { enter, confirm }

class _SetupPinScreenState extends ConsumerState<SetupPinScreen> {
  _SetupStep _step = _SetupStep.enter;
  String _firstPin = '';
  String _pin = '';
  String? _error;

  void _onChanged(String pin) {
    setState(() {
      _pin = pin;
      _error = null;
    });
    if (pin.length == 4) _submit();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (_step == _SetupStep.enter) {
      setState(() {
        _firstPin = _pin;
        _pin = '';
        _step = _SetupStep.confirm;
      });
      return;
    }
    if (_pin != _firstPin) {
      setState(() {
        _pin = '';
        _firstPin = '';
        _step = _SetupStep.enter;
        _error = l10n.pinsDoNotMatch;
      });
      return;
    }
    await ref.read(appLockProvider.notifier).setPin(_pin);
    if (!mounted) return;
    Navigator.of(context).pop(true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.pinEnabled)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = _step == _SetupStep.enter
        ? l10n.createPinTitle
        : l10n.confirmPinTitle;
    final subtitle = _step == _SetupStep.enter
        ? l10n.createPinSubtitle
        : l10n.confirmPinSubtitle;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.appLockTitle)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 56,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 36),
                  PinPad(
                    value: _pin,
                    onChanged: _onChanged,
                    errorText: _error,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
