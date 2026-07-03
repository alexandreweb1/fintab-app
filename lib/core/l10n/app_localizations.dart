import 'package:flutter/material.dart';

/// Simple inline localizations for PT-BR, EN-US and ES-ES.
/// Access via: AppLocalizations.of(context).someKey
class AppLocalizations {
  final Locale locale;
  const AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        const AppLocalizations(Locale('pt', 'BR'));
  }

  static const delegate = _AppLocalizationsDelegate();

  static const supportedLocales = [
    Locale('pt', 'BR'),
    Locale('en', 'US'),
    Locale('es', 'ES'),
  ];

  String _t(String pt, String en, String es) {
    switch (locale.languageCode) {
      case 'en':
        return en;
      case 'es':
        return es;
      default:
        return pt;
    }
  }

  // ── App ──────────────────────────────────────────────────────────────────
  String get appTitle => _t('Fintab', 'Fintab', 'Fintab');

  // ── Navigation ───────────────────────────────────────────────────────────
  String get navHome => _t('Início', 'Home', 'Inicio');
  String get navStatement => _t('Extrato', 'Statement', 'Extracto');
  String get navPlanning => _t('Planejamento', 'Planning', 'Planificación');
  String get navProfile => _t('Perfil', 'Profile', 'Perfil');
  String get navReports => _t('Relatórios', 'Reports', 'Informes');
  String get newTransaction => _t('Nova Transação', 'New Transaction', 'Nueva Transacción');

  // ── Dashboard ────────────────────────────────────────────────────────────
  String get dashboard => _t('Dashboard', 'Dashboard', 'Dashboard');
  String get totalBalance => _t('Saldo Total', 'Total Balance', 'Saldo Total');
  String get income => _t('Receitas', 'Income', 'Ingresos');
  String get expenses => _t('Despesas', 'Expenses', 'Gastos');
  String get budgets => _t('Orçamentos', 'Budgets', 'Presupuestos');
  String get thisMonth => _t('Este mês', 'This month', 'Este mes');
  String get hello => _t('Olá', 'Hello', 'Hola');
  String get goodMorning => _t('Bom dia', 'Good morning', 'Buenos días');
  String get goodAfternoon => _t('Boa tarde', 'Good afternoon', 'Buenas tardes');
  String get goodEvening => _t('Boa noite', 'Good evening', 'Buenas noches');
  String get yourFinances => _t('Suas Finanças', 'Your Finances', 'Tus Finanzas');
  String get noBudgets => _t('Sem orçamentos', 'No budgets', 'Sin presupuestos');
  String get seeAll => _t('Ver tudo', 'See all', 'Ver todo');
  String get recentTransactions => _t('Transações Recentes', 'Recent Transactions', 'Transacciones Recientes');

  // ── Transactions ─────────────────────────────────────────────────────────
  String get transactions => _t('Transações', 'Transactions', 'Transacciones');
  String get noTransactions => _t('Nenhuma transação encontrada', 'No transactions found', 'No se encontraron transacciones');
  String get titleField => _t('Título', 'Title', 'Título');
  String get amountField => _t('Valor (R\$)', 'Amount', 'Monto');
  String get categoryField => _t('Categoria', 'Category', 'Categoría');
  String get dateField => _t('Data', 'Date', 'Fecha');
  String get descriptionField => _t('Descrição (opcional)', 'Description (optional)', 'Descripción (opcional)');
  String get expense => _t('Despesa', 'Expense', 'Gasto');
  String get incomeType => _t('Receita', 'Income', 'Ingreso');
  String get save => _t('Salvar', 'Save', 'Guardar');
  String get cancel => _t('Cancelar', 'Cancel', 'Cancelar');
  String get delete => _t('Excluir', 'Delete', 'Eliminar');
  String get edit => _t('Editar', 'Edit', 'Editar');
  String get date => _t('Data', 'Date', 'Fecha');
  String get optional => _t('opcional', 'optional', 'opcional');
  String get invalidAmount => _t('Valor inválido', 'Invalid amount', 'Monto inválido');
  String get enterTitle => _t('Informe o título', 'Enter a title', 'Ingrese un título');
  String get enterAmount => _t('Informe o valor', 'Enter the amount', 'Ingrese el monto');
  String get selectCategory => _t('Selecione uma categoria', 'Select a category', 'Seleccione una categoría');
  String get maxAmount => _t('Valor máximo: R\$ 1.000.000.000,00', 'Max: \$ 1,000,000,000.00', 'Máx: \$ 1.000.000.000,00');
  String get suggestedCategories => _t('Categorias sugeridas', 'Suggested categories', 'Categorías sugeridas');
  String get suggestExample => _t('ex.: ', 'e.g. ', 'ej.: ');
  String get use => _t('Usar', 'Use', 'Usar');
  String get newCategory => _t('Nova categoria...', 'New category...', 'Nueva categoría...');
  String get newCategoryTitle => _t('Nova Categoria', 'New Category', 'Nueva Categoría');
  String get categoryName => _t('Nome da categoria', 'Category name', 'Nombre de categoría');
  String get create => _t('Criar', 'Create', 'Crear');
  String get errorSavingTransaction => _t('Erro ao salvar transação.', 'Error saving transaction.', 'Error al guardar transacción.');
  String get errorCreatingCategory => _t('Erro ao criar categoria.', 'Error creating category.', 'Error al crear categoría.');
  String get editTransaction => _t('Editar Transação', 'Edit Transaction', 'Editar Transacción');
  String get editBudget => _t('Editar Orçamento', 'Edit Budget', 'Editar Presupuesto');
  String get selectMonth => _t('Selecionar mês', 'Select month', 'Seleccionar mes');
  String get annualView => _t('Visão anual', 'Annual view', 'Vista anual');
  String get monthlyView => _t('Visão mensal', 'Monthly view', 'Vista mensual');
  String get customPeriod => _t('Período personalizado', 'Custom period', 'Período personalizado');
  String get clearFilter => _t('Limpar filtro', 'Clear filter', 'Limpiar filtro');
  String get filterAll => _t('Todos', 'All', 'Todos');
  String get moreOptions => _t('Mais opções', 'More options', 'Más opciones');
  String get filterTitle => _t('Filtros', 'Filters', 'Filtros');
  String get filterClearAll => _t('Limpar tudo', 'Clear all', 'Limpiar todo');
  String get filterType => _t('Tipo', 'Type', 'Tipo');
  String get filterCategories => _t('Categorias', 'Categories', 'Categorías');
  String get filterAmountRange => _t('Faixa de valor', 'Amount range', 'Rango de valores');
  String get filterMin => _t('Mínimo', 'Minimum', 'Mínimo');
  String get filterMax => _t('Máximo', 'Maximum', 'Máximo');
  String get filterApply => _t('Aplicar filtros', 'Apply filters', 'Aplicar filtros');
  String get filterIncome => _t('Receitas', 'Income', 'Ingresos');
  String get filterExpenses => _t('Despesas', 'Expenses', 'Gastos');
  String get expenseByCategory => _t('Gastos por categoria', 'Expenses by category', 'Gastos por categoría');

  // ── Wallets (user-facing renamed to "Conta/Account" — "Carteira" now means
  //    the PF/PJ workspace; internal identifiers keep the wallet name) ───────
  String get wallet => _t('Conta', 'Account', 'Cuenta');
  String get wallets => _t('Contas', 'Accounts', 'Cuentas');
  String get newWallet => _t('Nova conta...', 'New account...', 'Nueva cuenta...');
  String get walletField => _t('Conta', 'Account', 'Cuenta');
  String get walletName => _t('Nome da conta', 'Account name', 'Nombre de la cuenta');
  String get manageWallets => _t('Gerenciar contas', 'Manage accounts', 'Gestionar cuentas');
  String get noWallets => _t('Nenhuma conta cadastrada.', 'No accounts found.', 'No hay cuentas.');
  String get errorCreatingWallet => _t('Erro ao criar conta.', 'Error creating account.', 'Error al crear cuenta.');
  String get appearance => _t('Aparência', 'Appearance', 'Apariencia');
  String get themeModeSystem => _t('Padrão do sistema', 'System default', 'Predeterminado del sistema');
  String get themeModeLight => _t('Claro', 'Light', 'Claro');
  String get themeModeDark => _t('Escuro', 'Dark', 'Oscuro');

  // ── Planning ─────────────────────────────────────────────────────────────
  String get planning => _t('Planejamento', 'Planning', 'Planificación');
  String get budget => _t('Orçamento', 'Budget', 'Presupuesto');
  String get noBudgetsForMonth => _t('Nenhum orçamento para', 'No budget for', 'Sin presupuesto para');
  String get tapToStart => _t('Toque em "+ Orçamento" para começar.', 'Tap "+ Budget" to get started.', 'Toque en "+ Presupuesto" para comenzar.');
  String get replicateFrom => _t('Replicar de', 'Copy from', 'Copiar de');
  String get replicateBudgets => _t('Replicar orçamentos', 'Copy budgets', 'Copiar presupuestos');
  String get replicateConfirm => _t('orçamento(s) de', 'budget(s) from', 'presupuesto(s) de');
  String get replicateConfirmTo => _t('para', 'to', 'a');
  String get replicate => _t('Replicar', 'Copy', 'Copiar');
  String get limit => _t('Limite (R\$)', 'Limit', 'Límite');
  String get spent => _t('Gasto', 'Spent', 'Gastado');
  String get limitLabel => _t('Limite', 'Limit', 'Límite');
  String get errorReplicating => _t('Erro ao replicar orçamentos.', 'Error copying budgets.', 'Error al copiar presupuestos.');
  String get createBudgetsFor => _t('Criar orçamentos para', 'Create budgets for', 'Crear presupuestos para');
  String get copyPrevLimits => _t('Copiar limites de um mês anterior', 'Copy limits from a previous month', 'Copiar límites de un mes anterior');
  String get copyPrevLimitsDesc => _t('Copia os limites definidos em um mês anterior', 'Copies the limits defined in a previous month', 'Copia los límites definidos en un mes anterior');
  String get baseOnSpending => _t('Basear nos gastos reais', 'Base on real spending', 'Basar en gastos reales');
  String get baseOnSpendingDesc => _t('Usa o total gasto em um mês como limite de cada categoria', 'Uses total spending in a month as the limit per category', 'Usa el total gastado en un mes como límite por categoría');
  String get baseOnSpendingDescSuffix => _t('como limite de cada categoria', 'as the limit per category', 'como límite por categoría');
  String get createBudgets => _t('Criar orçamentos', 'Create budgets', 'Crear presupuestos');
  String get selectSourceMonth => _t('Selecionar mês de referência', 'Select reference month', 'Seleccionar mes de referencia');
  String get budgetSummaryTitle => _t('Resumo do mês', 'Monthly Summary', 'Resumen mensual');
  String get budgetPlanned => _t('Previsto', 'Planned', 'Previsto');
  String get budgetRemaining => _t('Restante', 'Remaining', 'Restante');
  String get budgetExceeded => _t('Excedido', 'Exceeded', 'Excedido');
  String get budgetRollover => _t('Acumular saldo do mês anterior', 'Roll over last month\'s balance', 'Acumular saldo del mes anterior');
  String get budgetRolloverDesc => _t(
      'A sobra (ou o excesso) do mês anterior é somada ao limite deste mês.',
      'Last month\'s leftover (or overspend) is added to this month\'s limit.',
      'El sobrante (o exceso) del mes anterior se suma al límite de este mes.');
  String budgetCarriedOver(String amount) => _t(
      'Acumulado: $amount', 'Carried over: $amount', 'Acumulado: $amount');
  String get createManually => _t('Criar manualmente', 'Create manually', 'Crear manualmente');
  String get createManuallyDesc => _t('Define o limite de cada categoria individualmente', 'Set each category limit individually', 'Define el límite de cada categoría individualmente');

  // ── Settings ─────────────────────────────────────────────────────────────
  String get settings => _t('Configurações', 'Settings', 'Configuración');
  String get changePassword => _t('Alterar senha', 'Change password', 'Cambiar contraseña');
  String get expenseCategories => _t('Categorias de Despesa', 'Expense Categories', 'Categorías de Gastos');
  String get incomeCategories => _t('Categorias de Receita', 'Income Categories', 'Categorías de Ingresos');
  String get logout => _t('Sair', 'Logout', 'Cerrar sesión');
  String get editProfile => _t('Editar perfil', 'Edit profile', 'Editar perfil');
  String get noName => _t('Sem nome', 'No name', 'Sin nombre');
  String get nameField => _t('Nome', 'Name', 'Nombre');
  String get currentPassword => _t('Senha atual', 'Current password', 'Contraseña actual');
  String get newPassword => _t('Nova senha', 'New password', 'Nueva contraseña');
  String get enterCurrentPassword => _t('Informe a senha atual', 'Enter current password', 'Ingrese la contraseña actual');
  String get enterNewPassword => _t('Informe a nova senha', 'Enter new password', 'Ingrese la nueva contraseña');
  String get minChars => _t('Mínimo 6 caracteres', 'Minimum 6 characters', 'Mínimo 6 caracteres');
  String get passwordChanged => _t('Senha alterada com sucesso!', 'Password changed successfully!', '¡Contraseña cambiada con éxito!');
  String get setPassword => _t('Definir senha', 'Set password', 'Establecer contraseña');
  String get setPasswordSubtitle => _t('Permite login com email e senha', 'Enables email & password login', 'Permite inicio de sesión con email y contraseña');
  String get passwordSet => _t('Senha definida! Agora você pode entrar com email e senha.', 'Password set! You can now sign in with email and password.', '¡Contraseña definida! Ahora puede iniciar sesión con email y contraseña.');
  String get defaultCategory => _t('Categoria padrão', 'Default category', 'Categoría predeterminada');
  String get addExpenseCategory => _t('Adicionar despesa', 'Add expense', 'Agregar gasto');
  String get addIncomeCategory => _t('Adicionar receita', 'Add income', 'Agregar ingreso');
  String get editCategory => _t('Editar categoria', 'Edit category', 'Editar categoría');
  String get editWallet => _t('Editar conta', 'Edit account', 'Editar cuenta');
  String get selectIcon => _t('Selecionar ícone', 'Select icon', 'Seleccionar ícono');
  String get selectColor => _t('Selecionar cor', 'Select color', 'Seleccionar color');
  String get defaultWallet => _t('Conta padrão', 'Default account', 'Cuenta predeterminada');
  String get currency => _t('Moeda', 'Currency', 'Moneda');
  String get language => _t('Idioma', 'Language', 'Idioma');
  String get currencyTitle => _t('Selecionar moeda', 'Select currency', 'Seleccionar moneda');
  String get languageTitle => _t('Selecionar idioma', 'Select language', 'Seleccionar idioma');
  String get newBudget => _t('Orçamento – ', 'Budget – ', 'Presupuesto – ');

  // ── Auth ─────────────────────────────────────────────────────────────────
  String get login => _t('Entrar', 'Login', 'Iniciar sesión');
  String get register => _t('Criar conta', 'Create account', 'Crear cuenta');
  String get createAccount => _t('Criar Conta', 'Create Account', 'Crear Cuenta');
  String get accountCreated => _t('Conta criada com sucesso! Bem-vindo(a)!', 'Account created successfully! Welcome!', '¡Cuenta creada con éxito! ¡Bienvenido/a!');
  String get enterName => _t('Informe seu nome', 'Enter your name', 'Ingrese su nombre');
  String get emailField => _t('E-mail', 'E-mail', 'E-mail');
  String get invalidEmail => _t('E-mail inválido', 'Invalid e-mail', 'E-mail inválido');
  String get passwordField => _t('Senha', 'Password', 'Contraseña');
  String get continueWithGoogle => _t('Continuar com Google', 'Continue with Google', 'Continuar con Google');
  String get continueWithApple => _t('Continuar com a Apple', 'Continue with Apple', 'Continuar con Apple');
  String get or => _t('OU', 'OR', 'O');

  // ── Budget actions ────────────────────────────────────────────────────────
  String get deleteBudget => _t('Excluir orçamento', 'Delete budget', 'Eliminar presupuesto');
  String get deleteBudgetConfirm => _t(
      'Tem certeza que deseja excluir este orçamento? Esta ação não pode ser desfeita.',
      'Are you sure you want to delete this budget? This action cannot be undone.',
      '¿Está seguro de que desea eliminar este presupuesto? Esta acción no se puede deshacer.');

  // ── Transaction actions ───────────────────────────────────────────────────
  String get deleteTransaction => _t('Excluir lançamento', 'Delete transaction', 'Eliminar transacción');
  String get deleteTransactionConfirm => _t(
      'Tem certeza que deseja excluir este lançamento? Esta ação não pode ser desfeita.',
      'Are you sure you want to delete this transaction? This action cannot be undone.',
      '¿Está seguro de que desea eliminar esta transacción? Esta acción no se puede deshacer.');
  String get errorDeletingTransaction => _t('Erro ao excluir lançamento.', 'Error deleting transaction.', 'Error al eliminar transacción.');

  // ── Invitations ───────────────────────────────────────────────────────────
  String get decline => _t('Recusar', 'Decline', 'Rechazar');
  String get accept => _t('Aceitar', 'Accept', 'Aceptar');

  // ── Notification detection ────────────────────────────────────────────────
  String get detectTransactions => _t('Detectar transações', 'Detect transactions', 'Detectar transacciones');
  String get detectTransactionsDesc => _t(
      'Lê notificações de bancos e sugere lançamentos automáticamente',
      'Reads bank notifications and suggests transactions automatically',
      'Lee notificaciones bancarias y sugiere transacciones automáticamente');
  String get detectTransactionsDialogTitle => _t(
      'Detectar transações automáticamente',
      'Automatically detect transactions',
      'Detectar transacciones automáticamente');
  String get detectTransactionsDialogContent => _t(
      'Permita que o app leia suas notificações para identificar valores de cobranças e pagamentos e sugerir o lançamento automaticamente.\n\nNenhuma notificação é armazenada ou enviada para servidores.',
      'Allow the app to read your notifications to identify payment amounts and automatically suggest transactions.\n\nNo notifications are stored or sent to servers.',
      'Permita que la app lea sus notificaciones para identificar montos de cobros y pagos y sugerir el registro automáticamente.\n\nNinguna notificación se almacena ni se envía a servidores.');
  String get notNow => _t('Agora não', 'Not now', 'Ahora no');
  String get enable => _t('Ativar', 'Enable', 'Activar');

  // ── Subscriptions (detected recurring charges) ─────────────────────────────
  String get subscriptions => _t('Assinaturas', 'Subscriptions', 'Suscripciones');
  String get subscriptionsDesc => _t(
      'Cobranças recorrentes detectadas nos seus lançamentos',
      'Recurring charges detected in your transactions',
      'Cargos recurrentes detectados en tus transacciones');
  String get subscriptionsMonthlyTotal => _t(
      'Total mensal estimado', 'Estimated monthly total', 'Total mensual estimado');
  String get subscriptionsEmpty => _t(
      'Nenhuma assinatura detectada',
      'No subscriptions detected',
      'No se detectaron suscripciones');
  String get subscriptionsEmptyDesc => _t(
      'Conforme você registra cobranças que se repetem (streaming, academia, seguros…), elas aparecem aqui automaticamente.',
      'As you record charges that repeat (streaming, gym, insurance…), they show up here automatically.',
      'A medida que registras cargos que se repiten (streaming, gimnasio, seguros…), aparecen aquí automáticamente.');
  String get subscriptionCreateRecurring =>
      _t('Criar recorrência', 'Create recurring', 'Crear recurrencia');
  String get subscriptionIgnore => _t('Ignorar', 'Ignore', 'Ignorar');
  String subscriptionOccurrences(int n) =>
      _t('$n cobranças', '$n charges', '$n cargos');
  String get subscriptionLastCharge => _t('Última', 'Last', 'Último');
  String get subscriptionNextCharge => _t('Próxima', 'Next', 'Próximo');
  String get subscriptionRecurringCreated => _t(
      'Recorrência criada com sucesso',
      'Recurring transaction created',
      'Recurrencia creada con éxito');
  String get subscriptionIgnored =>
      _t('Assinatura ignorada', 'Subscription ignored', 'Suscripción ignorada');
  String get undo => _t('Desfazer', 'Undo', 'Deshacer');

  // ── Receipt attachments (Pro) ──────────────────────────────────────────────
  String get attachReceipt =>
      _t('Anexar comprovante', 'Attach receipt', 'Adjuntar comprobante');
  String get attachReceiptDesc => _t(
      'Guarde a foto ou o PDF do comprovante junto ao lançamento.',
      'Keep a photo or PDF of the receipt with the transaction.',
      'Guarda la foto o el PDF del comprobante junto a la transacción.');
  String get attachments => _t('Comprovantes', 'Receipts', 'Comprobantes');
  String get takePhoto => _t('Tirar foto', 'Take photo', 'Tomar foto');
  String get chooseFromGallery =>
      _t('Escolher da galeria', 'Choose from gallery', 'Elegir de la galería');
  String get choosePdf => _t('Escolher PDF', 'Choose PDF', 'Elegir PDF');
  String get attachReceiptError => _t(
      'Não foi possível anexar o comprovante',
      'Could not attach the receipt',
      'No se pudo adjuntar el comprobante');

  // ── Credit card (invoices/faturas) ─────────────────────────────────────────
  String get creditCard =>
      _t('Cartão de crédito', 'Credit card', 'Tarjeta de crédito');
  String get creditLimit =>
      _t('Limite do cartão', 'Credit limit', 'Límite de la tarjeta');
  String get availableLimit =>
      _t('Limite disponível', 'Available limit', 'Límite disponible');
  String get closingDay => _t('Dia de fechamento', 'Closing day', 'Día de cierre');
  String get dueDay => _t('Dia de vencimento', 'Due day', 'Día de vencimiento');
  String get invoices => _t('Faturas', 'Invoices', 'Facturas');
  String get currentInvoice =>
      _t('Fatura atual', 'Current invoice', 'Factura actual');
  String get invoiceOpen => _t('Aberta', 'Open', 'Abierta');
  String get invoiceClosed => _t('Fechada', 'Closed', 'Cerrada');
  String get invoicePaid => _t('Paga', 'Paid', 'Pagada');
  String get invoiceOverdue => _t('Vencida', 'Overdue', 'Vencida');
  String get invoiceCloses => _t('Fecha em', 'Closes', 'Cierra el');
  String get invoiceDue => _t('Vence em', 'Due', 'Vence el');
  String get invoiceRemaining =>
      _t('Falta pagar', 'Remaining', 'Falta pagar');
  String get payInvoice => _t('Pagar fatura', 'Pay invoice', 'Pagar factura');
  String get payInvoiceFrom =>
      _t('Pagar com', 'Pay from', 'Pagar con');
  String get invoicePaidSuccess =>
      _t('Fatura paga com sucesso', 'Invoice paid', 'Factura pagada');
  String get noInvoiceTransactions => _t('Nenhum lançamento nesta fatura',
      'No transactions in this invoice', 'Sin transacciones en esta factura');
  String get installments => _t('Parcelas', 'Installments', 'Cuotas');
  String get installmentSingle => _t('À vista', 'Single', 'Al contado');
  String get viewInvoices => _t('Ver faturas', 'View invoices', 'Ver facturas');
  String get creditCardNoWallet => _t(
      'Selecione uma conta para pagar a fatura',
      'Select an account to pay the invoice',
      'Selecciona una cuenta para pagar la factura');
  String get cards => _t('Cartões', 'Cards', 'Tarjetas');
  String get newCard => _t('Novo cartão', 'New card', 'Nueva tarjeta');
  String get addCardPurchase =>
      _t('Lançar compra', 'Add purchase', 'Registrar compra');
  String get noCards =>
      _t('Nenhum cartão cadastrado', 'No cards yet', 'Sin tarjetas');
  String get noCardsDesc => _t(
      'Adicione seu cartão de crédito para lançar compras e controlar a fatura.',
      'Add your credit card to log purchases and track the invoice.',
      'Agrega tu tarjeta de crédito para registrar compras y controlar la factura.');
  String get cardsTotalOwed =>
      _t('Total das faturas', 'Total owed', 'Total de facturas');
  String get selectBank =>
      _t('Banco ou bandeira', 'Bank or network', 'Banco o red');
  String get cardName => _t('Nome do cartão', 'Card name', 'Nombre de la tarjeta');
  String get banksBrazil =>
      _t('Bancos do Brasil', 'Brazilian banks', 'Bancos de Brasil');
  String get banksIntl =>
      _t('Internacionais', 'International', 'Internacionales');

  // ── Bills / due-date reminders (contas a pagar e receber) ──────────────────
  String get bills => _t('Contas a pagar', 'Bills', 'Cuentas por pagar');
  String get billsDesc => _t(
      'Contas a pagar e receber com lembrete de vencimento',
      'Bills to pay and receive with due-date reminders',
      'Cuentas por pagar y cobrar con recordatorio de vencimiento');
  String get billAdd => _t('Nova conta', 'New bill', 'Nueva cuenta');
  String get billEdit => _t('Editar conta', 'Edit bill', 'Editar cuenta');
  String get billNameField => _t('Descrição', 'Description', 'Descripción');
  String get billDueDate => _t('Vencimento', 'Due date', 'Vencimiento');
  String get billType => _t('Tipo', 'Type', 'Tipo');
  String get billPayable => _t('A pagar', 'To pay', 'Por pagar');
  String get billReceivable => _t('A receber', 'To receive', 'Por cobrar');
  String get billReminder => _t('Lembrete', 'Reminder', 'Recordatorio');
  String get billReminderNone =>
      _t('Sem lembrete', 'No reminder', 'Sin recordatorio');
  String get billReminderSameDay => _t('No dia', 'Same day', 'El mismo día');
  String billReminderDaysBefore(int n) => _t(
      '$n dia${n > 1 ? 's' : ''} antes', '$n day${n > 1 ? 's' : ''} before',
      '$n día${n > 1 ? 's' : ''} antes');
  String get billRepeatMonthly =>
      _t('Repetir todo mês', 'Repeat monthly', 'Repetir cada mes');
  String get billMarkPaid => _t('Marcar como paga', 'Mark as paid', 'Marcar como pagada');
  String get billMarkReceived =>
      _t('Marcar como recebida', 'Mark as received', 'Marcar como cobrada');
  String get billPaid => _t('Paga', 'Paid', 'Pagada');
  String get billOverdue => _t('Vencida', 'Overdue', 'Vencida');
  String get billDueToday => _t('Vence hoje', 'Due today', 'Vence hoy');
  String billDueInDays(int n) =>
      _t('Vence em $n dias', 'Due in $n days', 'Vence en $n días');
  String get billsEmpty =>
      _t('Nenhuma conta cadastrada', 'No bills yet', 'Sin cuentas registradas');
  String get billsEmptyDesc => _t(
      'Cadastre contas a pagar ou receber e o app te lembra antes do vencimento.',
      'Add bills to pay or receive and the app reminds you before the due date.',
      'Agrega cuentas por pagar o cobrar y la app te recuerda antes del vencimiento.');
  String get billPaidSuccess => _t(
      'Conta baixada e lançada', 'Bill settled and recorded',
      'Cuenta liquidada y registrada');
  String get billsUpcoming => _t('A vencer', 'Upcoming', 'Por vencer');
  String get billsPaidSection => _t('Pagas', 'Paid', 'Pagadas');

  // ── Investments (portfolio tracker, Pro) ────────────────────────────────────
  String get investments => _t('Investimentos', 'Investments', 'Inversiones');
  String get investmentsDesc => _t(
      'Acompanhe ações, cripto e seus ganhos/perdas em tempo real',
      'Track stocks, crypto and your gains/losses in real time',
      'Sigue acciones, cripto y tus ganancias/pérdidas en tiempo real');
  String get portfolioValue =>
      _t('Patrimônio investido', 'Portfolio value', 'Patrimonio invertido');
  String get investUnrealized =>
      _t('Ganho/perda', 'Gain/loss', 'Ganancia/pérdida');
  String get investRealized =>
      _t('Lucro realizado', 'Realized profit', 'Ganancia realizada');
  String get investToday => _t('Hoje', 'Today', 'Hoy');
  String get investAddAsset =>
      _t('Adicionar ativo', 'Add asset', 'Agregar activo');
  String get investAddTrade =>
      _t('Registrar operação', 'Add trade', 'Registrar operación');
  String get investBuy => _t('Compra', 'Buy', 'Compra');
  String get investSell => _t('Venda', 'Sell', 'Venta');
  String get investQuantity => _t('Quantidade', 'Quantity', 'Cantidad');
  String get investUnitPrice =>
      _t('Preço unitário', 'Unit price', 'Precio unitario');
  String get investFetchQuote =>
      _t('Usar cotação atual', 'Use current quote', 'Usar cotización actual');
  String get investFetchQuoteError => _t('Não foi possível obter a cotação atual',
      "Couldn't fetch the current quote", 'No se pudo obtener la cotización actual');
  String get investFees => _t('Taxas', 'Fees', 'Comisiones');
  String get investAvgCost => _t('Preço médio', 'Avg. cost', 'Precio medio');
  String get investMarketValue =>
      _t('Valor de mercado', 'Market value', 'Valor de mercado');
  String get investKindStockBr => _t('Ação (B3)', 'Stock (B3)', 'Acción (B3)');
  String get investKindStockUs =>
      _t('Ação (EUA)', 'Stock (US)', 'Acción (EE.UU.)');
  String get investKindCrypto => _t('Cripto', 'Crypto', 'Cripto');
  String get investEmpty =>
      _t('Nenhum ativo cadastrado', 'No assets yet', 'Sin activos');
  String get investEmptyDesc => _t(
      'Adicione ações, FIIs ou cripto e registre suas compras para acompanhar quanto está ganhando.',
      'Add stocks, REITs or crypto and log your buys to track your gains.',
      'Agrega acciones, FIIs o cripto y registra tus compras para seguir tus ganancias.');
  String get investSearch => _t('Buscar ticker ou nome', 'Search ticker or name',
      'Buscar ticker o nombre');
  String get investDisclaimer => _t(
      'Valores informativos, com atraso de ~15 min. Não é recomendação de investimento.',
      'Informational values, ~15 min delayed. Not investment advice.',
      'Valores informativos, con ~15 min de retraso. No es recomendación de inversión.');
  String get investQuotesUpdated =>
      _t('Cotações de', 'Quotes from', 'Cotizaciones de');
  String get investNoQuote =>
      _t('Sem cotação', 'No quote', 'Sin cotización');
  String get investWeek52 =>
      _t('Faixa 52 semanas', '52-week range', 'Rango 52 semanas');
  String get investDayRange => _t('Faixa do dia', 'Day range', 'Rango del día');
  String get investTradesHistory =>
      _t('Histórico de operações', 'Trade history', 'Historial de operaciones');
  String get investNoTrades => _t('Nenhuma operação registrada',
      'No trades recorded', 'Sin operaciones registradas');
  String get investRemoveAsset =>
      _t('Remover ativo', 'Remove asset', 'Quitar activo');
  String get investAddToPortfolio => _t('Adicionar à carteira',
      'Add to portfolio', 'Agregar a la cartera');
  String get investAddToPortfolioDesc => _t(
      'Informe a quantidade e o preço para acompanhar este ativo na sua carteira.',
      'Enter the quantity and price to track this asset in your portfolio.',
      'Ingresa la cantidad y el precio para seguir este activo en tu cartera.');

  // ── Workspaces ("Carteiras" PF/PJ) ─────────────────────────────────────────
  String get workspaces => _t('Carteiras', 'Spaces', 'Espacios');
  String get workspacePersonal => _t('Pessoal (PF)', 'Personal', 'Personal');
  String get workspaceBusiness =>
      _t('Empresarial (PJ)', 'Business', 'Empresarial');
  String get allWorkspaces => _t('Todas juntas', 'All together', 'Todas juntas');
  String get allWorkspacesHint => _t(
      'Visão consolidada de todas as suas Carteiras (somente leitura de totais). Novos lançamentos vão para a Carteira Pessoal.',
      'Consolidated view of all your spaces. New entries go to the Personal space.',
      'Vista consolidada de todos tus espacios. Los nuevos registros van al espacio Personal.');
  String get newWorkspace => _t('Nova Carteira', 'New space', 'Nuevo espacio');
  String get manageWorkspaces =>
      _t('Gerenciar Carteiras', 'Manage spaces', 'Gestionar espacios');
  String get workspaceName =>
      _t('Nome da Carteira', 'Space name', 'Nombre del espacio');
  String get workspaceType => _t('Tipo', 'Type', 'Tipo');
  String get workspaceSharedWithMe =>
      _t('Compartilhada comigo', 'Shared with me', 'Compartida conmigo');
  String get workspaceSwitchTo =>
      _t('Trocar de Carteira', 'Switch space', 'Cambiar de espacio');
  String get deleteWorkspace =>
      _t('Excluir Carteira', 'Delete space', 'Eliminar espacio');
  String get deleteWorkspaceWarning => _t(
      'TODOS os lançamentos, contas, categorias, orçamentos, metas e demais dados desta Carteira serão apagados de forma permanente.',
      'ALL transactions, accounts, categories, budgets, goals and other data in this space will be permanently deleted.',
      'TODOS los registros, cuentas, categorías, presupuestos, metas y demás datos de este espacio se eliminarán de forma permanente.');
  String get cannotDeleteDefaultWorkspace => _t(
      'A Carteira Pessoal (padrão) não pode ser excluída.',
      'The default Personal space cannot be deleted.',
      'El espacio Personal (predeterminado) no se puede eliminar.');
  String get archiveWorkspace => _t('Arquivar', 'Archive', 'Archivar');
  String get unarchiveWorkspace => _t('Desarquivar', 'Unarchive', 'Desarchivar');
  String get workspacesDesc => _t(
      'Separe Pessoal (PF) e Empresarial (PJ) e gerencie cada uma de forma independente',
      'Separate Personal and Business ledgers and manage each independently',
      'Separa Personal y Empresarial y gestiona cada uno de forma independiente');

  // ── Tools hub ──────────────────────────────────────────────────────────────
  String get toolsHub =>
      _t('Ferramentas & Recursos', 'Tools & Features', 'Herramientas y recursos');
  String get toolsHubDesc => _t(
      'Investimentos, contas, assinaturas e mais',
      'Investments, bills, subscriptions and more',
      'Inversiones, cuentas, suscripciones y más');
  String get toolsMarket =>
      _t('Investimentos & mercado', 'Investments & market', 'Inversiones y mercado');
  String get toolsOrganize => _t('Organização', 'Organization', 'Organización');

  // ── Currency converter (Pro) ───────────────────────────────────────────────
  String get currencyConverter =>
      _t('Conversor de moedas', 'Currency converter', 'Conversor de monedas');
  String get currencyConverterDesc => _t(
      'Converta valores entre moedas com cotação real',
      'Convert amounts between currencies with live rates',
      'Convierte montos entre monedas con cotización real');
  String get amount => _t('Valor', 'Amount', 'Monto');
  String get currencyFrom => _t('De', 'From', 'De');
  String get currencyTo => _t('Para', 'To', 'A');
  String get currencySwap => _t('Inverter', 'Swap', 'Invertir');
  String get currencyRefreshRates =>
      _t('Atualizar cotações', 'Refresh rates', 'Actualizar cotizaciones');
  String get currencyRatesUpdatedAt =>
      _t('Cotações de', 'Rates from', 'Cotizaciones de');
  String get currencyRatesLoading => _t(
      'Buscando cotações…', 'Fetching rates…', 'Buscando cotizaciones…');

  // ── Common ────────────────────────────────────────────────────────────────
  String get clear => _t('Limpar', 'Clear', 'Limpiar');

  // ── App Update ───────────────────────────────────────────────────────────
  String get updateAvailable => _t(
      'Nova versão disponível! Atualize agora.',
      'New version available! Update now.',
      '¡Nueva versión disponible! Actualiza ahora.');
  String get updateNow => _t('Atualizar', 'Update', 'Actualizar');
  String get dismiss => _t('Fechar', 'Dismiss', 'Cerrar');

  // ── Common ───────────────────────────────────────────────────────────────
  String get errorGeneric => _t('Erro desconhecido.', 'Unknown error.', 'Error desconocido.');
  String get confirm => _t('Confirmar', 'Confirm', 'Confirmar');

  // ── App lock (PIN + biometrics) ──────────────────────────────────────────
  String get security => _t('Segurança', 'Security', 'Seguridad');
  String get appLockTitle =>
      _t('Bloqueio do app', 'App lock', 'Bloqueo de la app');
  String get appLockSubtitle => _t(
      'Exige PIN ou biometria para abrir o app',
      'Require PIN or biometrics to open the app',
      'Exige PIN o biometría para abrir la app');
  String get appLockUnavailableWeb => _t(
      'Disponível apenas no aplicativo móvel',
      'Available only on the mobile app',
      'Disponible solo en la app móvil');
  String get useBiometrics => _t(
      'Usar biometria', 'Use biometrics', 'Usar biometría');
  String get useBiometricsDesc => _t(
      'Digital ou reconhecimento facial',
      'Fingerprint or face recognition',
      'Huella o reconocimiento facial');
  String get changePin => _t('Alterar PIN', 'Change PIN', 'Cambiar PIN');
  String get createPinTitle =>
      _t('Criar PIN', 'Create PIN', 'Crear PIN');
  String get createPinSubtitle => _t(
      'Escolha um PIN de 4 dígitos para proteger o app',
      'Choose a 4-digit PIN to protect the app',
      'Elige un PIN de 4 dígitos para proteger la app');
  String get confirmPinTitle =>
      _t('Confirmar PIN', 'Confirm PIN', 'Confirmar PIN');
  String get confirmPinSubtitle => _t(
      'Digite o PIN novamente para confirmar',
      'Enter the PIN again to confirm',
      'Ingresa el PIN nuevamente para confirmar');
  String get pinsDoNotMatch => _t(
      'Os PINs não coincidem. Tente novamente.',
      'PINs don\'t match. Try again.',
      'Los PIN no coinciden. Inténtalo de nuevo.');
  String get pinEnabled => _t(
      'Bloqueio do app ativado!',
      'App lock enabled!',
      '¡Bloqueo de la app activado!');
  String get pinIncorrect =>
      _t('PIN incorreto', 'Incorrect PIN', 'PIN incorrecto');
  String get enterPinTitle =>
      _t('Digite seu PIN', 'Enter your PIN', 'Ingresa tu PIN');
  String get enterPinSubtitle => _t(
      'Desbloqueie para acessar o app',
      'Unlock to access the app',
      'Desbloquea para acceder a la app');
  String get unlockWithBiometricsReason => _t(
      'Desbloqueie o Fintab',
      'Unlock Fintab',
      'Desbloquea Fintab');
  String get forgotPin =>
      _t('Esqueci o PIN', 'Forgot PIN', 'Olvidé el PIN');
  String get forgotPinTitle =>
      _t('Esqueci o PIN', 'Forgot PIN', 'Olvidé el PIN');
  String get forgotPinMessage => _t(
      'Para redefinir o PIN você precisa sair e entrar novamente com sua senha. Seus dados permanecem salvos.',
      'To reset the PIN you need to sign out and sign in again with your password. Your data will be preserved.',
      'Para restablecer el PIN debes cerrar sesión y volver a iniciarla con tu contraseña. Tus datos se conservan.');
  String get disableAppLockTitle => _t(
      'Desativar bloqueio?',
      'Disable app lock?',
      '¿Desactivar bloqueo de la app?');
  String get disableAppLockMessage => _t(
      'O app deixará de pedir PIN ou biometria ao abrir.',
      'The app will no longer ask for PIN or biometrics on open.',
      'La app dejará de pedir PIN o biometría al abrir.');

  // ── Data (Import / Export) ───────────────────────────────────────────────
  String get dataSection => _t('Dados', 'Data', 'Datos');
  String get importTitle =>
      _t('Importar extrato', 'Import statement', 'Importar extracto');
  String get importSubtitle => _t(
      'Traga transações de arquivos OFX ou CSV do banco',
      'Bring transactions from OFX or CSV bank files',
      'Trae transacciones desde archivos OFX o CSV del banco');
  String get importPickFileTitle =>
      _t('Arquivo', 'File', 'Archivo');
  String get importPickFileDesc => _t(
      'Selecione um arquivo .ofx ou .csv exportado do seu banco',
      'Choose an .ofx or .csv file exported from your bank',
      'Selecciona un archivo .ofx o .csv exportado desde tu banco');
  String get importSelectFile =>
      _t('Selecionar arquivo', 'Select file', 'Seleccionar archivo');
  String get importDefaults =>
      _t('Padrões da importação', 'Import defaults', 'Predeterminados');
  String get importTargetWallet =>
      _t('Conta de destino', 'Target account', 'Cuenta destino');
  String get importIncomeCategory => _t('Categoria padrão (receitas)',
      'Default category (income)', 'Categoría por defecto (ingresos)');
  String get importExpenseCategory => _t('Categoria padrão (despesas)',
      'Default category (expenses)', 'Categoría por defecto (gastos)');
  String get importSelectAll =>
      _t('Selecionar todas', 'Select all', 'Seleccionar todas');
  String get importDeselectAll => _t(
      'Desmarcar todas', 'Deselect all', 'Deseleccionar todas');
  String importPreviewTitle(int n) => _t(
      'Transações detectadas ($n)',
      'Detected transactions ($n)',
      'Transacciones detectadas ($n)');
  String importConfirm(int n) => _t(
      'Importar $n transações',
      'Import $n transactions',
      'Importar $n transacciones');

  String get exportTitle =>
      _t('Exportar extrato', 'Export statement', 'Exportar extracto');
  String get exportSubtitle => _t(
      'Gere PDF ou Excel das suas transações',
      'Generate PDF or Excel of your transactions',
      'Genera PDF o Excel de tus transacciones');
  String get exportPeriod => _t('Período', 'Period', 'Período');
  String get exportCurrentMonth =>
      _t('Mês atual', 'Current month', 'Mes actual');
  String get exportPreviousMonth =>
      _t('Mês anterior', 'Previous month', 'Mes anterior');
  String get exportCurrentYear =>
      _t('Ano atual', 'Current year', 'Año actual');
  String get exportAllTime =>
      _t('Todos os lançamentos', 'All transactions', 'Todas las transacciones');
  String get exportCustomRange => _t(
      'Período personalizado', 'Custom range', 'Período personalizado');
  String get exportPickRange =>
      _t('Escolher', 'Pick', 'Elegir');
  String get exportFormat => _t('Formato', 'Format', 'Formato');
  String get exportPdfDesc => _t(
      'Relatório pronto para impressão ou envio',
      'Printable / shareable report',
      'Informe listo para imprimir o enviar');
  String get exportExcelDesc => _t(
      'Planilha editável com totais',
      'Editable spreadsheet with totals',
      'Hoja editable con totales');
  String get exportSummary => _t('Resumo', 'Summary', 'Resumen');
  String exportTransactionsCount(int n) => _t(
      '$n transações no período',
      '$n transactions in period',
      '$n transacciones en el período');
  String get exportGenerate =>
      _t('Gerar e compartilhar', 'Generate and share', 'Generar y compartir');
  String get exportNoTransactions => _t(
      'Nenhuma transação no período selecionado.',
      'No transactions in the selected period.',
      'No hay transacciones en el período seleccionado.');

  // ── Financial Health ─────────────────────────────────────────────────────
  String get financialHealthTitle =>
      _t('Saúde financeira', 'Financial health', 'Salud financiera');
  String get financialHealthSubtitle => _t(
      'Score de 0 a 100 baseado nos seus hábitos',
      'Score from 0 to 100 based on your habits',
      'Puntuación de 0 a 100 según tus hábitos');
  String get financialHealthFactors =>
      _t('Fatores avaliados', 'Evaluated factors', 'Factores evaluados');
  String get financialHealthRecommendations =>
      _t('Recomendações', 'Recommendations', 'Recomendaciones');

  String get financialHealthLevelExcellent =>
      _t('Excelente', 'Excellent', 'Excelente');
  String get financialHealthLevelGood => _t('Bom', 'Good', 'Bueno');
  String get financialHealthLevelFair =>
      _t('Razoável', 'Fair', 'Aceptable');
  String get financialHealthLevelAttention =>
      _t('Atenção', 'Needs attention', 'Atención');
  String get financialHealthLevelCritical =>
      _t('Crítico', 'Critical', 'Crítico');

  String get financialFactorSavingsRate =>
      _t('Taxa de poupança', 'Savings rate', 'Tasa de ahorro');
  String get financialFactorEmergencyReserve => _t(
      'Reserva de emergência',
      'Emergency reserve',
      'Reserva de emergencia');
  String get financialFactorBudgetAdherence => _t(
      'Aderência aos orçamentos',
      'Budget adherence',
      'Cumplimiento de presupuestos');
  String get financialFactorGoalMomentum =>
      _t('Progresso de metas', 'Goal momentum', 'Progreso de metas');
  String get financialFactorSpendingConcentration => _t(
      'Diversificação de gastos',
      'Spending diversification',
      'Diversificación de gastos');

  // ── Onboarding: nível de familiaridade financeira ────────────────────────
  String get literacyOnboardingTitle => _t(
      'Como você se sente com finanças?',
      'How do you feel about finance?',
      '¿Cómo te sientes con las finanzas?');
  String get literacyOnboardingSubtitle => _t(
      'Vamos adaptar o app para você. Você poderá mudar isso depois nas Configurações.',
      'We\'ll tailor the app for you. You can change this later in Settings.',
      'Adaptaremos la app para ti. Podrás cambiarlo después en Configuración.');
  String get literacyLevelBeginner =>
      _t('Iniciante', 'Beginner', 'Principiante');
  String get literacyLevelBeginnerDesc => _t(
      'Estou começando agora — quero dicas e explicações em todo o app.',
      'I\'m just starting — show me tips and explanations everywhere.',
      'Estoy empezando — quiero ver consejos y explicaciones en toda la app.');
  String get literacyLevelIntermediate =>
      _t('Intermediário', 'Intermediate', 'Intermedio');
  String get literacyLevelIntermediateDesc => _t(
      'Já controlo minhas finanças, mas algumas dicas ainda ajudam.',
      'I track my finances, but the occasional tip still helps.',
      'Controlo mis finanzas, pero algunos consejos aún me ayudan.');
  String get literacyLevelAdvanced =>
      _t('Avançado', 'Advanced', 'Avanzado');
  String get literacyLevelAdvancedDesc => _t(
      'Tenho experiência — quero a interface limpa, sem dicas.',
      'I\'m experienced — keep the UI clean, no tips.',
      'Tengo experiencia — quiero la interfaz limpia, sin consejos.');
  String get literacyLevelSettingsTitle => _t(
      'Nível de experiência',
      'Experience level',
      'Nivel de experiencia');
  String get literacyLevelSettingsSubtitle => _t(
      'Controla quando o app mostra dicas explicativas',
      'Controls when the app shows explanatory tips',
      'Controla cuándo la app muestra consejos explicativos');
  String get categorySortSettingsTitle => _t(
      'Ordem das categorias',
      'Category order',
      'Orden de las categorías');
  String get categorySortSettingsSubtitle => _t(
      'Como ordenar despesas e receitas ao lançar',
      'How expenses and income are ordered when adding',
      'Cómo se ordenan gastos e ingresos al registrar');
  String get categorySortTitle => _t(
      'Ordem das categorias',
      'Category order',
      'Orden de las categorías');
  String get categorySortMostUsed =>
      _t('Mais usadas', 'Most used', 'Más usadas');
  String get categorySortMostUsedDesc => _t(
      'As categorias que você mais usa aparecem primeiro',
      'The categories you use most appear first',
      'Las categorías que más usas aparecen primero');
  String get categorySortAlphabetical =>
      _t('Alfabética', 'Alphabetical', 'Alfabética');
  String get categorySortAlphabeticalDesc =>
      _t('De A a Z', 'From A to Z', 'De la A a la Z');
  String get helpHintLabel =>
      _t('Saiba mais', 'Learn more', 'Saber más');
  String get gotIt => _t('Entendi', 'Got it', 'Entendido');
  String get continueAction => _t('Continuar', 'Continue', 'Continuar');

  // ── Help hints (conteúdo das explicações) ────────────────────────────────
  String get hintBudgetTitle => _t(
      'O que é um orçamento?',
      'What is a budget?',
      '¿Qué es un presupuesto?');
  String get hintBudgetBody => _t(
      'Um orçamento é um limite mensal de gastos que você define para uma categoria (ex.: Alimentação até R\$ 800). O app avisa quando o gasto se aproxima do limite.',
      'A budget is a monthly spending limit you set for a category (e.g., Food up to \$800). The app warns you as spending approaches the limit.',
      'Un presupuesto es un límite mensual de gastos que defines para una categoría (ej.: Alimentación hasta \$800). La app te avisa cuando el gasto se acerca al límite.');

  String get hintGoalTitle => _t(
      'O que é uma meta?',
      'What is a goal?',
      '¿Qué es una meta?');
  String get hintGoalBody => _t(
      'Uma meta é um objetivo financeiro com um valor a alcançar (ex.: juntar R\$ 5.000 para uma viagem). Você acompanha o progresso aos poucos.',
      'A goal is a financial target with an amount to reach (e.g., save \$5,000 for a trip). You track progress over time.',
      'Una meta es un objetivo financiero con un monto a alcanzar (ej.: ahorrar \$5.000 para un viaje). Sigues el progreso poco a poco.');

  String get hintRecurringTitle => _t(
      'O que é uma recorrência?',
      'What is a recurring transaction?',
      '¿Qué es una recurrencia?');
  String get hintRecurringBody => _t(
      'Recorrências são transações que se repetem automaticamente (ex.: salário todo dia 5, aluguel todo dia 10). Você cadastra uma vez e o app lança nos meses seguintes.',
      'Recurring transactions repeat automatically (e.g., salary on the 5th, rent on the 10th). Set it once and the app posts them every period.',
      'Las recurrencias son transacciones que se repiten automáticamente (ej.: salario el día 5, alquiler el día 10). Las creas una vez y la app las registra cada período.');

  String get hintWalletTitle => _t(
      'O que é uma conta?',
      'What is an account?',
      '¿Qué es una cuenta?');
  String get hintWalletBody => _t(
      'Conta é onde seu dinheiro está: conta corrente, dinheiro vivo, cartão pré-pago etc. Você pode ter várias e ver o saldo de cada uma separadamente.',
      'An account is where your money lives: checking account, cash, prepaid card, etc. You can have several and see each balance separately.',
      'Una cuenta es dónde está tu dinero: cuenta corriente, efectivo, tarjeta prepago, etc. Puedes tener varias y ver el saldo de cada una.');

  String get hintCategoryTitle => _t(
      'O que é uma categoria?',
      'What is a category?',
      '¿Qué es una categoría?');
  String get hintCategoryBody => _t(
      'Categorias agrupam suas transações por tipo (Alimentação, Transporte, Salário…). Servem para você entender para onde o dinheiro vai.',
      'Categories group your transactions by type (Food, Transport, Salary…). They help you see where the money goes.',
      'Las categorías agrupan tus transacciones por tipo (Alimentación, Transporte, Salario…). Sirven para ver a dónde va el dinero.');

  String get hintIncomeExpenseTitle => _t(
      'Receita ou Despesa?',
      'Income or Expense?',
      '¿Ingreso o Gasto?');
  String get hintIncomeExpenseBody => _t(
      'Receita é dinheiro que entra (salário, vendas, presentes). Despesa é dinheiro que sai (compras, contas, lazer). A diferença mostra se você está sobrando ou faltando ao fim do mês.',
      'Income is money coming in (salary, sales, gifts). Expense is money going out (purchases, bills, leisure). The difference shows if you ended the month in surplus or deficit.',
      'Ingreso es el dinero que entra (salario, ventas, regalos). Gasto es el dinero que sale (compras, cuentas, ocio). La diferencia muestra si terminaste el mes con excedente o déficit.');

  String get hintFinancialHealthTitle => _t(
      'O que é Saúde Financeira?',
      'What is Financial Health?',
      '¿Qué es la Salud Financiera?');
  String get hintFinancialHealthBody => _t(
      'É uma nota de 0 a 100 que resume seus hábitos: o quanto você poupa, se tem reserva de emergência, se respeita os orçamentos e se progride nas metas.',
      'A 0–100 score that summarizes your habits: how much you save, whether you have an emergency fund, if you stick to budgets and make progress on goals.',
      'Es una nota de 0 a 100 que resume tus hábitos: cuánto ahorras, si tienes fondo de emergencia, si cumples los presupuestos y avanzas en las metas.');

  String get hintTagTitle =>
      _t('O que são etiquetas?', 'What are tags?', '¿Qué son las etiquetas?');
  String get hintTagBody => _t(
      'Etiquetas (tags) são marcadores livres que você adiciona a uma transação para filtrar depois (ex.: "viagem-2026", "presente-aniversário").',
      'Tags are free labels you attach to a transaction so you can filter later (e.g., "trip-2026", "birthday-gift").',
      'Las etiquetas son marcadores libres que añades a una transacción para filtrar después (ej.: "viaje-2026", "regalo-cumpleaños").');
}

// ─────────────────────────────────────────────────────────────────────────────
// Delegate
// ─────────────────────────────────────────────────────────────────────────────

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['pt', 'en', 'es'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
