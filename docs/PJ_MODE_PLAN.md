# Plano de Implementação — Modo Pessoal + Empresarial (PJ) no Fintab

## 1. Resumo da decisão + porquê

**Abordagem escolhida: `workspaceId`-field** (adicionar um campo `workspaceId` às coleções financeiras, mantendo `userId` intacto como fronteira de segurança), com **um empréstimo de UX da abordagem reuse-collaborator**: o seletor unifica, numa única lista, os workspaces próprios (Pessoal/Empresa) e as contas compartilhadas em que o usuário é colaborador.

**Por quê:**

- **Segurança e migração sem perda de dados (o critério dominante para um app de dinheiro).** `userId` continua sendo a fronteira imutável de segurança; `workspaceId` é apenas uma fronteira de organização/consulta. O pior caso de um filtro esquecido é os *seus próprios* dois ledgers se misturarem na *sua* tela (recuperável) — nunca vazamento entre usuários. O backfill é uma marcação in-place, idempotente e reversível, com fallback cliente `ausente→padrão` que elimina o risco clássico "os dados sumiram".
- **Sem Blaze.** Ship 100% client-side; não depende de Cloud Functions (que hoje estão desabilitadas, conforme memória).
- **Reuso máximo.** Regras, sharing, subscriptions e deleção continuam funcionando keyed em `userId`. `masterUserId`/`effectiveUserId` **não** são sobrecarregados — evitamos o footgun de `isMasterProvider` quebrar quando o usuário entra no próprio ledger "Empresa".
- **Convivência com colaboração é automática.** Como `workspaces` carrega `userId=owner`, um colaborador vê os workspaces do master de graça (compartilhamento é account-wide — decisão de produto explícita, ver §8).

A abordagem *reuse-collaborator* é mais barata mas transforma `userId` num valor de escopo controlado pelo cliente (risco permanente de integridade); a *subcollection* é a arquitetura mais limpa no fim, mas exige mover fisicamente todos os documentos + Cloud Functions/Blaze — inaceitável para lançar agora. Guardamos o modelo de membership/subcollection como alvo de v2 (sharing por workspace com papéis) quando Blaze estiver ligado.

---

## 2. Modelo de dados e mudanças exatas no Firestore

### 2.1 Nova coleção `workspaces/{workspaceId}`

Mesma "forma" de propriedade das coleções financeiras (para herdar as regras de colaborador de graça):

```
workspaces/{autoId} {
  userId:     string     // uid do DONO (== effectiveUserId). NÃO o uid do colaborador.
  name:       string     // "Pessoal", "Empresa / MEI"
  type:       string     // 'personal' | 'business'
  color:      string?    // chave de cor/ícone do chip (opcional)
  isDefault:  bool       // exatamente um true por userId (o ledger "Pessoal")
  order:      int
  archived:   bool
  createdAt:  timestamp
}
```

### 2.2 Novo campo nas 8 coleções de ledger

Adicionar `workspaceId: string` a: **transactions, wallets, budgets, categories, goals, recurring_transactions, category_rules, bills**.

**Não tocar:** `notification_backlog` (per-uid real) e `subscriptions/{uid}` (per-conta). Pro e backlog são per-pessoa, não per-workspace, por construção.

### 2.3 Correção do doc-id composto de budget (bug de perda de dados se ignorado)

`BudgetNotifier._budgetId` (`budget_provider.dart:323`) monta `'${_userId}_${categoryId}_${year}-$mm$suffix'`. Dois workspaces com a mesma categoria+mês colidem no **mesmo doc-id → overwrite silencioso entre ledgers**. Mudar para:

```dart
'${_userId}_${_workspaceId}_${categoryId}_${year}-$mm$suffix'
```

`BudgetNotifier` (`budget_provider.dart:312`, `:463`) passa a receber `_workspaceId`. **Legado:** ids antigos (sem workspaceId) continuam válidos e visíveis via fallback `ausente→padrão`; só budgets novos usam o id qualificado. Sem reescrita destrutiva.

### 2.4 Campos em `users/{uid}` (controle de migração/seleção)

```
users/{uid} {
  ...
  defaultWorkspaceId:   string   // id do workspace "Pessoal"
  workspaceMigrationV1: bool     // idempotência do backfill
  captureWorkspaceId:   string   // destino fixo da captura automática (default = defaultWorkspaceId)
}
```

### 2.5 Índices compostos

