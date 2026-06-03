# Regras do projeto — my_finance_app

## Plano Pro

Sempre que uma funcionalidade for adicionada ao plano Pro (gate via `isProProvider` /
`ProGateWidget` / `showProGateBottomSheet`), ela **deve ser adicionada também à lista de
vantagens** em `lib/features/subscription/presentation/screens/pro_screen.dart`
(widget `_FeaturesCard`), usando um `_FeatureRow` com ícone, título e descrição coerentes.

### Funcionalidades Pro atuais
| Funcionalidade | Gate aplicado em |
|---|---|
| Múltiplas carteiras | `add_transaction_dialog.dart`, `settings_screen.dart` |
| Categorias personalizadas | `add_transaction_dialog.dart`, `settings_screen.dart` |
| Visão anual | `transactions_screen.dart` |
| Orçamentos | `planning_screen.dart` (ProGateWidget no tab) |
| Metas financeiras | `goals_screen.dart` (_openAddDialog) |
| Compartilhamento | `settings_screen.dart` |
| Transações recorrentes | `planning_screen.dart` (ProGateWidget no tab) |
| Tags / Etiquetas | `add_transaction_dialog.dart` (input só aparece se Pro) |
| Importação de extratos (OFX/CSV) | `settings_screen.dart` (`_DataIoCard._openImport`) |
| Exportação de relatórios (PDF/Excel) | `settings_screen.dart` (`_DataIoCard._openExport`) |
| Saúde financeira (score 0–100) | `settings_screen.dart` (`_FinancialHealthCard._open`) |
