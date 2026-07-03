# Plano — "Carteiras" (PF/PJ) com compartilhamento por Carteira

> Supersede `PJ_MODE_PLAN.md` (que assumia compartilhamento de conta inteira).
> Decisões do usuário (2026-07-03): o novo espaço chama-se **"Carteira"** (PF/PJ);
> as contas de dinheiro atuais (WalletEntity) são renomeadas na UI para **"Conta"**;
> compartilhamento passa a ser **por Carteira** (substitui o de conta inteira);
> papel escolhido **no convite**: `viewer` (só ver) ou `editor`.

## Modelo de dados

Nova coleção `workspaces/{autoId}` (user-facing "Carteira"):

```
ownerId:    string        // uid do dono (== userId dos docs de ledger desta Carteira)
name:       string        // "Pessoal", "Minha Empresa"
type:       string        // 'personal' | 'business'
memberUids: [uid, ...]    // INCLUI ownerId; habilita arrayContains "compartilhadas comigo"
roles:      { uid: 'editor' | 'viewer' }   // ownerId => 'editor'
color, order, archived, isDefault, createdAt
```

- **Dono também é membro** → toda leitura (dono ou convidado) usa `where('workspaceId'==X)` uniformemente.
- **`userId` dos docs de ledger continua == ownerId** (nunca o uid do convidado) — preserva deleção de conta e invariante imutável.
- `workspaceId: string` adicionado às 8 coleções: transactions, wallets, budgets, categories, goals, recurring_transactions, category_rules, bills. NÃO tocar: subscriptions, notification_backlog, referral* (per-pessoa, uid real).
- `invitations/{id}` ganha `workspaceId` + `role`.
- `users/{uid}` ganha `defaultWorkspaceId`, `captureWorkspaceId`, `workspaceMigrationV1`.

## Regras (dual-path na transição)

Helpers:
```
function wsData(wid) { return get(/databases/$(database)/documents/workspaces/$(wid)).data; }
function isWorkspaceMember(wid) { return request.auth.uid in wsData(wid).memberUids; }
function isWorkspaceEditor(wid) { return wsData(wid).roles[request.auth.uid] == 'editor'; }
function wsOwner(wid) { return wsData(wid).ownerId; }
```
Custo: ~1 get() por QUERY (deduplicado), não por doc. Ledger (padrão p/ as 8):
- read: `('workspaceId' in resource.data && isWorkspaceMember(...)) || legacy(owner||collaborator)`
- create: `(isWorkspaceEditor(wid) && userId == wsOwner(wid)) || (legacy && !('workspaceId' in request.resource.data))`
- update: `userId imutável (AUDIT FIX em todas)` + `(workspaceId imutável && isWorkspaceEditor) || (sem workspaceId && legacy)`
- delete: análogo.
Viewer bloqueado de escrita de graça (roles[uid] != 'editor').
`workspaces`: read se membro; create/update/delete só ownerId (ownerId congelado). Self-add do convidado = Cloud Function.
O branch legado é o gêmeo (nas rules) do fallback cliente `ausente→default` — remover só na P4.

## Camada de consulta

`lib/core/providers/workspace_provider.dart`:
- `LedgerScope` = `WorkspaceScope(workspaceId, ownerId)` | `LegacyScope(userId)` | `CombinedScope(userId)`.
- `activeLedgerScopeProvider`: Carteira própria/compartilhada + backfill confirmado → WorkspaceScope; share legado (masterUserId) → LegacyScope(master); pré-migração → LegacyScope(uid); "Todas juntas" → CombinedScope(uid).
- `activeWorkspaceIdProvider`: StateNotifier persistido (SharedPreferences, chave por uid), sentinela `'__ALL__'`, validado contra o stream.
- `workspacesStreamProvider`: união de próprias (`ownerId==uid`) + compartilhadas (`memberUids arrayContains uid`).
- `activeWorkspaceOwnerIdProvider`: quem os notifiers carimbam como `userId`.
- `effectiveUserIdProvider` fica INTOCADO (só caminho legado; aposenta na P4). Pro/referral/backlog seguem no uid REAL de login.
- Datasources: caminho workspaceId é equality-only (sort no cliente p/ categories/goals/recurring/rules/budgets) → **ZERO índices novos** até a P4. Query inline de bills está em `bills_provider.dart:24`.

## "Todas juntas"

`CombinedScope` = `where('userId'==uid)` sem filtro de workspace → agrega só as Carteiras PRÓPRIAS (exclui compartilhadas-comigo) de graça; todos os providers derivados consolidam sozinhos. Modo leitura: FAB/edições abrem "Escolha uma Carteira" (escrita precisa de um workspaceId).

## Compartilhamento por Carteira

- Convite (cliente/dono): sendInvitation ganha workspaceId+role; UI com picker de Carteira + toggle Ver/Editar.
- **Aceite = Cloud Function `acceptWorkspaceInvite`** (onCall, Admin SDK): valida email/status, batch: invitation accepted+collaboratorUserId; workspace memberUids arrayUnion + roles.{uid}=role. NÃO seta masterUserId (shares novos são só-membership). Idempotente.
- Revogar (dono, cliente): arrayRemove + delete role + invitation 'removed'. Sair (convidado): **CF `leaveWorkspace`**.
- Migração dos shares atuais (no backfill P1, dono escreve os próprios docs): colaboradores aceitos → memberUids+roles='editor' da Carteira default; invitations legadas carimbadas com workspaceId+role. `masterUserId` fica até a P4 (isolação real dos shares antigos só na P4 — comunicar!). Shares novos são isolados desde o dia 1.