**Estratégia de lançamento (filtro client-side primeiro) → ZERO índices novos.** Cada root stream mantém apenas `where('userId')` e filtra `workspaceId` no cliente (tratando ausente como padrão). Só na **Fase 4 (opcional, escala)** migramos streams quentes para `where('workspaceId')` server-side + índices `(userId ASC, workspaceId ASC, <campo> ASC)` para: categories `orderBy('name')`, goals/recurring/category_rules `orderBy('createdAt')`, budgets (range de período), transactions (se houver range server-side).

---

## 3. Plano de migração/backfill sem perda de dados

**O perigo:** `where('workspaceId', ==, X)` **não** retorna docs sem o campo. Se o filtro server-side subir antes do backfill, os dados de todos parecem sumir. Firestore não expressa "== X OU campo ausente" numa query. A ordem é load-bearing.

**Estratégia: lazy, dirigida pelo dono, com fallback `ausente→padrão` (sem Blaze):**

1. **Só o dono migra.** Rodar apenas quando `isMasterProvider == true` (`effective_user_provider.dart:40`). Colaboradores nunca escrevem o estado de migração do master.
2. **No primeiro launch do build PJ**, para um master sem doc em `workspaces`: criar o default `{type:'personal', name:'Pessoal', isDefault:true, order:0}` e persistir `defaultWorkspaceId` + `captureWorkspaceId` + `workspaceMigrationV1:true` em `users/{uid}`.
3. **Backfill** marca `workspaceId = defaultWorkspaceId` em todos os docs existentes das 8 coleções, paginado em lotes de ~400 (espelhar `_deleteDocsInChunks`, `auth_remote_datasource.dart:424`). **Idempotente:** `where('userId'==uid)`, pular docs que já têm `workspaceId`.
4. **Leitura com fallback durante a transição.** Cada root stream mantém só `where('userId')` e filtra `workspaceId` no cliente, tratando **ausente** como pertencente ao workspace default. Garante que nenhum doc desapareça, independentemente do progresso do backfill.
5. **Budgets legados:** deixados como default-workspace-owned; só budgets novos usam o id composto (§2.3). Sem reescrita.

**Rollback:** subir o build antigo — os dados marcados são ignorados por ele; nada quebra.

---

## 4. Camada de providers

**Novo arquivo `lib/core/providers/workspace_provider.dart`:**

- `workspacesStreamProvider` — `where('userId', ==, effectiveUserId)`, ordenado por `order`. Colaborador recebe os workspaces do master automaticamente.
- `activeWorkspaceIdProvider` — `StateNotifierProvider<String?>` persistido em SharedPreferences, **chave namespaced por uid** (`active_workspace_<uid>`). Default = `defaultWorkspaceId`. Null = modo legado pré-migração.
- `workspaceScopeProvider` — o valor que todo stream consome: resolve o workspace ativo, valida que ainda existe em `workspacesStreamProvider`, senão volta para o default (guarda contra id órfão em SharedPreferences).
- `activeWorkspaceProvider` — a `WorkspaceEntity` resolvida (para header/label).
- `captureWorkspaceIdProvider` — lê `users/{uid}.captureWorkspaceId`; default = default workspace (§9).
- `canUseWorkspacesProvider` — `isProProvider` (gate da feature).

**Composição com `effectiveUserIdProvider`:** **não** alterar `effectiveUserIdProvider` (`effective_user_provider.dart:25`) — ele deve continuar sendo só identidade-do-dono (subscriptions/referral dependem disso indiretamente). Introduzir um helper `applyWorkspaceScope(items, ref)` (filtro client-side uniforme, com fallback ausente→default) que **todos** os root streams chamam. Owner (`effectiveUserId`) × ledger (`workspaceId`) são ortogonais.

**Root streams a atualizar (aplicar filtro):** `transactionsStreamProvider` (`transactions_provider.dart:47`), `walletsStreamProvider` (`wallets_provider.dart:62`) + `walletsSeedProvider` (`:80`), todos os budget streams (`budget_provider.dart:50,72,178,192,212`) + `dashboardBudgetsStreamProvider` (`dashboard_provider.dart:17`), `categoriesStreamProvider` (`categories_provider.dart:48`) + `categoriesSeedProvider` (`:142`), `goalsStreamProvider` (`goals_provider.dart:24`), `recurringStreamProvider` (`recurring_provider.dart:30`), `categoryRulesStreamProvider` (`category_rules_provider.dart:25`), `billsStreamProvider` (`bills_provider.dart:15`).

