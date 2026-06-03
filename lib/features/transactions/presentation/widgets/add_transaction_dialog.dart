import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/providers/effective_user_provider.dart';
import '../../../../core/widgets/help_hint.dart';
import '../../../categories/domain/entities/category_entity.dart';
import '../../../categories/presentation/providers/categories_provider.dart';
import '../../../subscription/presentation/providers/subscription_provider.dart';
import '../../../subscription/presentation/widgets/pro_gate_widget.dart';
import '../../../wallets/presentation/providers/wallets_provider.dart';
import '../../../../core/utils/money_input_formatter.dart';
import '../../../../core/utils/icon_data_utils.dart';
import '../../../goals/presentation/providers/goals_provider.dart';
import '../../domain/entities/transaction_entity.dart';
import '../providers/transactions_provider.dart';

const _kNewCategory = '__new__';
const _kNewWallet = '__new_wallet__';
const _kGreen = Color(0xFF00D887);

class AddTransactionDialog extends ConsumerStatefulWidget {
  /// If provided, the dialog opens in edit mode pre-filled with this transaction.
  final TransactionEntity? transaction;

  /// Pre-fills the amount field (used by the notification suggestion feature).
  final double? initialAmount;

  /// Pre-selects the transaction type (used by the notification suggestion feature).
  final TransactionType? initialType;

  const AddTransactionDialog({
    super.key,
    this.transaction,
    this.initialAmount,
    this.initialType,
  });

  @override
  ConsumerState<AddTransactionDialog> createState() =>
      _AddTransactionDialogState();
}

