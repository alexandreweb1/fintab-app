import 'package:flutter/material.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/utils/platform_store.dart';
import 'legal_document.dart';

/// Full Privacy Policy rendered natively inside the app (no external link / webview).
///
/// Content mirrors the official web versions (fintab.info/privacy and
/// /privacy-en). Language follows the app locale: Portuguese for `pt`,
/// English for everything else (so `es` users fall back to English).
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isPt = AppLocalizations.of(context).locale.languageCode == 'pt';
    return LegalDocumentScreen(
      title: isPt ? 'Política de Privacidade' : 'Privacy Policy',
      blocks: isPt ? _ptPrivacy : _enPrivacy,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Content — Portuguese (pt-BR)
// ─────────────────────────────────────────────────────────────────────────────

final List<LegalBlock> _ptPrivacy = <LegalBlock>[
  const Updated('Última atualização: 3 de junho de 2026'),
  const Para(
      'Esta política explica, de forma direta, quais dados o Fintab coleta, por quê, com quem compartilha e como você pode exercer seus direitos sob a **LGPD** (Lei nº 13.709/2018) e o **GDPR** (Regulamento UE 2016/679).'),
  const Rule(),

  const Heading(2, '1. Quem somos (Controlador)'),
  const Para(
      'O Fintab é um aplicativo de finanças pessoais desenvolvido e operado por:'),
  const Bullets([
    '**Controlador:** Alexandre Figueiredo F Costa Filho (desenvolvedor pessoa física, atuando sob a marca **VerticalTI**)',
    '**Contato geral:** alexandreweb2@gmail.com',
    '**Encarregado de Dados (DPO):** Alexandre Figueiredo F Costa Filho — alexandreweb2@gmail.com',
  ]),
  const Para(
      'Você pode falar com o Encarregado a qualquer momento usando o e-mail acima.'),

  const Heading(2, '2. Quais dados tratamos'),
  const Heading(3, '2.1 Dados de conta e autenticação'),
  const Bullets([
    'E-mail (cadastro por e-mail/senha, Sign in with Apple ou Google Sign-In)',
    'Nome de exibição (quando informado pelo provedor de login)',
    'URL da foto de perfil (quando informada pelo provedor de login)',
    'UID único gerado pelo Firebase Authentication',
    'Senha (apenas para login por e-mail; armazenada **somente como hash** pelo Firebase — nunca acessamos a senha em texto)',
  ]),
  const Quote(
      'Se você usar **Sign in with Apple** e escolher "Esconder meu e-mail", recebemos apenas o endereço relay (`@privaterelay.appleid.com`). Tratamos esse relay como um e-mail comum.'),

  const Heading(3, '2.2 Dados financeiros que você registra'),
  const Bullets([
    'Transações (título, valor, tipo, categoria, data, descrição, conta, tags)',
    'Contas (nome, ícone, cor, moeda, tipo, saldo inicial)',
    'Categorias personalizadas',
    'Orçamentos (limites por categoria, mês/ano)',
    'Metas financeiras (título, valor-alvo, prazo)',
    'Transações recorrentes (Pro)',
  ]),

  const Heading(3, '2.3 Notificações locais'),
  const Para(
      'O app pode agendar lembretes locais no seu dispositivo (ex.: avisos de transações recorrentes) com sua autorização. Esses lembretes são processados **apenas localmente**; nenhum conteúdo dessas notificações é enviado aos nossos servidores. No iOS, **não** lemos notificações do sistema operacional nem de outros aplicativos.'),

  const Heading(3, '2.4 Assinatura Pro'),
  const Bullets([
    'Status da assinatura, identificador do produto, data de expiração',
    '`purchaseToken` (token sensível usado para validar a compra junto à Apple/Google)',
  ]),
  Para(
      'O pagamento em si é processado pela ${isApplePlatform ? "Apple App Store" : "Apple App Store ou Google Play"}. **Não temos acesso ao seu cartão de crédito ou método de pagamento.**'),

  const Heading(3, '2.5 Compartilhamento de conta (colaboradores) — Pro'),
  const Para(
      'Se você convidar alguém para compartilhar sua conta, armazenamos: e-mail e nome do master, e-mail do convidado, status do convite e UID do colaborador após aceite.'),

  const Heading(3, '2.6 Dados armazenados apenas no seu dispositivo'),
  const Bullets([
    'PIN do app lock (somente **hash SHA-256 + salt** no Keychain/Keystore — nunca enviado a nenhum servidor)',
    'Flags de bloqueio (PIN ativo, biometria ativa)',
    'Preferências de UI (moeda, idioma, tema, layout do dashboard, contas ocultas, nível de letramento financeiro)',
  ]),

  const Heading(3, '2.7 O que NÃO coletamos'),
  const Bullets([
    '**Não** usamos Google Analytics, Firebase Analytics ou Crashlytics.',
    '**Não** rastreamos você entre apps ou sites (não há IDFA / App Tracking Transparency).',
    '**Não** vendemos seus dados.',
    '**Não** usamos seus dados financeiros para treinar modelos de IA.',
    '**Não** exibimos publicidade dentro do app.',
  ]),

  const Heading(2, '3. Como tratamos os dados'),
  const Bullets([
    'Dados de conta e dados financeiros são gravados no **Cloud Firestore** (Google) sob o seu UID.',
    'A comunicação entre o app e o Firestore é criptografada em trânsito (TLS 1.2+).',
    'Em repouso, os dados são criptografados pela infraestrutura do Google Cloud.',
    'O PIN local **nunca** sai do dispositivo.',
  ]),

  const Heading(2, '4. Por que tratamos (finalidade + base legal)'),
  const TableBlock([
    [
      'Conta / autenticação',
      '**Finalidade:** Permitir login e identificar você no app',
      '**Base legal (LGPD Art. 7):** Execução de contrato (V)',
    ],
    [
      'Dados financeiros',
      '**Finalidade:** Funcionalidade principal: registrar e exibir suas finanças',
      '**Base legal (LGPD Art. 7):** Execução de contrato (V)',
    ],
    [
      'Assinatura Pro',
      '**Finalidade:** Validar plano ativo e desbloquear recursos pagos',
      '**Base legal (LGPD Art. 7):** Execução de contrato (V)',
    ],
    [
      'Convites de compartilhamento',
      '**Finalidade:** Permitir que dois usuários acessem a mesma conta',
      '**Base legal (LGPD Art. 7):** Execução de contrato (V)',
    ],
    [
      'Comunicações de suporte',
      '**Finalidade:** Responder ao e-mail que você nos envia',
      '**Base legal (LGPD Art. 7):** Legítimo interesse (IX)',
    ],
  ]),
  const Para(
      'Sob o GDPR, as bases são equivalentes: **Art. 6(1)(b)** (execução de contrato) e **Art. 6(1)(a)** (consentimento, quando aplicável).'),

  const Heading(2, '5. Compartilhamento com terceiros (suboperadores)'),
  const Para(
      'Compartilhamos o mínimo necessário com os seguintes prestadores:'),
  TableBlock([
    [
      '**Google LLC** — Firebase Authentication',
      '**Dado compartilhado:** E-mail, UID, senha (hash), tokens OAuth',
      '**Finalidade:** Autenticação',
    ],
    [
      '**Google LLC** — Cloud Firestore',
      '**Dado compartilhado:** Todos os dados financeiros vinculados ao UID',
      '**Finalidade:** Armazenamento do backend',
    ],
    [
      '**Apple Inc.** — Sign in with Apple',
      '**Dado compartilhado:** Nonce; em retorno, identityToken + e-mail + nome (apenas no primeiro login)',
      '**Finalidade:** Autenticação',
    ],
    [
      '**Apple Inc.** — App Store / StoreKit',
      '**Dado compartilhado:** `purchaseToken`, `productId`',
      '**Finalidade:** Processar e validar assinatura Pro (iOS)',
    ],
    if (!isApplePlatform)
      [
        '**Google LLC** — Google Play Billing',
        '**Dado compartilhado:** `purchaseToken`, `productId`',
        '**Finalidade:** Processar e validar assinatura Pro (Android)',
      ],
  ]),
  const Para(
      'Não há outros suboperadores. Não há SDKs de publicidade, analytics ou attribution.'),
  const Heading(3, 'Sobre a função "compartilhar" (share)'),
  const Para(
      'Quando você exporta um relatório em PDF/Excel, o app usa o **share sheet nativo do sistema operacional**. O destino (e-mail, Drive, WhatsApp etc.) é escolhido por você; o Fintab não envia nada automaticamente a terceiros.'),

  const Heading(2, '6. Onde os dados ficam armazenados'),
  const Bullets([
    '**Cloud Firestore:** região `southamerica-east1` (São Paulo, Brasil).',
    'Backups e logs operacionais do Firebase podem ser processados em outras regiões da Google Cloud com base nas Standard Contractual Clauses, o que cobre eventuais transferências internacionais sob a LGPD (Art. 33, II) e o GDPR (Art. 46).',
    'Dados locais ficam apenas no seu dispositivo (Keychain/Keystore + SharedPreferences).',
  ]),

  const Heading(2, '7. Por quanto tempo guardamos'),
  const Bullets([
    '**Enquanto sua conta estiver ativa:** mantemos todos os dados para o funcionamento do app.',
    '**Após exclusão da conta:** os dados pessoais e financeiros vinculados ao seu UID são apagados do Firestore em **até 30 dias**. Backups operacionais do Google Cloud expiram em até **90 dias** adicionais.',
    '**Logs técnicos de autenticação** (Firebase Auth) são retidos pelo Firebase pelo período padrão da Google.',
    '**Dados locais** no dispositivo somem ao desinstalar o app.',
  ]),

  const Heading(2, '8. Seus direitos (LGPD Art. 18 + GDPR)'),
  const Para('Você pode, a qualquer momento e gratuitamente:'),
  const Numbered([
    '**Confirmar** se tratamos dados sobre você',
    '**Acessar** seus dados',
    '**Corrigir** dados incompletos, inexatos ou desatualizados',
    '**Anonimizar, bloquear ou eliminar** dados desnecessários ou tratados em desconformidade',
    '**Portar** seus dados para outro fornecedor',
    '**Eliminar** seus dados tratados com base em consentimento',
    '**Revogar** consentimento',
    '**Ser informado** sobre com quem compartilhamos seus dados',
    '**Opor-se** ao tratamento em caso de descumprimento da LGPD',
  ]),
  const Heading(3, 'Como exercer cada direito'),
  const Bullets([
    '**Excluir conta + todos os dados:** no app, vá em **Ajustes → Conta → Excluir conta**. A exclusão é executada imediatamente após reautenticação.',
    '**Exportar seus dados (portabilidade):** envie um e-mail para alexandreweb2@gmail.com com o assunto "LGPD - Portabilidade". Respondemos em até **15 dias**.',
    '**Demais direitos:** envie e-mail para alexandreweb2@gmail.com.',
  ]),

  const Heading(2, '9. Segurança'),
  const Para(
      'Aplicamos medidas técnicas e organizacionais para proteger seus dados:'),
  const Bullets([
    '**Em trânsito:** toda comunicação entre o app e o backend usa TLS 1.2 ou superior.',
    '**Em repouso:** o Firestore criptografa todos os dados por padrão (AES-256).',
    '**Senhas:** são armazenadas apenas como hash pela Firebase Authentication (scrypt). Não temos acesso à senha em texto.',
    '**PIN local:** armazenado como hash SHA-256 com salt aleatório no Keychain (iOS) / Keystore (Android). Não sai do dispositivo.',
    '**Biometria:** Face ID / Touch ID são processados pelo sistema operacional. O Fintab não recebe nem armazena os dados biométricos.',
    '**Regras de acesso (Firestore):** cada usuário só pode ler e escrever dados vinculados ao seu próprio UID.',
  ]),

  const Heading(2, '10. Crianças'),
  const Para(
      'O Fintab não é direcionado a menores de 13 anos e não coleta intencionalmente dados de crianças. Se você é responsável e identificou que uma criança nos forneceu dados, entre em contato em alexandreweb2@gmail.com para que sejam removidos.'),

  const Heading(2, '11. Assinaturas Pro auto-renováveis'),
  Para(
      'O Fintab Pro é uma assinatura auto-renovável processada pela ${isApplePlatform ? "Apple App Store" : "Apple App Store (iOS) ou Google Play (Android)"}. Ao assinar:'),
  const Bullets([
    '**Renovação:** a assinatura é renovada automaticamente ao final de cada período (Mensal ou Anual) pelo mesmo valor, salvo cancelamento até **24 horas antes** do término do período atual.',
    '**Cobrança:** processada na sua conta da Apple/Google na confirmação da compra e a cada renovação.',
    '**Cancelamento:** você pode cancelar a qualquer momento:',
  ]),
  Bullets([
    '**iPhone/iPad:** Ajustes → [seu nome] → Assinaturas → Fintab Pro → Cancelar Assinatura',
    if (!isApplePlatform)
      '**Android:** Google Play Store → ☰ → Assinaturas → Fintab Pro → Cancelar',
  ], indent: true),
  const Bullets([
    '**Reembolso:** reembolsos são processados exclusivamente pela Apple/Google conforme as políticas delas. Não temos acesso direto ao seu pagamento.',
  ]),
  const Para(
      'Veja os Termos de Uso (em Ajustes → Sobre) para detalhes contratuais completos da assinatura.'),

  const Heading(2, '12. Alterações desta política'),
  const Para(
      'Podemos atualizar esta política conforme o app evolui ou para refletir mudanças regulatórias. Quando houver alteração relevante, atualizaremos a **data no topo desta tela** e, se a mudança afetar significativamente seus direitos, notificaremos você dentro do app ou por e-mail.'),

  const Heading(2, '13. Outros idiomas'),
  const Para(
      'Esta política está disponível em **Português (Brasil)** e **English (U.S.)**. Para trocar, altere o idioma do app em Ajustes → Idioma.'),

  const Heading(2, '14. Contato'),
  const Para('Dúvidas, solicitações ou reclamações sobre privacidade?'),
  const Bullets([
    '📧 alexandreweb2@gmail.com',
    '🌐 https://fintab.info',
  ]),
  const Para(
      'Se você não estiver satisfeito com nossa resposta, pode procurar a **Autoridade Nacional de Proteção de Dados (ANPD)**: https://www.gov.br/anpd.'),
];

// ─────────────────────────────────────────────────────────────────────────────
// Content — English (en-US)
// ─────────────────────────────────────────────────────────────────────────────

final List<LegalBlock> _enPrivacy = <LegalBlock>[
  const Updated('Last updated: June 3, 2026'),
  const Para(
      'This policy explains, in plain language, what data Fintab collects, why, with whom we share it, and how you can exercise your rights under **GDPR** (EU 2016/679) and **LGPD** (Brazilian Law 13.709/2018).'),
  const Rule(),

  const Heading(2, '1. Who we are (Data Controller)'),
  const Para('Fintab is a personal finance app developed and operated by:'),
  const Bullets([
    '**Controller:** Alexandre Figueiredo F Costa Filho (individual developer trading as **VerticalTI**)',
    '**General contact:** alexandreweb2@gmail.com',
    '**Data Protection Officer (DPO):** Alexandre Figueiredo F Costa Filho — alexandreweb2@gmail.com',
  ]),
  const Para('You may contact the DPO at any time via the email above.'),

  const Heading(2, '2. What data we process'),
  const Heading(3, '2.1 Account & authentication data'),
  const Bullets([
    'Email (email/password signup, Sign in with Apple, or Google Sign-In)',
    'Display name (when provided by the login provider)',
    'Profile photo URL (when provided by the login provider)',
    'Unique UID generated by Firebase Authentication',
    'Password (email signup only; stored **only as a hash** by Firebase — we never access plaintext passwords)',
  ]),
  const Quote(
      'If you use **Sign in with Apple** and choose "Hide My Email", we only receive the relay address (`@privaterelay.appleid.com`). We treat this relay as a regular email.'),

  const Heading(3, '2.2 Financial data you record'),
  const Bullets([
    'Transactions (title, amount, type, category, date, description, wallet, tags)',
    'Wallets/accounts (name, icon, color, currency, type, initial balance)',
    'Custom categories',
    'Budgets (limits per category, month/year)',
    'Financial goals (title, target amount, deadline)',
    'Recurring transactions (Pro)',
  ]),

  const Heading(3, '2.3 Local notifications'),
  const Para(
      'The app may schedule local reminders on your device (e.g., recurring transaction alerts) with your permission. These reminders are processed **locally only**; no notification content is sent to our servers. On iOS, we **do not** read system or third-party app notifications.'),

  const Heading(3, '2.4 Pro subscription'),
  const Bullets([
    'Subscription status, product identifier, expiry date',
    '`purchaseToken` (sensitive token used to validate the purchase with Apple/Google)',
  ]),
  Para(
      'Payment itself is processed by ${isApplePlatform ? "the Apple App Store" : "the Apple App Store or Google Play"}. **We have no access to your credit card or payment method.**'),

  const Heading(3, '2.5 Account sharing (collaborators) — Pro'),
  const Para(
      'If you invite someone to share your account, we store: master\'s email and name, invitee\'s email, invitation status, and the collaborator\'s UID after acceptance.'),

  const Heading(3, '2.6 Data stored only on your device'),
  const Bullets([
    'App lock PIN (only **SHA-256 hash + salt** in Keychain/Keystore — never sent to any server)',
    'Lock flags (PIN active, biometrics active)',
    'UI preferences (currency, language, theme, dashboard layout, hidden wallets, financial literacy level)',
  ]),

  const Heading(3, '2.7 What we DO NOT collect'),
  const Bullets([
    'We do **not** use Google Analytics, Firebase Analytics, or Crashlytics.',
    'We do **not** track you across apps or websites (no IDFA / App Tracking Transparency).',
    'We do **not** sell your data.',
    'We do **not** use your financial data to train AI models.',
    'We do **not** display advertising inside the app.',
  ]),

  const Heading(2, '3. How we process data'),
  const Bullets([
    'Account and financial data are stored in **Cloud Firestore** (Google) under your UID.',
    'Communication between the app and Firestore is encrypted in transit (TLS 1.2+).',
    'At rest, data is encrypted by Google Cloud infrastructure (AES-256).',
    'The local PIN **never** leaves your device.',
  ]),

  const Heading(2, '4. Why we process (purpose + legal basis)'),
  const TableBlock([
    [
      'Account / authentication',
      '**Purpose:** Allow login and identify you in the app',
      '**GDPR legal basis:** Art. 6(1)(b) — Contract performance',
    ],
    [
      'Financial data',
      '**Purpose:** Core functionality: record and display your finances',
      '**GDPR legal basis:** Art. 6(1)(b) — Contract performance',
    ],
    [
      'Pro subscription',
      '**Purpose:** Validate active plan and unlock paid features',
      '**GDPR legal basis:** Art. 6(1)(b) — Contract performance',
    ],
    [
      'Sharing invitations',
      '**Purpose:** Allow two users to access the same account',
      '**GDPR legal basis:** Art. 6(1)(b) — Contract performance',
    ],
    [
      'Support communications',
      '**Purpose:** Reply to emails you send us',
      '**GDPR legal basis:** Art. 6(1)(f) — Legitimate interest',
    ],
  ]),
  const Para(
      'Under Brazilian LGPD the bases are equivalent: **Art. 7, V** (contract execution) and **Art. 7, IX** (legitimate interest).'),

  const Heading(2, '5. Sharing with third parties (subprocessors)'),
  const Para('We share the minimum necessary with the following processors:'),
  TableBlock([
    [
      '**Google LLC** — Firebase Authentication',
      '**Data shared:** Email, UID, password (hash), OAuth tokens',
      '**Purpose:** Authentication',
    ],
    [
      '**Google LLC** — Cloud Firestore',
      '**Data shared:** All financial data linked to UID',
      '**Purpose:** Backend storage',
    ],
    [
      '**Apple Inc.** — Sign in with Apple',
      '**Data shared:** Nonce; in return: identityToken + email + name (only on first login)',
      '**Purpose:** Authentication',
    ],
    [
      '**Apple Inc.** — App Store / StoreKit',
      '**Data shared:** `purchaseToken`, `productId`',
      '**Purpose:** Process and validate Pro subscription (iOS)',
    ],
    if (!isApplePlatform)
      [
        '**Google LLC** — Google Play Billing',
        '**Data shared:** `purchaseToken`, `productId`',
        '**Purpose:** Process and validate Pro subscription (Android)',
      ],
  ]),
  const Para(
      'There are no other subprocessors. No advertising, analytics, or attribution SDKs.'),
  const Heading(3, 'About the "share" function'),
  const Para(
      'When you export a report as PDF/Excel, the app uses the **OS-native share sheet**. The destination (email, Drive, WhatsApp, etc.) is chosen by you; Fintab does not send anything automatically to third parties.'),

  const Heading(2, '6. Where data is stored'),
  const Bullets([
    '**Cloud Firestore:** region `southamerica-east1` (São Paulo, Brazil).',
    'Firebase operational backups and logs may be processed in other Google Cloud regions under Standard Contractual Clauses, covering any international transfers under GDPR (Art. 46) and LGPD (Art. 33, II).',
    'Local data stays on your device only (Keychain/Keystore + SharedPreferences).',
  ]),

  const Heading(2, '7. How long we keep data'),
  const Bullets([
    '**While your account is active:** we keep all data needed for the app to work.',
    '**After account deletion:** personal and financial data linked to your UID is erased from Firestore within **30 days**. Google Cloud operational backups expire within another **90 days**.',
    '**Authentication logs** (Firebase Auth) are retained per Google\'s default period.',
    '**Local data** disappears when you uninstall the app.',
  ]),

  const Heading(2, '8. Your rights (GDPR Arts. 15–22 + LGPD Art. 18)'),
  const Para('At any time and free of charge you may:'),
  const Numbered([
    '**Confirm** whether we process data about you',
    '**Access** your data',
    '**Rectify** incomplete, inaccurate, or outdated data',
    '**Erase** data (right to be forgotten)',
    '**Restrict** processing',
    '**Port** your data to another provider',
    '**Object** to processing',
    '**Withdraw consent**',
    '**Lodge a complaint** with a supervisory authority',
  ]),
  const Heading(3, 'How to exercise each right'),
  const Bullets([
    '**Delete account + all data:** in the app, go to **Settings → Account → Delete Account**. Deletion is executed immediately after reauthentication.',
    '**Export your data (portability):** email alexandreweb2@gmail.com with subject "GDPR - Portability". We respond within **15 days**.',
    '**Other rights:** email alexandreweb2@gmail.com.',
  ]),

  const Heading(2, '9. Security'),
  const Para(
      'We apply technical and organizational measures to protect your data:'),
  const Bullets([
    '**In transit:** all communication between the app and backend uses TLS 1.2 or higher.',
    '**At rest:** Firestore encrypts all data by default (AES-256).',
    '**Passwords:** stored only as a hash by Firebase Authentication (scrypt). We have no access to plaintext passwords.',
    '**Local PIN:** stored as SHA-256 hash with random salt in Keychain (iOS) / Keystore (Android). Never leaves the device.',
    '**Biometrics:** Face ID / Touch ID are handled by the OS. Fintab never receives or stores biometric data.',
    '**Firestore security rules:** each user can only read and write data tied to their own UID.',
  ]),

  const Heading(2, '10. Children'),
  const Para(
      'Fintab is not directed at children under 13 and does not knowingly collect data from children. If you are a guardian and identified that a child provided us with data, contact alexandreweb2@gmail.com for removal.'),

  const Heading(2, '11. Auto-renewable Pro subscriptions'),
  Para(
      'Fintab Pro is an auto-renewable subscription processed by ${isApplePlatform ? "the Apple App Store" : "the Apple App Store (iOS) or Google Play (Android)"}. By subscribing:'),
  const Bullets([
    '**Renewal:** the subscription auto-renews at the end of each period (Monthly or Yearly) at the same price unless canceled at least **24 hours before** the current period ends.',
    '**Billing:** charged to your Apple/Google account at purchase confirmation and at each renewal.',
    '**Cancellation:** you can cancel at any time:',
  ]),
  Bullets([
    '**iPhone/iPad:** Settings → [your name] → Subscriptions → Fintab Pro → Cancel Subscription',
    if (!isApplePlatform)
      '**Android:** Google Play Store → ☰ → Subscriptions → Fintab Pro → Cancel',
  ], indent: true),
  const Bullets([
    '**Refunds:** refunds are processed exclusively by Apple/Google per their policies. We have no direct access to your payment.',
  ]),
  const Para(
      'See the Terms of Use (under Settings → About) for full subscription terms.'),

  const Heading(2, '12. Changes to this policy'),
  const Para(
      'We may update this policy as the app evolves or to reflect regulatory changes. When there\'s a relevant change, we\'ll update the **date at the top of this screen** and, if the change significantly affects your rights, we\'ll notify you in-app or by email.'),

  const Heading(2, '13. Other languages'),
  const Para(
      'This policy is available in **Portuguese (Brazil)** and **English (U.S.)**. To switch, change the app language under Settings → Language.'),

  const Heading(2, '14. Contact'),
  const Para('Questions, requests, or complaints about privacy?'),
  const Bullets([
    '📧 alexandreweb2@gmail.com',
    '🌐 https://fintab.info',
  ]),
  const Para(
      'If you are unsatisfied with our response, you may contact your local Data Protection Authority. In Brazil: **ANPD** at https://www.gov.br/anpd.'),
];