**Write notifiers a carimbar `workspaceId`** (ler `workspaceScopeProvider`): `TransactionsNotifier` (`transactions_provider.dart:539/432/481`), `WalletsNotifier` (`wallets_provider.dart:187`), `BudgetNotifier` (`budget_provider.dart:463` + doc-id §2.3), `CategoriesNotifier` (`categories_provider.dart:242`), `GoalsNotifier` (`goals_provider.dart:121`), `RecurringNotifier` (`recurring_provider.dart:129`), `CategoryRulesNotifier` (`category_rules_provider.dart:105`), `BillsNotifier` (`bills_provider.dart:196`). Seed defaults (`wallets_provider.dart:87`, `categories_provider.dart:149`) carimbam o workspace ativo — workspace novo e vazio auto-semeia em si mesmo.

**Recurring generator (sharp edge):** `recurring_provider.dart:154-165` monta `TransactionEntity(userId: rec.userId, …)` **sem** workspace. Deve herdar `workspaceId: rec.workspaceId` — ocorrências geradas caem no ledger da recorrência, não no ativo.

**Agregados derivados isolam de graça** uma vez que os roots estão escopados — sem mudança em `balanceProvider`, `convertedBalanceProvider`, `financialScoreProvider`, budget summaries, goal progress, credit-card, bills, subscription-detection, dashboard totals.

**Estado local (SharedPreferences) a namespacear por workspace ou resetar no switch:**
- `AppSettings.hiddenWalletIds` (`app_settings_provider.dart:153`) → chave por workspace (alimenta `visibleTransactionsProvider`).
- `dismissedSubscriptionsProvider` (`subscriptions_provider.dart:7`) → por workspace.
- Filtros de statement `statementWalletFilterProvider`/`statementCategoryFilterProvider`/`statementTagFilterProvider` (`transactions_provider.dart:161-210`) → **`ref.invalidate` no switch** (guardam ids/categorias/tags inexistentes no outro ledger).
- `selectedMonthProvider` (`selected_month_provider.dart:6`) → persiste, ok.
- `dashboardConfigProvider` → compartilhado entre workspaces (decisão de produto: ok).

**Listener de switch** em `MainScreen`: `ref.listen(activeWorkspaceIdProvider)` que invalida os filtros transitórios e re-empurra o home widget (§9).

---

## 5. Mudanças no firestore.rules

### 5.1 Novo bloco `workspaces` (mesma forma dos ledgers)

```
match /workspaces/{workspaceId} {
  allow read, update, delete: if isSignedIn() && (isOwnerOfExistingDoc() || isCollaboratorOfOwner());
  allow create:               if isSignedIn() && (isCreatingOwnDoc() || isCollaboratorCreatingMastersDoc());
}
```

### 5.2 Corrigir o achado do audit: imutabilidade de `userId` no update

Hoje **só `bills`** fixa `userId` no update (`firestore.rules:162`). Todas as outras coleções permitem `update` só com `isOwnerOfExistingDoc()` — que checa o `userId` do doc *existente* mas nunca restringe o *novo* — então um cliente pode **re-homear um doc para outro uid** no update. Aproveitando que estamos mexendo nesses blocos, aplicar o mesmo pin de `bills` a **transactions, categories, budgets, wallets, goals, recurring_transactions, category_rules**:

```
&& request.resource.data.userId == resource.data.userId   // no update
```

Extrair helper `userIdUnchanged()` para manter DRY.

### 5.3 Higiene de `workspaceId` (opcional, barato)

`workspaceId` **não** precisa ser regra de segurança (é mesmo-dono; a isolação é query-layer). Opcionalmente, pinar `workspaceId` imutável no update (um doc não deve pular de ledger silenciosamente). O `get()` para validar que o `workspaceId` referencia um workspace do mesmo dono custa uma leitura de regra por escrita — **adiar** para o lançamento; o filtro client-side já previne leitura cross-ledger acidental e um dono malicioso só afeta os próprios dados. Recomendação: fazer 5.2 agora, adiar o `get()` de 5.3.

---

## 6. UI

### 6.1 Seletor de workspace

