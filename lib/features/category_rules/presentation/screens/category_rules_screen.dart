import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../categories/presentation/providers/categories_provider.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../domain/entities/category_rule_entity.dart';
import '../providers/category_rules_provider.dart';

const _kGreen = Color(0xFF00D887);

const _kStaticExpenseCategories = [
  'Alimentação',
  'Moradia',
  'Transporte',
  'Saúde',
  'Educação',
  'Lazer',
  'Vestuário',
  'Outros',
];
const _kStaticIncomeCategories = [
  'Salário',
  'Freelance',
  'Investimentos',
  'Outros',
];

/// Screen to manage auto-categorization rules ("if text contains X → category Y").
/// Rules are applied when typing a new transaction and when a bank notification
/// is auto-imported.
class CategoryRulesScreen extends ConsumerWidget {
  const CategoryRulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rulesAsync = ref.watch(categoryRulesStreamProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Regras de categorização')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context, ref),
        backgroundColor: _kGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nova regra'),
      ),
      body: rulesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Erro ao carregar regras')),
        data: (rules) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bolt_rounded, color: _kGreen, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Quando a descrição de um lançamento contém a palavra-chave, '
                        'a categoria é preenchida automaticamente — no app e nas '
                        'notificações detectadas.',
                        style: TextStyle(
                            fontSize: 12.5,
                            height: 1.35,
                            color: cs.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (rules.isEmpty)
                _EmptyState(onAdd: () => _openEditor(context, ref))
              else
                ...rules.map((r) => _RuleTile(
                      rule: r,
                      onEdit: () => _openEditor(context, ref, existing: r),
                      onDelete: () => _delete(context, ref, r),
                    )),
            ],
          );
        },
      ),
    );
  }

  Future<void> _delete(
      BuildContext context, WidgetRef ref, CategoryRuleEntity rule) async {
    await ref.read(categoryRulesNotifierProvider.notifier).delete(rule.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Regra removida')),
    );
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref, {
    CategoryRuleEntity? existing,
  }) async {
    final result = await showModalBottomSheet<_RuleDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _RuleEditor(existing: existing),
    );
    if (result == null) return;

    final notifier = ref.read(categoryRulesNotifierProvider.notifier);
    if (existing == null) {
      await notifier.add(
        keyword: result.keyword,
        categoryName: result.category,
        type: result.type,
      );
    } else {
      await notifier.update(existing.copyWith(
        keyword: result.keyword,
        categoryName: result.category,
        type: result.type,
        clearType: result.type == null,
      ));
    }
  }
}

// ── Rule draft returned by the editor ─────────────────────────────────────────

class _RuleDraft {
  final String keyword;
  final String category;
  final TransactionType? type;
  const _RuleDraft(this.keyword, this.category, this.type);
}

// ── Rule list tile ────────────────────────────────────────────────────────────

class _RuleTile extends StatelessWidget {
  final CategoryRuleEntity rule;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RuleTile({
    required this.rule,
    required this.onEdit,
    required this.onDelete,
  });

  String get _typeLabel {
    switch (rule.type) {
      case TransactionType.expense:
        return 'Despesa';
      case TransactionType.income:
        return 'Receita';
      default:
        return 'Despesa e receita';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: onEdit,
        title: Row(
          children: [
            Flexible(
              child: Text(
                '"${rule.keyword}"',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Icon(Icons.arrow_forward_rounded, size: 16),
            ),
            Flexible(
              child: Text(
                rule.categoryName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, color: _kGreen),
              ),
            ),
          ],
        ),
        subtitle: Text(_typeLabel,
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline, color: cs.error),
          onPressed: onDelete,
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        children: [
          Icon(Icons.rule_folder_outlined,
              size: 56, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text('Nenhuma regra ainda',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface)),
          const SizedBox(height: 6),
          Text(
            'Ex.: contém "POSTO" → Transporte',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// ── Editor (add / edit) ───────────────────────────────────────────────────────

enum _RuleScope { expense, income, both }

class _RuleEditor extends ConsumerStatefulWidget {
  final CategoryRuleEntity? existing;
  const _RuleEditor({this.existing});

  @override
  ConsumerState<_RuleEditor> createState() => _RuleEditorState();
}

class _RuleEditorState extends ConsumerState<_RuleEditor> {
  late final TextEditingController _keywordCtrl;
  late _RuleScope _scope;
  String? _category;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _keywordCtrl = TextEditingController(text: e?.keyword ?? '');
    _scope = switch (e?.type) {
      TransactionType.income => _RuleScope.income,
      TransactionType.expense => _RuleScope.expense,
      _ => _RuleScope.both,
    };
    _category = e?.categoryName;
  }

  @override
  void dispose() {
    _keywordCtrl.dispose();
    super.dispose();
  }

  TransactionType? get _typeForScope => switch (_scope) {
        _RuleScope.expense => TransactionType.expense,
        _RuleScope.income => TransactionType.income,
        _RuleScope.both => null,
      };

  List<String> _categoryOptions() {
    final income = ref.watch(incomeCategoriesProvider).map((c) => c.name);
    final expense = ref.watch(expenseCategoriesProvider).map((c) => c.name);
    Iterable<String> base;
    switch (_scope) {
      case _RuleScope.expense:
        base = expense.isNotEmpty ? expense : _kStaticExpenseCategories;
      case _RuleScope.income:
        base = income.isNotEmpty ? income : _kStaticIncomeCategories;
      case _RuleScope.both:
        final exp = expense.isNotEmpty ? expense : _kStaticExpenseCategories;
        final inc = income.isNotEmpty ? income : _kStaticIncomeCategories;
        base = {...exp, ...inc};
    }
    return base.toList();
  }

  bool get _canSave =>
      _keywordCtrl.text.trim().isNotEmpty &&
      _category != null &&
      _category!.isNotEmpty;

  void _save() {
    if (!_canSave) return;
    Navigator.of(context).pop(
      _RuleDraft(_keywordCtrl.text.trim(), _category!, _typeForScope),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final options = _categoryOptions();
    // Drop a stale selection that isn't valid for the current scope.
    final value = (_category != null && options.contains(_category))
        ? _category
        : null;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.existing == null ? 'Nova regra' : 'Editar regra',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _keywordCtrl,
            autofocus: widget.existing == null,
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Se a descrição contém',
              hintText: 'Ex.: POSTO',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          SegmentedButton<_RuleScope>(
            segments: const [
              ButtonSegment(value: _RuleScope.expense, label: Text('Despesa')),
              ButtonSegment(value: _RuleScope.income, label: Text('Receita')),
              ButtonSegment(value: _RuleScope.both, label: Text('Ambos')),
            ],
            selected: {_scope},
            onSelectionChanged: (s) => setState(() {
              _scope = s.first;
              // Reset category if it no longer belongs to the new scope.
              if (!_categoryOptions().contains(_category)) _category = null;
            }),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: value,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Categorizar como',
              prefixIcon: const Icon(Icons.label_outline),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            items: options
                .map((name) =>
                    DropdownMenuItem(value: name, child: Text(name)))
                .toList(),
            onChanged: (v) => setState(() => _category = v),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _kGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _canSave ? _save : null,
              child: Text(widget.existing == null ? 'Criar regra' : 'Salvar'),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'A regra mais específica (palavra-chave mais longa) vence.',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
