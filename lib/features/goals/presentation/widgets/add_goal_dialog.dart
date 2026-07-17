import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/icon_data_utils.dart';
import '../../../../core/utils/money_input_formatter.dart';
import '../../domain/entities/goal_entity.dart';
import '../providers/goals_provider.dart';

const _kGreen = Color(0xFF00D887);

const _kIconOptions = [
  Icons.savings_rounded,
  Icons.home_rounded,
  Icons.directions_car_rounded,
  Icons.flight_rounded,
  Icons.school_rounded,
  Icons.devices_rounded,
  Icons.favorite_rounded,
  Icons.beach_access_rounded,
  Icons.business_center_rounded,
  Icons.child_care_rounded,
  Icons.fitness_center_rounded,
  Icons.celebration_rounded,
];

const _kColorOptions = [
  0xFF00D887,
  0xFF1E88E5,
  0xFFFF6B6B,
  0xFFFFA726,
  0xFF7C4DFF,
  0xFF26C6DA,
  0xFFEC407A,
  0xFF66BB6A,
];

class AddGoalDialog extends ConsumerStatefulWidget {
  final GoalEntity? goal;
  const AddGoalDialog({super.key, this.goal});

  @override
  ConsumerState<AddGoalDialog> createState() => _AddGoalDialogState();
}

class _AddGoalDialogState extends ConsumerState<AddGoalDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();

  DateTime? _deadline;
  int _iconCodePoint = Icons.savings_rounded.codePoint;
  int _colorValue = 0xFF00D887;

  bool get _isEditing => widget.goal != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final g = widget.goal!;
      _titleController.text = g.title;
      _amountController.text = doubleToMoneyText(g.targetAmount);
      _deadline = g.deadline;
      _iconCodePoint = g.iconCodePoint;
      _colorValue = g.colorValue;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = moneyTextToDouble(_amountController.text);
    if (amount <= 0) return;

    bool success;
    if (_isEditing) {
      final updated = GoalEntity(
        id: widget.goal!.id,
        userId: widget.goal!.userId,
        title: _titleController.text.trim(),
        targetAmount: amount,
        deadline: _deadline,
        iconCodePoint: _iconCodePoint,
        colorValue: _colorValue,
        createdAt: widget.goal!.createdAt,
      );
      success = await ref.read(goalsNotifierProvider.notifier).update(updated);
    } else {
      success = await ref.read(goalsNotifierProvider.notifier).add(
            title: _titleController.text.trim(),
            targetAmount: amount,
            deadline: _deadline,
            iconCodePoint: _iconCodePoint,
            colorValue: _colorValue,
          );
    }
    if (success && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final color = Color(_colorValue);
    final symbol = ref.watch(currencySymbolProvider);
    return AlertDialog(
      title: Text(_isEditing ? 'Editar meta' : 'Nova meta'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Icon & color picker ──────────────────────────────────
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        goalIconFromCodePoint(_iconCodePoint),
                        color: color,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _kColorOptions.map((c) {
                          final selected = c == _colorValue;
                          return GestureDetector(
                            onTap: () => setState(() => _colorValue = c),
                            child: Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: Color(c),
                                shape: BoxShape.circle,
                                border: selected
                                    ? Border.all(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                        width: 2.5)
                                    : null,
                              ),
                              child: selected
                                  ? const Icon(Icons.check,
                                      size: 14, color: Colors.white)
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Icon picker row
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: _kIconOptions.map((icon) {
                      final selected = icon.codePoint == _iconCodePoint;
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _iconCodePoint = icon.codePoint),
                        child: Container(
                          width: 40,
                          height: 40,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: selected
                                ? color.withValues(alpha: 0.2)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: selected
                                ? Border.all(color: color)
                                : Border.all(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outline
                                        .withValues(alpha: 0.3)),
                          ),
                          child: Icon(icon,
                              size: 20,
                              color: selected
                                  ? color
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Title ──────────────────────────────────────────────
                TextFormField(
                  controller: _titleController,
                  autofocus: !_isEditing,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Nome da meta',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Informe um nome' : null,
                ),
                const SizedBox(height: 12),

                // ── Target amount ──────────────────────────────────────
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [MoneyInputFormatter()],
                  decoration: InputDecoration(
                    labelText: 'Valor da meta',
                    hintText: '$symbol 0,00',
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Informe o valor';
                    if (moneyTextToDouble(v) <= 0) return 'Valor inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // ── Deadline ───────────────────────────────────────────
                InkWell(
                  onTap: _pickDeadline,
                  borderRadius: BorderRadius.circular(8),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Prazo (opcional)',
                      suffixIcon: _deadline != null
                          ? IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () =>
                                  setState(() => _deadline = null),
                            )
                          : const Icon(Icons.calendar_today_outlined,
                              size: 18),
                      border: const OutlineInputBorder(),
                    ),
                    child: Text(
                      _deadline != null
                          ? '${_deadline!.day.toString().padLeft(2, '0')}/'
                              '${_deadline!.month.toString().padLeft(2, '0')}/'
                              '${_deadline!.year}'
                          : 'Sem prazo definido',
                      style: TextStyle(
                        color: _deadline != null
                            ? Theme.of(context).colorScheme.onSurface
                            : Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: _kGreen,
              foregroundColor: Colors.black),
          onPressed: _submit,
          child: Text(_isEditing ? 'Salvar' : 'Criar meta'),
        ),
      ],
    );
  }
}