- **Local global (todas as abas):** o `Column` do `MainScreen` acima do `IndexedStack` (`main_screen.dart:609-617` mobile, `:537` web), ao lado do `UpdateBanner`. Não há AppBar global para reusar. Um chip/segmented control slim aqui renderiza em Home/Statement/Planning/Reports — **recomendado**, para os totais em Statement/Reports nunca ficarem ambíguos.
- Alternativa mais visível (Home-only): o `_DarkHeader` do dashboard (`dashboard_screen.dart:309-355`), chip ao lado do avatar.
- Tocar no chip abre um bottom sheet listando: workspaces próprios (com ícone de `type`), **contas compartilhadas em que sou colaborador** (label "Conta de X"), "+ Criar workspace (Empresa/MEI)" (Pro-gated) e "Gerenciar workspaces". Mostrar o chip só quando houver ≥2 contextos (evita clutter para a maioria só-Pessoal).

### 6.2 Criar / renomear / arquivar / excluir

Gerência em **Settings**, nova seção espelhando o card de Sharing (`settings_screen.dart:568-574`), dentro/após `_ProfileInfoCard` (`:252-324`):

- **Criar** (Pro-gated): nome + tipo (Pessoal/Empresa). Cria doc em `workspaces`; workspace novo vazio → seed providers auto-populam wallets+categories.
- **Renomear:** update `name`/`color`.
- **Arquivar** (default seguro): `archived:true`, some do seletor, dados retidos.
- **Excluir** (destrutivo): cascade-delete de todos os docs `userId==owner && workspaceId==wid` nas 8 coleções (reusar o padrão paginado de `_deleteAllUserData`, `auth_remote_datasource.dart:402-413`, adicionando o filtro `workspaceId`). **Bloquear exclusão do `isDefault`**; exigir digitar o nome para confirmar.

### 6.3 Telas afetadas

Sem mudança de lógica se os roots estão escopados — mas smoke-test por workspace nas superfícies de "totais não podem misturar": saldo do dashboard (`convertedBalanceProvider`→`dashboard_screen.dart:383`), linha income/expense (`dashboardMonth*`), sparkline 24 meses (`dashboard_screen.dart:444-470`), budget summary, cards wallet/NetWorth/SafeToSpend/Bills, financial-health score (`main_screen.dart:482`), Statement (all-time + mês), Reports. **Adicionar o nome do workspace ativo** ao header do dashboard e a qualquer relatório exportado.

---

## 7. Gating Pro

- `isProProvider` keyed no **uid real de login** (`subscription_provider.dart:53-68`) → Pro é per-conta e segue o dono por todos os workspaces dele. **Manter exatamente onde está**; não re-keyar para `effectiveUserId`.
- **Gate na feature, não nos dados:** usuário free vive implicitamente no único workspace default "Pessoal" (seletor oculto, `canUseWorkspacesProvider=false`). Pro libera criar/trocar/múltiplos ledgers.
- **Adicionar** "Modo Pessoal + Empresarial (PJ)" à lista de vantagens Pro em `pro_screen.dart` `_FeaturesCard` (`_FeatureRow` com ícone + descrição) — exigido pelo `fintab-app/CLAUDE.md`.
- **Downgrade/lapse (sem perda de dados):** se um usuário com N>1 workspaces perde Pro, **não** apagar workspaces extras. Forçar `activeWorkspaceIdProvider` para o default, ocultar o seletor, mostrar upsell. Dados nos outros ledgers permanecem e reaparecem ao re-assinar. (Espelha a degradação das features Pro atuais.)

---

## 8. Convivência com o compartilhamento/colaborador atual

- **Ortogonal por construção:** `effectiveUserId` responde "de quem são os dados" (dono), `workspaceId` responde "qual ledger". Nunca compartilham campo — aceitar convite e selecionar workspace não se sobrescrevem (o failure mode do atalho de reusar `masterUserId`).
- Como `workspaces` carrega `userId=owner`, **um colaborador vê TODOS os workspaces do master**, incluindo "Empresa". Esse é o default correto para compartilhamento de conta inteira, mas deve ser **explícito ao produto: compartilhamento é account-wide, não per-workspace.** Sharing por workspace (convidar alguém só para "Empresa") é feature muito maior (invitation precisaria de escopo `workspaceId` + regras que filtram acesso do colaborador por workspace) — **fora de escopo v1**.
- `isMasterProvider` continua correto: usuário no próprio "Empresa" ainda tem `effectiveUserId==user.id` (não tocamos `masterUserId`), então o painel de convite / botão "Sair da conta compartilhada" (`settings_screen.dart:1808-1960`) continua funcionando. Esse é o bug concreto que evitamos ao não sobrecarregar `masterUserId`.
- **UX unificada (empréstimo do reuse-collaborator):** o seletor lista os workspaces próprios *e* as contas compartilhadas num só lugar, mas cada dimensão continua no seu campo — só a apresentação é unificada.

