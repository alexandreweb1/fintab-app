import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Numeric keypad + masked PIN indicator. Caller controls the current value.
class PinPad extends StatelessWidget {
  final String value;
  final int length;
  final ValueChanged<String> onChanged;
  final VoidCallback? onBiometric;
  final String? errorText;

  const PinPad({
    super.key,
    required this.value,
    required this.onChanged,
    this.length = 4,
    this.onBiometric,
    this.errorText,
  });

  void _append(String digit) {
    if (value.length >= length) return;
    HapticFeedback.selectionClick();
    onChanged(value + digit);
  }

  void _backspace() {
    if (value.isEmpty) return;
    HapticFeedback.selectionClick();
    onChanged(value.substring(0, value.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PinDots(filled: value.length, total: length, error: errorText != null),
        const SizedBox(height: 12),
        SizedBox(
          height: 20,
          child: errorText == null
              ? const SizedBox.shrink()
              : Text(
                  errorText!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 13,
                  ),
                ),
        ),
        const SizedBox(height: 8),
        _Keypad(
          onDigit: _append,
          onBackspace: _backspace,
          onBiometric: onBiometric,
        ),
      ],
    );
  }
}

class _PinDots extends StatelessWidget {
  final int filled;
  final int total;
  final bool error;
  const _PinDots({
    required this.filled,
    required this.total,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final errorColor = Theme.of(context).colorScheme.error;
    final outline = Theme.of(context).colorScheme.outlineVariant;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final active = i < filled;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: error
                ? errorColor
                : active
                    ? primary
                    : outline,
          ),
        );
      }),
    );
  }
}

class _Keypad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback? onBiometric;

  const _Keypad({
    required this.onDigit,
    required this.onBackspace,
    this.onBiometric,
  });

  @override
  Widget build(BuildContext context) {
    Widget digit(String d) => _KeypadButton(
          label: d,
          onTap: () => onDigit(d),
        );
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        children: [
          digit('1'), digit('2'), digit('3'),
          digit('4'), digit('5'), digit('6'),
          digit('7'), digit('8'), digit('9'),
          onBiometric != null
              ? _KeypadButton(
                  icon: Icons.fingerprint,
                  onTap: onBiometric,
                )
              : const SizedBox.shrink(),
          digit('0'),
          _KeypadButton(
            icon: Icons.backspace_outlined,
            onTap: onBackspace,
          ),
        ],
      ),
    );
  }
}

class _KeypadButton extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final VoidCallback? onTap;

  const _KeypadButton({this.label, this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Center(
          child: label != null
              ? Text(
                  label!,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w500,
                  ),
                )
              : Icon(icon, size: 24),
        ),
      ),
    );
  }
}