class _AddTransactionDialogState extends ConsumerState<AddTransactionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagController = TextEditingController();

  TransactionType _type = TransactionType.expense;
  String? _category;
  DateTime _date = DateTime.now();
  String? _suggestedCategory;
  String _walletId = '';
  String? _goalId;
  List<String> _tags = [];

  bool get _isEditing => widget.transaction != null;

  static const _staticIncomeCategories = [
    'Salário', 'Freelance', 'Investimentos', 'Outros',
  ];
  static const _staticExpenseCategories = [
    'Alimentação', 'Moradia', 'Transporte', 'Saúde',
    'Educação', 'Lazer', 'Vestuário', 'Outros',
  ];

  List<String> _categoryNames() {
    if (_type == TransactionType.income) {
      final cats = ref.watch(incomeCategoriesProvider);
      return cats.isNotEmpty
          ? cats.map((c) => c.name).toList()
          : _staticIncomeCategories;
    } else {
      final cats = ref.watch(expenseCategoriesProvider);
      return cats.isNotEmpty
          ? cats.map((c) => c.name).toList()
          : _staticExpenseCategories;
    }
  }

  // --- Auto-suggest ---

  String? _computeSuggestion(String input) {
    if (_isEditing) return null;
    final query = input.toLowerCase().trim();
    if (query.length < 3) return null;
    final transactions = ref.read(transactionsStreamProvider).value ?? [];
    if (transactions.isEmpty) return null;

    final queryWords =
        query.split(RegExp(r'\s+')).where((w) => w.length >= 3).toSet();
    String? bestCategory;
    int bestScore = 0;

    for (final t in transactions) {
      final titleLower = t.title.toLowerCase();
      final titleWords =
          titleLower.split(RegExp(r'\s+')).where((w) => w.length >= 3).toSet();
      final wordOverlap = queryWords.intersection(titleWords).length;
      final substringMatch =
          (titleLower.contains(query) || query.contains(titleLower)) ? 1 : 0;
      final score = wordOverlap + substringMatch;
      if (score > bestScore) {
        bestScore = score;
        bestCategory = t.category;
      }
    }
    return bestScore > 0 ? bestCategory : null;
  }

  void _onTitleChanged(String value) {
    final suggestion = _computeSuggestion(value);
    if (suggestion != _suggestedCategory) {
      setState(() => _suggestedCategory = suggestion);
    }
  }

  void _acceptSuggestion() {
    if (_suggestedCategory == null) return;
    final categories = _categoryNames();
    if (categories.contains(_suggestedCategory)) {
      setState(() {
        _category = _suggestedCategory;
        _suggestedCategory = null;
      });
    }
  }

  void _dismissSuggestion() => setState(() => _suggestedCategory = null);

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isEmpty || _tags.contains(tag)) return;
    setState(() {
      _tags.add(tag);
      _tagController.clear();
    });
  }

  // --- New category dialog ---

  Future<void> _showNewCategoryDialog() async {
    final nameCtrl = TextEditingController();
    final effectiveUserId = ref.read(effectiveUserIdProvider);
    if (effectiveUserId.isEmpty) return;

    final l10n = AppLocalizations.of(context);
    final created = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.newCategoryTitle),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l10n.categoryName,
            border: const OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.words,
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(nameCtrl.text.trim()),
            child: Text(l10n.create),
          ),
        ],
      ),
    );

    nameCtrl.dispose();
    if (created == null || created.isEmpty) return;
    if (!mounted) return;

    final categoryType = _type == TransactionType.income
        ? CategoryType.income
        : CategoryType.expense;

    final success = await ref.read(categoriesNotifierProvider.notifier).add(
          userId: effectiveUserId,
          name: created,
          type: categoryType,
          iconCodePoint: Icons.label_outline_rounded.codePoint,
          colorValue: 0xFF607D8B,
        );

    if (!mounted) return;
    if (success) {
      setState(() => _category = created);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao criar categoria.')),
      );
    }
  }

  // --- New wallet dialog ---

  Future<void> _showNewWalletDialog() async {
    final l10n = AppLocalizations.of(context);
    final nameCtrl = TextEditingController();
    final effectiveUserId = ref.read(effectiveUserIdProvider);
    if (effectiveUserId.isEmpty) return;

    final created = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.wallet),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l10n.walletName,
            border: const OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.words,
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(nameCtrl.text.trim()),
            child: Text(l10n.create),
          ),
        ],
      ),
    );

    nameCtrl.dispose();
    if (created == null || created.isEmpty) return;
    if (!mounted) return;

    final success = await ref.read(walletsNotifierProvider.notifier).add(
          userId: effectiveUserId,
          name: created,
          iconCodePoint: Icons.account_balance_wallet_outlined.codePoint,
          colorValue: 0xFF607D8B,
        );

    if (!mounted) return;
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.errorCreatingWallet)),
      );
    }
    // walletId stays unchanged — user picks from dropdown after creation
  }

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final t = widget.transaction!;
      _titleController.text = t.title;
      _amountController.text = doubleToMoneyText(t.amount);
      _descriptionController.text = t.description ?? '';
      _type = t.type;
      _category = t.category;
      _date = t.date;
      _walletId = t.walletId;
      _goalId = t.goalId;
      _tags = [...t.tags];
    }
    // Pre-fill from notification suggestion
    if (!_isEditing) {
      if (widget.initialAmount != null) {
        _amountController.text = doubleToMoneyText(widget.initialAmount!);
      }
      if (widget.initialType != null) {
        _type = widget.initialType!;
      }
    }
    _titleController.addListener(() => _onTitleChanged(_titleController.text));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteTransaction),
        content: Text(l10n.deleteTransactionConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final success = await ref
        .read(transactionsNotifierProvider.notifier)
        .delete(widget.transaction!.id);
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).errorDeletingTransaction)),
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = moneyTextToDouble(_amountController.text);
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Valor inválido')),
      );
      return;
    }

    // Snapshot for smart monthly alert (only for new expenses in the current calendar month)
    final now = DateTime.now();
    final isCurrentMonthExpense = !_isEditing &&
        _type == TransactionType.expense &&
        _date.year == now.year &&
        _date.month == now.month;
    final prevMonthExpense = isCurrentMonthExpense
        ? ref.read(previousCalendarMonthExpenseProvider)
        : 0.0;
    final curMonthExpense = isCurrentMonthExpense
        ? ref.read(currentCalendarMonthExpenseProvider)
        : 0.0;

    final notifier = ref.read(transactionsNotifierProvider.notifier);
    final bool success;

    if (_isEditing) {
      final updated = TransactionEntity(
        id: widget.transaction!.id,
        userId: widget.transaction!.userId,
        title: _titleController.text.trim(),
        amount: amount,
        type: _type,
        category: _category!,
        date: _date,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        walletId: _walletId,
        goalId: _type == TransactionType.income ? _goalId : null,
        tags: _tags,
      );
      success = await notifier.update(updated);
    } else {
      success = await notifier.add(
        title: _titleController.text.trim(),
        amount: amount,
        type: _type,
        category: _category!,
        date: _date,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        walletId: _walletId,
        goalId: _type == TransactionType.income ? _goalId : null,
        tags: _tags,
      );
    }

    if (!mounted) return;
    if (success) {
      // Smart alert: notify when expenses exceed last month's total
      if (isCurrentMonthExpense && prevMonthExpense > 0) {
        final newTotal = curMonthExpense + amount;
        if (newTotal > prevMonthExpense) {
          final diff = newTotal - prevMonthExpense;
          final justCrossed = curMonthExpense <= prevMonthExpense;
          final message = justCrossed
              ? 'Suas despesas ultrapassaram o mês passado em R\$ ${doubleToMoneyText(diff)}!'
              : 'Atenção! R\$ ${doubleToMoneyText(diff)} acima das despesas do mês passado.';
          final messenger = ScaffoldMessenger.of(context);
          Navigator.of(context).pop();
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Text(message)),
                  ],
                ),
                backgroundColor: Colors.orange.shade800,
                duration: const Duration(seconds: 5),
                behavior: SnackBarBehavior.floating,
              ),
            );
          return;
        }
      }
      Navigator.of(context).pop();
    } else {
      final errorMsg =
          ref.read(transactionsNotifierProvider).error?.toString() ??
              'Erro ao salvar transação.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isLoading = ref.watch(transactionsNotifierProvider).isLoading;
    final categories = _categoryNames();
    final wallets = ref.watch(walletsStreamProvider).value ?? [];
    final goals = ref.watch(goalsStreamProvider).value ?? [];

    // Default category
    _category ??= categories.isNotEmpty ? categories.first : null;

    // Default wallet to first available
    if (_walletId.isEmpty && wallets.isNotEmpty) {
      _walletId = wallets.first.id;
    }

    final showSuggestion = _suggestedCategory != null &&
        categories.contains(_suggestedCategory) &&
        _suggestedCategory != _category;

    return AlertDialog(
      title: Row(
        children: [
          Expanded(
            child: Text(
                _isEditing ? l10n.editTransaction : l10n.newTransaction),
          ),
          HelpHint(
            title: l10n.hintIncomeExpenseTitle,
            body: l10n.hintIncomeExpenseBody,
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Type toggle (Despesa / Receita) ──────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _TypeButton(
                        label: l10n.expense,
                        icon: Icons.arrow_downward_rounded,
                        isSelected: _type == TransactionType.expense,
                        activeColor: const Color(0xFFEF4444),
                        onTap: () => setState(() {
                          _type = TransactionType.expense;
                          _category = null;
                          _suggestedCategory = null;
                        }),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _TypeButton(
                        label: l10n.incomeType,
                        icon: Icons.arrow_upward_rounded,
                        isSelected: _type == TransactionType.income,
                        activeColor: const Color(0xFF10B981),
                        onTap: () => setState(() {
                          _type = TransactionType.income;
                          _category = null;
                          _suggestedCategory = null;
                        }),
                      ),
                    ),
                  ],
                ),

                // ── Amount field (prominent) ─────────────────────────────
                const SizedBox(height: 20),
                TextFormField(
                  controller: _amountController,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [MoneyInputFormatter()],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: _type == TransactionType.expense
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF10B981),
                  ),
                  decoration: InputDecoration(
                    hintText: 'R\$ 0,00',
                    hintStyle: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: (_type == TransactionType.expense
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF10B981))
                          .withValues(alpha: 0.35),
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: _type == TransactionType.expense
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF10B981),
                        width: 2,
                      ),
                    ),
                    errorBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.red),
                    ),
                    focusedErrorBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.red, width: 2),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return l10n.enterAmount;
                    final n = moneyTextToDouble(v);
                    if (n <= 0) return l10n.invalidAmount;
                    if (n > 1000000000) return l10n.maxAmount;
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // ── Title field (optional) ───────────────────────────────
                TextFormField(
                  controller: _titleController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: l10n.titleField,
                    border: const OutlineInputBorder(),
                  ),
                ),

                // Auto-suggest banner
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  child: showSuggestion
                      ? Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: _kGreen.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: _kGreen.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.auto_awesome,
                                    size: 16, color: _kGreen),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${l10n.suggestCategory}: $_suggestedCategory',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: _acceptSuggestion,
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: Text(
                                      l10n.use,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: _kGreen,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: _dismissSuggestion,
                                  child: const Padding(
                                    padding: EdgeInsets.only(left: 8),
                                    child: Icon(Icons.close,
                                        size: 16, color: Colors.grey),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),

                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: categories.contains(_category) ? _category : null,
                  decoration: InputDecoration(
                    labelText: l10n.categoryField,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v == _kNewCategory)
                      ? l10n.selectCategory
                      : null,
                  items: [
                    ...categories.map(
                      (c) => DropdownMenuItem(value: c, child: Text(c)),
                    ),
                    DropdownMenuItem(
                      value: _kNewCategory,
                      child: Row(
                        children: [
                          const Icon(Icons.add_circle_outline,
                              size: 18, color: _kGreen),
                          const SizedBox(width: 8),
                          Text(
                            l10n.newCategory,
                            style: const TextStyle(
                              color: _kGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  onChanged: (v) {
                    if (v == _kNewCategory) {
                      if (!ref.read(isProProvider)) {
                        showProGateBottomSheet(
                          context,
                          featureName: 'Categorias Personalizadas',
                          featureDescription:
                              'Crie categorias ilimitadas do seu jeito.',
                          featureIcon: Icons.category_rounded,
                        );
                        return;
                      }
                      _showNewCategoryDialog();
                    } else {
                      setState(() => _category = v);
                    }
                  },
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _selectDate,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: l10n.dateField,
                      suffixIcon: const Icon(Icons.calendar_today),
                      border: const OutlineInputBorder(),
                    ),
                    child: Text(
                      '${_date.day.toString().padLeft(2, '0')}/'
                      '${_date.month.toString().padLeft(2, '0')}/'
                      '${_date.year}',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Wallet dropdown
                DropdownButtonFormField<String>(
                  key: ValueKey('wallet_$_walletId'),
                  initialValue: wallets.any((w) => w.id == _walletId)
                      ? _walletId
                      : (wallets.isNotEmpty ? wallets.first.id : null),
                  decoration: InputDecoration(
                    labelText: l10n.walletField,
                    prefixIcon: const Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 20),
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    ...wallets.map(
                      (w) => DropdownMenuItem(
                        value: w.id,
                        child: Text(w.name),
                      ),
                    ),
                    DropdownMenuItem(
                      value: _kNewWallet,
                      child: Row(
                        children: [
                          const Icon(Icons.add_circle_outline,
                              size: 18, color: _kGreen),
                          const SizedBox(width: 8),
                          Text(
                            l10n.newWallet,
                            style: const TextStyle(
                              color: _kGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  onChanged: (v) {
                    if (v == _kNewWallet) {
                      if (!ref.read(canAddWalletProvider)) {
                        showProGateBottomSheet(
                          context,
                          featureName: 'Múltiplas Carteiras',
                          featureDescription:
                              'Crie quantas carteiras quiser para organizar seu dinheiro.',
                          featureIcon: Icons.account_balance_wallet_rounded,
                        );
                        return;
                      }
                      _showNewWalletDialog();
                    } else if (v != null) {
                      setState(() => _walletId = v);
                    }
                  },
                ),
                // ── Goal selector (income only) ──────────────────────
                if (_type == TransactionType.income && goals.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    key: ValueKey('goal_$_goalId'),
                    initialValue: goals.any((g) => g.id == _goalId) ? _goalId : null,
                    decoration: const InputDecoration(
                      labelText: 'Vincular à meta (opcional)',
                      prefixIcon: Icon(Icons.savings_rounded, size: 20),
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Nenhuma meta'),
                      ),
                      ...goals.map(
                        (g) => DropdownMenuItem<String?>(
                          value: g.id,
                          child: Row(
                            children: [
                              Icon(
                                goalIconFromCodePoint(g.iconCodePoint),
                                size: 16,
                                color: Color(g.colorValue),
                              ),
                              const SizedBox(width: 8),
                              Text(g.title),
                            ],
                          ),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => _goalId = v),
                  ),
                ],
                // ── Observação ──
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Observação (opcional)',
                    hintText: 'Adicione uma nota...',
                    prefixIcon: Icon(Icons.notes_rounded, size: 20),
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                ),
                // ── Tags (Pro) ──
                if (ref.watch(isProProvider)) ...[
                  const SizedBox(height: 12),
                  // Existing tags chips
                  if (_tags.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: _tags.map((tag) => Chip(
                          label: Text(tag, style: const TextStyle(fontSize: 12)),
                          deleteIcon: const Icon(Icons.close, size: 14),
                          onDeleted: () => setState(() => _tags.remove(tag)),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        )).toList(),
                      ),
                    ),
                  // Add tag input
                  TextFormField(
                    controller: _tagController,
                    decoration: InputDecoration(
                      labelText: 'Tags (opcional)',
                      hintText: 'Digite e pressione Enter',
                      prefixIcon: const Icon(Icons.label_outline_rounded, size: 20),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.add, size: 20),
                        onPressed: _addTag,
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    onFieldSubmitted: (_) => _addTag(),
                  ),
                ],
                if (_isEditing) ...[
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 4),
                  OutlinedButton.icon(
                    onPressed: isLoading ? null : _delete,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                      side: BorderSide(
                          color: Theme.of(context).colorScheme.error),
                      minimumSize: const Size(double.infinity, 44),
                    ),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: Text(l10n.deleteTransaction),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: isLoading ? null : _submit,
          child: isLoading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.save),
        ),
      ],
    );
  }
}

// ─── Type Toggle Button ────────────────────────────────────────────────────────

class _TypeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final Color activeColor;
  final VoidCallback onTap;

  const _TypeButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.18)
              : activeColor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? activeColor.withValues(alpha: 0.7)
                : activeColor.withValues(alpha: 0.2),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? activeColor
                  : activeColor.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? activeColor
                    : activeColor.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