---

## 9. Casos de borda

- **Captura automática / notificações** (`main_screen.dart:383-446`, `_autoSaveTransaction`): escritas em background não têm "workspace ativo" confiável (pode estar stale enquanto em background). Usar `captureWorkspaceIdProvider` (default = "Pessoal"); auto-save e drain do backlog carimbam **esse** workspace, não o `activeWorkspaceIdProvider`. `notification_backlog` continua real-uid (`backlog_provider.dart:211`) — sem mudança; só a transaction produzida ganha o capture workspace. Listener nativo start/stop (`main_screen.dart:320,469`) passa a keyar em `user.id` para não churnar a cada switch.
- **Widget Android** (`HomeWidgetService.updateAll`, `main_screen.dart:476-504`): espelha um único ledger. Adicionar **label com o nome do workspace** ao payload e re-empurrar no switch (providers rebuildam). Recomendo refletir o workspace ativo + label (evita ambiguidade no home screen).
- **Referral** (`referral_service.dart`, `referralCodes/…`): account-level, real-uid — intocado, sem filtro de workspace.
- **Exclusão de conta** (`auth_remote_datasource.dart:342-421`): deleção já query por `userId` só, então pega docs de *todos* os workspaces — bom. Mas: (a) adicionar `'workspaces'` a `_userDataCollections`; e (b) **corrigir o gap pré-existente** — `'bills'` e `'category_rules'` faltam nessa lista (`:343-351`), ficando órfãos na exclusão (risco LGPD/GDPR + App Store 5.1.1(v)). Adicionar os três agora.
- **Seed de workspace novo:** `walletsSeedProvider`/`categoriesSeedProvider` disparam quando o stream (agora escopado) está vazio — garantir que a checagem de vazio e as escritas de seed usem `(effectiveUserId, activeWorkspaceId)`, para semear uma vez, não repetidamente. Enhancement futuro: set de categorias empresariais (Faturamento, Impostos/DAS, Pró-labore, Tarifas bancárias) para `type:'business'`.
- **Workspace ativo excluído/arquivado:** `workspaceScopeProvider` volta ao default (guarda contra id pendurado em SharedPreferences).
- **Multi-device:** seleção é local por device (ok); resolver valida contra `workspacesStreamProvider` e cai no default se stale.
- **Exportação Carnê-Leão futura:** os dados PJ já ficam numa partição limpa (`workspaceId`) — a exportação filtra por `(userId, workspaceId)` e carimba o nome do workspace no relatório. Este design prepara o terreno sem trabalho extra. **Recomendação:** garantir que todo relatório exportado inclua o nome do workspace para números PJ inequívocos.

---

## 10. Fases de entrega com esforço e ordem

| Fase | Conteúdo | Esforço |
|---|---|---|
| **P0 — Encanamento (sem mudança visível)** | Coleção `workspaces` + entity/repo; regras (bloco `workspaces` + fix imutabilidade de `userId` nas 7 coleções); adicionar `workspaceId` a todos os write paths (carimbando o default); fix do doc-id de budget (§2.3); fix da lista de deleção (bills+category_rules+workspaces). Reads ainda sem filtro. Dado novo já fica tagueado; nada muda visualmente. | **M** |
| **P1 — Backfill** | Migração lazy dirigida pelo dono no launch; criar "Pessoal" default; `workspaceMigrationV1`. Filtro client-side com fallback `ausente→default` (zero índices, zero risco de sumiço). Ainda 1 workspace visível. | **M** |
| **P2 — Feature ligada (Pro)** | `activeWorkspaceIdProvider`, seletor UI (global no MainScreen + lista unificada com contas compartilhadas), criar/renomear/arquivar/excluir em Settings, capture-default setting, label no widget, namespacing/reset do estado local no switch. Gate por `isProProvider`. `_FeaturesCard` do `pro_screen.dart`. | **G** |
| **P3 — Hardening de escala (opcional)** | Após telemetria confirmar backfill completo, migrar streams quentes (transactions, budgets) para `where('workspaceId')` server-side + índices compostos. | **M** |