## Migração/backfill (P1) — sem sumiço

Só o dono (isMasterProvider). Primeiro launch: cria Carteira default `{'Pessoal', personal, isDefault, memberUids:[uid+colaboradores], roles}`, grava users.{defaultWorkspaceId,captureWorkspaceId,workspaceMigrationV1}. Backfill workspaceId nas 8 coleções em lotes ~400 (espelha `_deleteDocsInChunks`), idempotente (pula quem já tem). Leitura continua LegacyScope+fallback até o scope flip. Rollback = build antigo.

## Fases

| Fase | Conteúdo | Estado |
|---|---|---|
| **P0** Encanamento + rename (invisível) | rules dual-path + bloco workspaces + userId imutável (audit); entity/model/datasource workspace; workspaceId nos 8 models; notifiers carimbam (se houver default); fix doc-id de budget (qualificado SÓ p/ carteiras não-default — default mantém id legado p/ não duplicar); recurring generator herda rec.workspaceId; deletion-list += bills, category_rules, investment_*, workspaces; rename UI Carteira→Conta (NÃO tocar "carteira" de investimentos/portfolio) | ✅ FEITO 2026-07-03 (rules DEPLOYADAS) |
| **P1** Backfill | `workspace_migration_provider.dart` (dono, idempotente; ws default com **doc-id determinístico `ws_<uid>_default`** → multi-device não duplica; flag `workspaceMigrationV1` só APÓS backfill completo → interrompido retoma; seed colaboradores legados como editors; carimba invitations c/ workspaceId+role) | ✅ FEITO 2026-07-03 (roda no próximo build) |
| **P2** Feature ON | `LedgerScope` (UserScope/MemberScope) + `activeLedgerScopeProvider` + `activeWorkspaceIdProvider` (SharedPreferences por uid, sentinela `__ALL__`) + `ledgerOwnerIdProvider`; 8 root streams escopados (client-filter p/ UserScope, query workspaceId p/ MemberScope — este design SUBSTITUI o "stream mesclado" da nota P2: dono lê sempre por userId+filtro cliente, imune ao set()-drop); `WorkspaceSwitcherBar` global no MainScreen + bottom sheet + `ManageWorkspacesScreen` (criar/renomear/arquivar/excluir cascade, default bloqueada) + entrada em Ajustes; captura em background força default (overrides no addAndReturnId); seeds só em UserScope; filtros de statement invalidados no switch; pro_screen row | ✅ FEITO 2026-07-03 |
| **P3** Sharing por Carteira | CFs `acceptWorkspaceInvite`+`leaveWorkspace` (onCall us-central1, DEPLOYADAS); rules: brecha de escalada fechada (`!('workspaceId' in inv)` no invitationAuthorizesLink), create valida role+wsOwner, accept cliente só p/ convites legados; `cloud_functions` ^5.1 no pubspec; invitation ganha workspaceId+workspaceName(denorm)+role; datasource roteia CF vs transaction legada; revoke = membership removal + tolera profile detach negado; UI: picker de Carteira + toggle Pode editar/Só ver no convite, badges de papel, seção "Carteiras compartilhadas comigo" c/ sair | ✅ FEITO 2026-07-03 (rules+functions DEPLOYADAS) |
| **P2** Feature ON (Pro) | workspace_provider completo; 8 streams → LedgerScope; switcher global no MainScreen (Column acima do IndexedStack, mobile ~609/web ~537); bottom sheet (próprias PF/PJ + Todas juntas + compartilhadas + Nova Carteira Pro + Gerenciar, só com ≥2 contextos); CRUD em Settings (delete cascade por userId+workspaceId, bloquear isDefault); write-block no modo Todas; higiene local no switch (hiddenWalletIds/dismissed por workspace, invalidar filtros de statement, re-push widget, captura usa captureWorkspaceId); pro_screen _FeaturesCard | |
| **P3** Sharing por Carteira | CFs acceptWorkspaceInvite+leaveWorkspace em functions/index.js; datasource/entity/providers/UI de sharing com workspaceId+role; rules de invitations (accept sai do cliente) | |
| **P4** Cutover (opcional) | remover masterUserId dos convidados; dropar branch legado; aposentar effectiveUserIdProvider; índices compostos p/ orderBy server-side | |

Ordem estrita P0→P1→P2→P3. Nunca filtro server-side antes do backfill.

## Nota de design obrigatória para a P2 (aprendida na P0)

**A carteira DEFAULT deve ler com stream MESCLADO**: `where('workspaceId'==default)` UNION `where('userId'==uid)` filtrado no cliente para docs SEM workspaceId. Motivo: builds antigos que fazem `set()` sem merge (ex.: budgets upsert) DERRUBAM o campo workspaceId de docs backfilled — o fallback server-side puro faria esses docs sumirem. Carteiras não-default (criadas pós-P2, só builds novos escrevem nelas) usam query única por workspaceId. Oportunisticamente re-carimbar docs sem workspaceId encontrados pelo stream default.

## Riscos principais
1. Stream/notifier esquecido misturando ledgers (ALTO) → funil único LedgerScope + matriz QA "totais nunca misturam".
2. Regras dual-path com regressão (ALTO) → testar: update normal passa, re-home negado, colaborador legado ainda lê, viewer não escreve.
3. Shares pré-existentes não isolados até P4 (comunicar).
4. Rename com falso-positivo (portfolio ≠ wallet).
