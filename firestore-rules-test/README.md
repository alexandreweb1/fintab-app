# Testes de segurança das regras do Firestore

Testes de `../firestore.rules` rodando contra o **emulador do Firestore** — não
tocam em produção. Cobrem os cenários da revisão adversarial das 3 correções
críticas (escalação via `masterUserId`, fraude de assinatura, exclusão de conta).

## Pré-requisitos (uma vez)

```bash
# Firebase CLI (precisa de Node 18+)
npm install -g firebase-tools

# Java 21+ (o emulador do Firestore exige JDK 21 ou superior)
brew install openjdk@21

# dependências de teste
cd fintab-app/firestore-rules-test && npm install
```

## Rodar

A partir de `fintab-app/`:

```bash
export PATH="/opt/homebrew/opt/openjdk@21/bin:$PATH"
export JAVA_HOME="/opt/homebrew/opt/openjdk@21"

firebase emulators:exec --project demo-fintab --only firestore \
  "node firestore-rules-test/rules.test.js"
```

Saída esperada: `RESULT: 26 passed, 0 failed`. Exit code ≠ 0 se algo falhar
(útil para CI). Não precisa de login no Firebase — usa o projeto fake
`demo-fintab`.

## O que é coberto

- **Escalação de privilégio**: um usuário não consegue apontar `masterUserId`
  para o uid de outra pessoa sem um convite aceito válido.
- **Fluxos legítimos de compartilhamento**: aceitar convite (batch + `getAfter`),
  colaborador lê dados do mestre, sair, mestre desvincular, editar perfil.
- **Assinatura**: bloqueia Pro perpétuo, campos extras, produto falso,
  `updatedAt` forjado, escrita no doc de outro usuário; permite o write legítimo,
  o restore com token vazio (fix B1) e o `clearSubscription`.
- **Risco residual conhecido**: documenta que um Pro forjado de < 400 dias ainda
  passa (só fecha com validação de recibo server-side — Cloud Function).
- **Exclusão de conta**: dono apaga as próprias coleções; colaborador recusa o
  convite ao se deletar (fix B2).

> Ao mudar `firestore.rules`, rode esta suíte **antes** de `firebase deploy`.