Ordem estrita: P0 → P1 → P2. Nunca subir filtro server-side (P3) antes do backfill (risco "dados sumiram").

---

## 11. Riscos e mitigação

- **R1 — Mistura silenciosa de ledgers se algum stream/notifier for esquecido (ALTO).** O filtro deve ser uniforme. Mitigar: helper único `applyWorkspaceScope` + matriz de smoke-test por tela (§12). Atenção à query inline em `bills_provider.dart:24`.
- **R2 — Colisão de doc-id de budget (perda de dados) (ALTO).** Corrigido em §2.3 antes de qualquer escrita PJ.
- **R3 — "Docs somem" na migração (ALTO).** Evitado pela ordem P0→P1→P2 e pelo fallback client-side `ausente→default`; server-side (P3) só após confirmação.
- **R4 — Recurring generator / captura escrevendo no ledger errado (MÉDIO).** Generator herda `rec.workspaceId`; captura usa `captureWorkspaceId` fixo, não o ativo.
- **R5 — Estado local vazando entre workspaces (MÉDIO).** Namespacing de `hiddenWalletIds`/`dismissedSubscriptions` + invalidação dos filtros de statement no switch.
- **R6 — Isolação NÃO é fronteira de segurança (comunicação).** Não vender "Empresa" como oculto de colaborador — não é. Documentar que sharing é account-wide.
- **R7 — Downgrade Pro percebido como perda de dados (BAIXO).** Manter todos os workspaces acessíveis (read); só bloquear criar novos; mensagem clara.
- **R8 — Fix de imutabilidade de `userId` pode quebrar updates legítimos (BAIXO).** Testar com rules emulator que updates normais (mesmo `userId`) passam e re-home é negado.

---

## 12. Checklist de QA

**Isolação / "totais nunca misturam" (por workspace, ≥2 workspaces com dados distintos):**
- [ ] Saldo total do dashboard (`convertedBalanceProvider`) reflete só o ativo.
- [ ] Linha income/expense do mês (`dashboardMonth*`).
- [ ] Sparkline 24 meses.
- [ ] Budget summary + cards de budget (checar doc-id composto, sem overwrite entre ledgers).
- [ ] Wallet balances / NetWorth / SafeToSpend / Bills cards.
- [ ] Financial-health score.
- [ ] Statement: totais all-time e do mês; filtros wallet/categoria/tag resetam no switch.
- [ ] Reports / exportação carrega só o ativo e mostra o nome do workspace.
- [ ] Metas (goal progress) e credit-card invoices isolados.

**Migração/backfill:**
- [ ] Usuário existente vê 100% dos dados após update (fallback ausente→default), antes e durante o backfill.
- [ ] Backfill idempotente (rodar 2x não duplica/estraga).
- [ ] Budgets legados continuam visíveis em "Pessoal".
- [ ] Colaborador não dispara migração do master.

**Switch de workspace:**
- [ ] Seed de wallets+categories dispara uma única vez num workspace novo vazio.
- [ ] Filtros de statement invalidados; `hiddenWalletIds`/`dismissed` namespaced.
- [ ] Home widget re-empurra com label correto.
- [ ] Workspace ativo excluído/arquivado → volta ao default sem crash.

**Captura/notificações:**
- [ ] Transação auto-capturada cai no `captureWorkspaceId` (Pessoal), mesmo com "Empresa" ativo em background.
- [ ] Backlog drain carimba o capture workspace.

**Regras (emulator):**
- [ ] Update normal (mesmo `userId`) passa em todas as 8 coleções.
- [ ] Re-home de doc para outro `userId` no update é **negado** (as 7 coleções + bills).
- [ ] Colaborador lê/escreve os workspaces do master; não lê de terceiros.

**Convivência com sharing:**
- [ ] Usuário no próprio "Empresa": painel de convite visível, botão "Sair da conta compartilhada" **não** aparece (`isMasterProvider` correto).
- [ ] Colaborador enxerga os workspaces do master no seletor.

**Pro gating:**
- [ ] Free: seletor oculto, só Pessoal, criar workspace bloqueado com upsell.
- [ ] Lapse com N>1 workspaces: sem perda de dados, força default, upsell.
- [ ] "Modo Pessoal + Empresarial (PJ)" aparece no `_FeaturesCard`.

**Exclusão de conta:**
- [ ] Todos os workspaces + as 8 coleções (incl. bills e category_rules) + doc `workspaces` são apagados; nada órfão.