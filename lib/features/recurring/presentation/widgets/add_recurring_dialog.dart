import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/money_input_formatter.dart';
import '../../../categories/presentation/providers/categories_provider.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../wallets/presentation/providers/wallets_provider.dart';
import '../../domain/entities/recurring_transaction_entity.dart';
import '../providers/recurring_provider.dart';

class AddRecurringDialog extends ConsumerStatefulWidget {
  final RecurringTransactionEntity? recurring;

  const AddRecurringDialog({super.key, this.recurring});

  @override
  ConsumerState<AddRecurringDialog> createState() => _AddRecurringDialogState();
}

class _AddRecurringDialogState extends ConsumerState<AddRecurringDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  TransactionType _type = TransactionType.expense;
  String? _selectedCategory;
  String _walletId = '';
  RecurrenceFrequency _frequency = RecurrenceFrequency.monthly;
  int _dayOfRecurrence = 1;
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;

  bool get _isEditing => widget.recurring != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final r = widget.recurring!;
      _titleController.text = r.title;
      _amountController.text = doubleToMoneyText(r.amount);
      _descriptionController.text = r.description ?? '';
      _type = r.type;
      _selectedCategory = r.category;
      _walletId = r.walletId;
      _frequency = r.frequency;
      _dayOfRecurrence = r.dayOfRecurrence;
      _startDate = r.startDate;
      _endDate = r.endDate;
    } else {
      _dayOfRecurrence = DateTime.now().day;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione uma categoria')),
      );
      return;
    }

    final amount = moneyTextToDouble(_amountController.text);
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Valor inválido')),
      );
      return;
    }

    final notifier = ref.read(recurringNotifierProvider.notifier);
    bool success;

    if (_isEditing) {
      success = await notifier.update(widget.recurring!.copyWith(
        title: _titleController.text.trim(),
        amount: amount,
        type: _type,
        category: _selectedCategory!,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        walletId: _walletId,
        frequency: _frequency,
        dayOfRecurrence: _dayOfRecurrence,
        startDate: _startDate,
        endDate: _endDate,
      ));
    } else {
      success = await notifier.add(
        title: _titleController.text.trim(),
        amount: amount,
        type: _type,
        category: _selectedCategory!,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        walletId: _walletId,
        frequency: _frequency,
        dayOfRecurrence: _dayOfRecurrence,
        startDate: _startDate,
        endDate: _endDate,
      );
    }

    if (!mounted) return;
    if (success) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final wallets = ref.watch(walletsStreamProvider).value ?? [];
    final rawCategories = _type == TransactionType.income
        ? ref.watch(incomeCategoriesProvider)
        : ref.watch(expenseCategoriesProvider);
    // Deduplicate category names to avoid DropdownButton assertion errors
    final categoryNames = rawCategories
        .map((c) => c.name)
        .toSet()
        .toList();
    final isLoading = ref.watch(recurringNotifierProvider).isLoading;

    // Ensure selected category is still valid after type switch
    if (_selectedCategory != null &&
        !categoryNames.contains(_selectedCategory)) {
      _selectedCategory = null;
    }

    return AlertDialog(
      title: Text(_isEditing ? 'Editar Recorrência' : 'Nova Recorrência'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Type toggle ──
                SegmentedButton<TransactionType>(
                  segments: const [
                    ButtonSegment(
                      value: TransactionType.expense,
                      label: Text('Despesa'),
                      icon: Icon(Icons.arrow_upward_rounded, size: 16),
                    ),
                    ButtonSegment(
                      value: TransactionType.income,
                      label: Text('Receita'),
                      icon: Icon(Icons.arrow_downward_rounded, size: 16),
                    ),
                  ],
                  selected: {_type},
                  onSelectionChanged: (v) =>
                      setState(() => _type = v.first),
                ),
                const SizedBox(height: 16),

                // ── Title ──
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Título',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Informe um título' : null,
                ),
                const SizedBox(height: 12),

                // ── Amount ──
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [MoneyInputFormatter()],
                  decoration: const InputDecoration(
                    labelText: 'Valor',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Informe o valor';
                    if (moneyTextToDouble(v) <= 0) return 'Valor inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // ── Category ──
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Categoria',
                    border: OutlineInputBorder(),
                  ),
                  items: categoryNames
                      .map((name) => DropdownMenuItem(
                            value: name,
                            child: Text(name),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedCategory = v),
                  validator: (v) => v == null ? 'Selecione uma categoria' : null,
                ),
                const SizedBox(height: 12),

                // ── Wallet ──
                if (wallets.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: DropdownButtonFormField<String>(
                      initialValue: _walletId,
                      decoration: const InputDecoration(
                        labelText: 'Carteira',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('Geral'),
                        ),
                        ...wallets.map((w) => DropdownMenuItem(
                              value: w.id,
                              child: Text(w.name),
                            )),
                      ],
                      onChanged: (v) =>
                          setState(() => _walletId = v ?? ''),
                    ),
                  ),

                // ── Frequency ──
                DropdownButtonFormField<RecurrenceFrequency>(
                  initialValue: _frequency,
                  decoration: const InputDecoration(
                    labelText: 'Frequência',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: RecurrenceFrequency.daily,
                      child: Text('Diária'),
                    ),
                    DropdownMenuItem(
                      value: RecurrenceFrequency.weekly,
                      child: Text('Semanal'),
                    ),
                    DropdownMenuItem(
                      value: RecurrenceFrequency.monthly,
                      child: Text('Mensal'),
                    ),
                    DropdownMenuItem(
                      value: RecurrenceFrequency.yearly,
                      child: Text('Anual'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      _frequency = v;
                      if (v == RecurrenceFrequency.weekly) {
                        _dayOfRecurrence =
                            _dayOfRecurrence.clamp(1, 7);
                      } else if (v == RecurrenceFrequency.monthly) {
                        _dayOfRecurrence =
                            _dayOfRecurrence.clamp(1, 31);
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),

                // ── Day of recurrence ──
                if (_frequency == RecurrenceFrequency.weekly)
                  DropdownButtonFormField<int>(
                    initialValue: _dayOfRecurrence.clamp(1, 7),
                    decoration: const InputDecoration(
                      labelText: 'Dia da semana',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('Segunda')),
                      DropdownMenuItem(value: 2, child: Text('Terça')),
                      DropdownMenuItem(value: 3, child: Text('Quarta')),
                      DropdownMenuItem(value: 4, child: Text('Quinta')),
                      DropdownMenuItem(value: 5, child: Text('Sexta')),
                      DropdownMenuItem(value: 6, child: Text('Sábado')),
                      DropdownMenuItem(value: 7, child: Text('Domingo')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _dayOfRecurrence = v);
                    },
                  ),
                if (_frequency == RecurrenceFrequency.monthly)
                  DropdownButtonFormField<int>(
                    initialValue: _dayOfRecurrence.clamp(1, 31),
                    decoration: const InputDecoration(
                      labelText: 'Dia do mês',
                      border: OutlineInputBorder(),
                    ),
                    items: List.generate(
                      31,
                      (i) => DropdownMenuItem(
                        value: i + 1,
                        child: Text('Dia ${i + 1}'),
                      ),
                    ),
                    onChanged: (v) {
                      if (v != null) setState(() => _dayOfRecurrence = v);
                    },
                  ),
                const SizedBox(height: 12),

                // ── Start date ──
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today_outlined),
                  title: const Text('Data de início'),
                  subtitle: Text(
                    '${_startDate.day.toString().padLeft(2, '0')}/'
                    '${_startDate.month.toString().padLeft(2, '0')}/'
                    '${_startDate.year}',
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _startDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setState(() => _startDate = picked);
                  },
                ),

                // ── End date (optional) ──
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_outlined),
                  title: const Text('Data de término (opcional)'),
                  subtitle: Text(
                    _endDate != null
                        ? '${_endDate!.day.toString().padLeft(2, '0')}/'
                          '${_endDate!.month.toString().padLeft(2, '0')}/'
                          '${_endDate!.year}'
                        : 'Sem data de término',
                  ),
                  trailing: _endDate != null
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => setState(() => _endDate = null),
                        )
                      : null,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _endDate ?? _startDate,
                      firstDate: _startDate,
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setState(() => _endDate = picked);
                  },
                ),
                const SizedBox(height: 8),

                // ── Description ──
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Descrição (opcional)',
                    border: OutlineInputBorder(),
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
          onPressed: isLoading ? null : _submit,
          child: isLoading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_isEditing ? 'Salvar' : 'Criar'),
        ),
      ],
    );
  }
}
