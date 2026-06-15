# Captura automatizada de transações — iOS (e Android)

Como o iOS não permite ler notificações de outros apps (ver
`docs`/decisão de produto), a captura "automática" no iOS é feita por outros
caminhos. Este documento descreve o que já está implementado e o que ainda
precisa ser concluído **no Xcode** (passos que exigem a GUI/assinatura e não dão
para automatizar por edição de arquivo).

## Visão geral do que foi implementado

Todas as fontes de captura usam o **mesmo parser** —
`lib/core/services/transaction_text_parser.dart` (`TransactionTextParser`),
porte fiel da lógica nativa Android (`NotificationMonitorService.kt`), coberto
por testes em `test/transaction_text_parser_test.dart`.

| Caminho | Plataforma | Status | Como funciona |
|---|---|---|---|
| Parser de texto → transação | todas | ✅ pronto e testado | regex de R$/BRL + palavras-chave de despesa/receita |
| Captura por **clipboard** | iOS + Android | ✅ pronto | ao voltar ao app, lê o texto copiado e oferece "Lançar" (opt-in nas Configurações) |
| **Share** (compartilhar texto) | Android | ✅ pronto | share sheet → Fintab → diálogo pré-preenchido |
| **Share** (compartilhar texto) | iOS | ⏳ falta criar o target no Xcode | arquivos prontos em `ios/Share Extension/` |
| **Atalho do ícone** ("Novo lançamento") | iOS + Android | ✅ pronto | `quick_actions`, long-press no ícone do app |
| Siri / App Intents / Botão de Ação | iOS | 🔵 opcional, próximo passo | ver seção final |

Tudo o que está ✅ já compila: `flutter analyze` limpo, testes passando e
`flutter build apk` concluído.

---

## 1. Concluir a Share Extension do iOS (Xcode)

O código Dart (`_initShareIntent`/`_handleSharedFiles` em `main_screen.dart`), o
esquema de URL no `Runner/Info.plist` e os arquivos nativos já estão prontos.
Falta só criar o **target** no Xcode e ligar o App Group.

Bundle id do app: **`com.alexdev.fintab`** · App Group sugerido:
**`group.com.alexdev.fintab`**

### Passos

1. **Abrir o projeto**: `open ios/Runner.xcworkspace`.

2. **Criar o target da extensão**: File ▸ New ▸ Target… ▸ **Share Extension**.
   - Product Name: **`Share Extension`** (exatamente esse nome — o Podfile e a
     pasta já assumem ele).
   - Linguagem: Swift. Não ative "Include UI Tests".
   - Quando perguntar "Activate scheme?", pode ativar.

3. **Substituir os arquivos gerados pelos já prontos** (em
   `ios/Share Extension/`):
   - `ShareViewController.swift` → subclasse de `RSIShareViewController`.
   - `Info.plist` → já com `NSExtensionActivationSupportsText`/`WebURL` e
     `AppGroupId = $(CUSTOM_GROUP_ID)`.
   - Mantenha o `MainInterface.storyboard` que o Xcode gerou.
   - Apague o `ShareViewController.swift` gerado em duplicidade, se houver.

4. **App Groups** (Signing & Capabilities) — nos **dois** targets, `Runner` e
   `Share Extension`:
   - "+ Capability" ▸ **App Groups** ▸ adicionar `group.com.alexdev.fintab`.
   - Isso atualiza os entitlements e o provisioning automaticamente. O arquivo
     `ios/Share Extension/Share Extension.entitlements` já contém esse grupo;
     no `Runner` a capability adiciona o grupo ao `Runner.entitlements`
     existente (que hoje só tem Sign in with Apple).

5. **Build Setting `CUSTOM_GROUP_ID`** — nos **dois** targets:
   - Build Settings ▸ "+" ▸ **Add User-Defined Setting**.
   - Nome: `CUSTOM_GROUP_ID` · Valor: `group.com.alexdev.fintab`.

6. **Podfile** (`ios/Podfile`) — adicionar o target da extensão e rodar o pod:
   ```ruby
   target 'Share Extension' do
     inherit! :search_paths
   end
   ```
   Depois: `cd ios && pod install`.

7. **Ordem das Build Phases do `Runner`**: arraste **"Embed Foundation
   Extension"** para **acima** de "Thin Binary" (evita erro de import de módulo).

8. **Deployment target** da extensão: iOS **12.0+** (o plugin exige).

### Como testar
Recebido um push/transação no app do banco, faça **Compartilhar → Fintab** (ou
selecione o texto e compartilhe). O app abre o diálogo de nova transação já
preenchido com valor e tipo. Se o texto não tiver valor, abre o diálogo vazio.

> Observação: no iOS não dá para "compartilhar a notificação" direto da central;
> os gatilhos reais são **selecionar texto** no app do banco, **compartilhar um
> print** ou **copiar** (este último já coberto pela captura por clipboard).

---

## 2. Mudança no Gradle (Android) — contexto

Adicionar `receive_sharing_intent` quebrou o build Android com
*"Inconsistent JVM-target compatibility"* porque alguns plugins compilam Java em
1.8 e Kotlin no default do JDK. A correção (em `android/gradle.properties`):

```properties
kotlin.jvm.target.validation.mode=warning
```

Rebaixa a checagem para aviso; o bytecode misto é inofensivo após o D8/R8. Não
foi preciso mexer no `build.gradle.kts`.

---

## 3. (Opcional) Siri / App Intents / Botão de Ação — próximo passo

Para o usuário dizer *"Ei Siri, lançar 50 reais de despesa no Fintab"* ou mapear
o Botão de Ação (iPhone 15 Pro+), é preciso o **App Intents** do iOS. Isso **não
foi aplicado** porque o pacote `flutter_app_intents` (0.7.0) é imaturo, iOS-only
e exige Swift nativo obrigatório — risco que não dá para validar sem um build
iOS assinado, e o app está em produção. Quando quiser seguir:

1. `flutter pub add flutter_app_intents`.
2. **Dart** — registrar o intent (ex. no `main_screen`):
   ```dart
   final intent = AppIntentBuilder()
       .identifier('add_transaction')
       .title('Lançar transação')
       .description('Abre o Fintab para registrar uma transação')
       .build();
   await FlutterAppIntentsClient.instance.registerIntent(intent, (params) async {
     // abrir AddTransactionDialog
     return AppIntentResult.successful();
   });
   ```
3. **Swift (obrigatório)** — declarar o `AppIntent` estático e um
   `AppShortcutsProvider` no target do app (Siri/Atalhos só descobrem assim):
   ```swift
   import AppIntents
   struct AddTransactionIntent: AppIntent {
     static var title: LocalizedStringResource = "Lançar transação"
     func perform() async throws -> some IntentResult {
       let r = await FlutterAppIntentsPlugin.shared
         .handleIntentInvocation(identifier: "add_transaction", parameters: [:])
       return .result()
     }
   }
   ```
4. Validar num device iOS 16+ (Atalhos, Siri e Botão de Ação).

Alternativa mais simples já entregue: o atalho do ícone via `quick_actions`
(long-press no ícone → "Novo lançamento").
