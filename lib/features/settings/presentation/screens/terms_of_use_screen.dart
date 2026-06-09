import 'package:flutter/material.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/utils/platform_store.dart';
import 'legal_document.dart';

/// Full Terms of Use rendered natively inside the app (no external link / webview).
///
/// Content mirrors the official web versions (fintab.info/terms and /terms-en).
/// Language follows the app locale: Portuguese for `pt`, English otherwise
/// (so `es` users fall back to English).
class TermsOfUseScreen extends StatelessWidget {
  const TermsOfUseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isPt = AppLocalizations.of(context).locale.languageCode == 'pt';
    return LegalDocumentScreen(
      title: isPt ? 'Termos de Uso' : 'Terms of Use',
      blocks: isPt ? _ptTerms : _enTerms,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Content — Portuguese (pt-BR)
// ─────────────────────────────────────────────────────────────────────────────

final List<LegalBlock> _ptTerms = <LegalBlock>[
  const Updated('Última atualização: 3 de junho de 2026'),
  const Para(
      'Bem-vindo ao Fintab. Estes Termos de Uso ("Termos") regulam a sua relação com o Fintab, aplicativo de finanças pessoais desenvolvido por **Alexandre Figueiredo F Costa Filho** (atuando sob a marca **VerticalTI**), CPF cadastrado junto à Receita Federal do Brasil ("nós", "Fintab"). Ao baixar, instalar ou usar o app, você concorda integralmente com estes Termos.'),
  const Rule(),

  const Heading(2, '1. Definições e aceitação'),
  Bullets([
    '**"App" ou "Fintab":** o aplicativo móvel Fintab para iOS e Android, incluindo todas as versões futuras.',
    '**"Você" / "Usuário":** pessoa física que baixa, instala ou usa o Fintab.',
    '**"Pro":** plano de assinatura pago que desbloqueia funcionalidades premium.',
    '**"Loja":** ${isApplePlatform ? "Apple App Store" : "Apple App Store (iOS) ou Google Play Store (Android)"}.',
  ]),
  const Para(
      'Ao instalar, criar conta ou usar o Fintab, você declara ter **13 anos ou mais** e concordar com estes Termos. Se não concorda, não use o app.'),

  const Heading(2, '2. Licença de uso'),
  const Para(
      'Concedemos a você uma licença **não exclusiva, intransferível, revogável e gratuita** para usar o Fintab apenas para fins pessoais e não comerciais, em dispositivos que você possui ou controla.'),
  const Para('Você **não pode**:'),
  const Bullets([
    'Sublicenciar, alugar, vender ou ceder o app ou sua conta a terceiros',
    'Fazer engenharia reversa, descompilar ou tentar extrair o código-fonte',
    'Modificar, copiar ou criar trabalhos derivados',
    'Remover ou alterar marcas, logos ou avisos de direitos autorais',
    'Usar o app para finalidade ilegal ou que viole direitos de terceiros',
  ]),

  const Heading(2, '3. Conta de usuário'),
  const Para(
      'Para usar o Fintab é necessário criar uma conta via e-mail/senha, Sign in with Apple ou Google Sign-In. Você é responsável por:'),
  const Bullets([
    'Fornecer informações verdadeiras e mantê-las atualizadas',
    'Manter a confidencialidade da sua senha',
    'Toda a atividade que ocorre na sua conta',
    'Notificar-nos imediatamente em caso de uso não autorizado',
  ]),
  const Para('Podemos suspender ou encerrar contas que violem estes Termos.'),

  const Heading(2, '4. Conduta proibida'),
  const Para('Você concorda em não:'),
  const Bullets([
    'Usar o Fintab para finalidade ilegal, fraudulenta ou que cause dano',
    'Tentar acessar contas de outros usuários',
    'Interferir, sobrecarregar ou comprometer a segurança do app ou de nossos servidores',
    'Usar bots, scrapers ou outras formas automatizadas de acesso sem nosso consentimento',
    'Inserir dados que infrinjam direitos de terceiros',
  ]),

  const Heading(2, '5. Propriedade intelectual'),
  const Para(
      'O Fintab — incluindo código-fonte, design, marca, logotipo, ícones, conteúdo e documentação — é de propriedade exclusiva de **Alexandre Figueiredo F Costa Filho (VerticalTI)** e está protegido pela legislação brasileira e internacional de direitos autorais e propriedade intelectual.'),
  const Para(
      'Os **seus dados financeiros pessoais** (transações, orçamentos, metas, categorias) **continuam pertencendo a você**. Você nos concede apenas a licença mínima necessária para armazenar, processar e exibir esses dados conforme nossa Política de Privacidade.'),

  const Heading(2, '6. Assinatura Fintab Pro'),
  const Para(
      'O Fintab oferece um plano pago chamado **Fintab Pro**, em duas modalidades:'),
  const Bullets([
    '**Mensal:** R\$ 4,90/mês',
    '**Anual:** R\$ 49,90/ano (~R\$ 4,16/mês)',
  ]),
  const Para(
      '(Os preços podem variar conforme o tier vigente da Apple/Google e por país. Preço final exibido pela loja prevalece.)'),
  const Heading(3, '6.1 Renovação automática'),
  const Bullets([
    'A assinatura é **renovada automaticamente** ao final de cada período pelo mesmo valor.',
    'Para evitar a renovação, cancele **até 24 horas antes** do término do período atual.',
    'A cobrança ocorre na sua conta da loja (Apple ou Google) na confirmação da compra e a cada renovação.',
  ]),
  const Heading(3, '6.2 Cancelamento'),
  const Para('Você pode cancelar a qualquer momento:'),
  Bullets([
    '**iPhone/iPad:** Ajustes → [seu nome] → Assinaturas → Fintab Pro → Cancelar Assinatura',
    if (!isApplePlatform)
      '**Android:** Google Play Store → ☰ → Assinaturas → Fintab Pro → Cancelar',
  ]),
  const Para(
      'Após o cancelamento, você continua com acesso Pro até o fim do período já pago.'),
  const Heading(3, '6.3 Reembolso'),
  const Para(
      'Reembolsos são processados exclusivamente pela Apple ou Google, conforme as políticas de cada loja:'),
  const Bullets([
    '**Apple:** https://reportaproblem.apple.com',
    '**Google:** https://support.google.com/googleplay/answer/2479637',
  ]),
  const Para(
      'Não temos acesso direto ao seu pagamento e não emitimos reembolso por fora da loja.'),
  const Heading(3, '6.4 Alteração de preço'),
  const Para(
      'Se alterarmos o preço da assinatura, você será notificado antes da próxima renovação e poderá cancelar antes de a alteração entrar em vigor.'),

  const Heading(2, '7. EULA — Apple Standard End User License Agreement'),
  const Para(
      'Para usuários iOS, esta seção complementa os Termos com as cláusulas obrigatórias da Apple. O Fintab adota o **Apple Standard EULA**, disponível em https://www.apple.com/legal/internet-services/itunes/dev/stdeula/, com os seguintes esclarecimentos:'),
  const Numbered([
    '**O contrato é entre você e o Fintab** (Alexandre Figueiredo F Costa Filho), não entre você e a Apple. O Fintab é o único responsável pelo app e seu conteúdo.',
    '**A Apple não tem obrigação** de prestar serviços de manutenção ou suporte ao app.',
    '**A Apple não tem responsabilidade** por qualquer garantia, expressa ou implícita, sobre o app.',
    '**A Apple não tem responsabilidade** por reclamações relacionadas ao app, incluindo (mas não limitado a): reclamações de responsabilidade pelo produto, reclamações de não conformidade com requisitos legais ou regulatórios, ou reclamações de proteção ao consumidor.',
    '**A Apple não tem responsabilidade** por investigação, defesa, acordo ou pagamento de qualquer reclamação de terceiros de que o app viole direitos de propriedade intelectual de terceiros.',
    '**A Apple e suas subsidiárias são terceiros beneficiários** destes Termos e, ao aceitar, você concorda que a Apple tem o direito de fazer cumprir estes Termos contra você como terceiro beneficiário.',
  ]),

  const Heading(2, '8. Disclaimer e ausência de aconselhamento financeiro'),
  const Para(
      'O Fintab é uma ferramenta de **organização pessoal**. Não somos consultores financeiros, contadores ou advogados.'),
  const Para(
      'O app é fornecido **"COMO ESTÁ" (AS IS)**, sem garantias de qualquer tipo, expressas ou implícitas, incluindo garantias de comerciabilidade, adequação a um propósito específico ou não violação. Não garantimos:'),
  const Bullets([
    'Que o app estará livre de erros ou interrupções',
    'Que os cálculos e relatórios sejam precisos para fins fiscais ou contábeis',
    'Resultados financeiros específicos a partir do uso do app',
  ]),
  const Para(
      'Consulte sempre profissionais qualificados antes de tomar decisões financeiras ou tributárias importantes.'),

  const Heading(2, '9. Limitação de responsabilidade'),
  const Para(
      'Na máxima extensão permitida pela legislação brasileira (CDC Lei 8.078/90 respeitado), o Fintab e seus desenvolvedores **não são responsáveis por**:'),
  const Bullets([
    'Perdas indiretas, incidentais, consequenciais ou lucros cessantes',
    'Perda de dados decorrente de causa fora do nosso controle razoável',
    'Decisões financeiras que você tome com base em informações do app',
    'Indisponibilidade temporária por manutenção, falhas de terceiros (Apple, Google, Firebase) ou força maior',
  ]),
  const Para(
      'Nada nestes Termos limita responsabilidades que, por força de lei, não podem ser excluídas.'),

  const Heading(2, '10. Modificações dos Termos'),
  const Para(
      'Podemos atualizar estes Termos a qualquer momento. Mudanças relevantes serão comunicadas dentro do app ou por e-mail com pelo menos **30 dias de antecedência**. O uso continuado após a vigência das mudanças constitui aceite. Se discordar, encerre sua conta.'),

  const Heading(2, '11. Rescisão'),
  const Para(
      'Você pode encerrar sua conta a qualquer momento em **Ajustes → Conta → Excluir conta**. Podemos suspender ou encerrar sua conta sem aviso prévio se você violar estes Termos.'),
  const Para(
      'Após o encerramento, os efeitos das seções 5 (Propriedade Intelectual), 8 (Disclaimer), 9 (Limitação de Responsabilidade) e 13 (Lei aplicável) sobrevivem.'),

  const Heading(2, '12. Suporte'),
  const Para(
      'Dúvidas, sugestões ou problemas? Envie e-mail para alexandreweb2@gmail.com. Respondemos em até **5 dias úteis**.'),

  const Heading(2, '13. Lei aplicável e foro'),
  const Para(
      'Estes Termos são regidos pelas leis da **República Federativa do Brasil**. Para conflitos de consumo, fica eleito o foro do **domicílio do consumidor** (CDC Art. 101, I). Demais litígios: foro da Comarca de domicílio do desenvolvedor.'),

  const Heading(2, '14. Privacidade'),
  const Para(
      'O tratamento dos seus dados pessoais está descrito em detalhe na nossa Política de Privacidade (em Ajustes → Sobre), que é parte integrante destes Termos.'),

  const Heading(2, '15. Disposições gerais'),
  const Bullets([
    '**Acordo integral:** estes Termos + a Política de Privacidade representam o acordo completo entre você e o Fintab sobre o uso do app.',
    '**Independência das cláusulas:** se alguma cláusula for considerada inválida, as demais permanecem em vigor.',
    '**Não renúncia:** o não exercício de qualquer direito não implica renúncia ao mesmo.',
    '**Cessão:** você não pode ceder estes Termos. Podemos cedê-los em caso de reorganização societária ou venda, mediante aviso prévio razoável.',
  ]),

  const Heading(2, '16. Outros idiomas'),
  const Para(
      'Estes Termos estão disponíveis em **Português (Brasil)** e **English (U.S.)**. Para trocar, altere o idioma do app em Ajustes → Idioma.'),
  const Rule(),
  const Para(
      'Ao continuar usando o Fintab, você confirma que leu e concorda com estes Termos.'),
];

// ─────────────────────────────────────────────────────────────────────────────
// Content — English (en-US)
// ─────────────────────────────────────────────────────────────────────────────

final List<LegalBlock> _enTerms = <LegalBlock>[
  const Updated('Last updated: June 3, 2026'),
  const Para(
      'Welcome to Fintab. These Terms of Use ("Terms") govern your relationship with Fintab, a personal finance app developed by **Alexandre Figueiredo F Costa Filho** (trading as **VerticalTI**), an individual developer registered with the Brazilian Federal Revenue Service ("we", "Fintab"). By downloading, installing, or using the app, you fully agree to these Terms.'),
  const Rule(),

  const Heading(2, '1. Definitions and acceptance'),
  Bullets([
    '**"App" or "Fintab":** the Fintab mobile application for iOS and Android, including all future versions.',
    '**"You" / "User":** the individual who downloads, installs, or uses Fintab.',
    '**"Pro":** the paid subscription plan that unlocks premium features.',
    '**"Store":** ${isApplePlatform ? "Apple App Store" : "Apple App Store (iOS) or Google Play Store (Android)"}.',
  ]),
  const Para(
      'By installing, creating an account, or using Fintab, you confirm you are **13 years or older** and agree to these Terms. If you don\'t agree, don\'t use the app.'),

  const Heading(2, '2. License to use'),
  const Para(
      'We grant you a **non-exclusive, non-transferable, revocable, and free** license to use Fintab for personal, non-commercial purposes only, on devices you own or control.'),
  const Para('You **may not**:'),
  const Bullets([
    'Sublicense, rent, sell, or transfer the app or your account to third parties',
    'Reverse engineer, decompile, or attempt to extract the source code',
    'Modify, copy, or create derivative works',
    'Remove or alter trademarks, logos, or copyright notices',
    'Use the app for illegal purposes or to violate third-party rights',
  ]),

  const Heading(2, '3. User account'),
  const Para(
      'To use Fintab you must create an account via email/password, Sign in with Apple, or Google Sign-In. You are responsible for:'),
  const Bullets([
    'Providing truthful information and keeping it up to date',
    'Maintaining the confidentiality of your password',
    'All activity that occurs in your account',
    'Notifying us immediately of any unauthorized use',
  ]),
  const Para('We may suspend or terminate accounts that violate these Terms.'),

  const Heading(2, '4. Prohibited conduct'),
  const Para('You agree not to:'),
  const Bullets([
    'Use Fintab for illegal, fraudulent, or harmful purposes',
    'Attempt to access other users\' accounts',
    'Interfere with, overload, or compromise the security of the app or our servers',
    'Use bots, scrapers, or other automated means without our consent',
    'Submit data that infringes third-party rights',
  ]),

  const Heading(2, '5. Intellectual property'),
  const Para(
      'Fintab — including source code, design, brand, logo, icons, content, and documentation — is the exclusive property of **Alexandre Figueiredo F Costa Filho (VerticalTI)** and is protected by Brazilian and international copyright and intellectual property laws.'),
  const Para(
      '**Your personal financial data** (transactions, budgets, goals, categories) **remains yours**. You grant us only the minimum license needed to store, process, and display this data per our Privacy Policy.'),

  const Heading(2, '6. Fintab Pro subscription'),
  const Para(
      'Fintab offers a paid plan called **Fintab Pro**, in two tiers (prices in Brazilian Real for the Brazilian storefront — equivalent pricing applies in other regions per Apple/Google tier):'),
  const Bullets([
    '**Monthly:** R\$ 4.90/month',
    '**Yearly:** R\$ 49.90/year (~R\$ 4.16/month)',
  ]),
  const Para('Final price shown by the store prevails.'),
  const Heading(3, '6.1 Auto-renewal'),
  const Bullets([
    'The subscription **auto-renews** at the end of each period at the same price.',
    'To avoid renewal, cancel **at least 24 hours before** the current period ends.',
    'You are billed via your Apple or Google account at purchase confirmation and at each renewal.',
  ]),
  const Heading(3, '6.2 Cancellation'),
  const Para('You can cancel at any time:'),
  Bullets([
    '**iPhone/iPad:** Settings → [your name] → Subscriptions → Fintab Pro → Cancel Subscription',
    if (!isApplePlatform)
      '**Android:** Google Play Store → ☰ → Subscriptions → Fintab Pro → Cancel',
  ]),
  const Para(
      'After cancellation, you keep Pro access until the end of the period already paid.'),
  const Heading(3, '6.3 Refunds'),
  const Para(
      'Refunds are processed exclusively by Apple or Google per each store\'s policy:'),
  const Bullets([
    '**Apple:** https://reportaproblem.apple.com',
    '**Google:** https://support.google.com/googleplay/answer/2479637',
  ]),
  const Para(
      'We have no direct access to your payment and don\'t issue refunds outside the store.'),
  const Heading(3, '6.4 Price changes'),
  const Para(
      'If we change the subscription price, you\'ll be notified before the next renewal and can cancel before the change takes effect.'),

  const Heading(2, '7. EULA — Apple Standard End User License Agreement'),
  const Para(
      'For iOS users, this section supplements the Terms with Apple\'s required clauses. Fintab adopts the **Apple Standard EULA**, available at https://www.apple.com/legal/internet-services/itunes/dev/stdeula/, with the following clarifications:'),
  const Numbered([
    '**The agreement is between you and Fintab** (Alexandre Figueiredo F Costa Filho), not between you and Apple. Fintab is solely responsible for the app and its content.',
    '**Apple has no obligation** to provide maintenance or support services for the app.',
    '**Apple has no responsibility** for any warranties, express or implied, regarding the app.',
    '**Apple has no responsibility** for claims relating to the app, including (but not limited to): product liability claims, claims that the app fails to conform to legal or regulatory requirements, or claims arising under consumer protection law.',
    '**Apple has no responsibility** for investigation, defense, settlement, or discharge of any third-party claim that the app infringes third-party intellectual property rights.',
    '**Apple and its subsidiaries are third-party beneficiaries** of these Terms and, upon acceptance, you agree that Apple has the right to enforce these Terms against you as a third-party beneficiary.',
  ]),

  const Heading(2, '8. Disclaimer and no financial advice'),
  const Para(
      'Fintab is a **personal organization tool**. We are not financial advisors, accountants, or lawyers.'),
  const Para(
      'The app is provided **"AS IS"**, without warranties of any kind, express or implied, including warranties of merchantability, fitness for a particular purpose, or non-infringement. We do not guarantee:'),
  const Bullets([
    'That the app will be error-free or uninterrupted',
    'That calculations and reports are accurate for tax or accounting purposes',
    'Specific financial outcomes from using the app',
  ]),
  const Para(
      'Always consult qualified professionals before making important financial or tax decisions.'),

  const Heading(2, '9. Limitation of liability'),
  const Para(
      'To the maximum extent permitted by law, Fintab and its developers are **not liable for**:'),
  const Bullets([
    'Indirect, incidental, consequential, or punitive damages, or lost profits',
    'Data loss due to causes beyond our reasonable control',
    'Financial decisions you make based on app information',
    'Temporary unavailability due to maintenance, third-party failures (Apple, Google, Firebase), or force majeure',
  ]),
  const Para(
      'Nothing in these Terms limits liabilities that, by law, cannot be excluded (including Brazilian Consumer Protection Code where applicable).'),

  const Heading(2, '10. Changes to these Terms'),
  const Para(
      'We may update these Terms at any time. Material changes will be communicated in-app or by email at least **30 days in advance**. Continued use after the effective date constitutes acceptance. If you disagree, terminate your account.'),

  const Heading(2, '11. Termination'),
  const Para(
      'You can terminate your account at any time at **Settings → Account → Delete Account**. We may suspend or terminate your account without prior notice if you violate these Terms.'),
  const Para(
      'After termination, sections 5 (Intellectual Property), 8 (Disclaimer), 9 (Limitation of Liability), and 13 (Governing Law) survive.'),

  const Heading(2, '12. Support'),
  const Para(
      'Questions, suggestions, or issues? Email alexandreweb2@gmail.com. We respond within **5 business days**.'),

  const Heading(2, '13. Governing law and venue'),
  const Para(
      'These Terms are governed by the laws of the **Federative Republic of Brazil**. For consumer disputes, the venue is the **consumer\'s domicile** (Brazilian Consumer Protection Code, Art. 101, I). Other disputes: developer\'s domicile.'),

  const Heading(2, '14. Privacy'),
  const Para(
      'How we handle your personal data is detailed in our Privacy Policy (under Settings → About), which is an integral part of these Terms.'),

  const Heading(2, '15. General provisions'),
  const Bullets([
    '**Entire agreement:** these Terms + the Privacy Policy represent the complete agreement between you and Fintab regarding use of the app.',
    '**Severability:** if any clause is found invalid, the remaining clauses remain in effect.',
    '**No waiver:** failure to enforce any right does not constitute waiver of that right.',
    '**Assignment:** you may not assign these Terms. We may assign them in case of corporate reorganization or sale, with reasonable prior notice.',
  ]),

  const Heading(2, '16. Other languages'),
  const Para(
      'These Terms are available in **English (U.S.)** and **Portuguese (Brazil)**. To switch, change the app language under Settings → Language.'),
  const Rule(),
  const Para(
      'By continuing to use Fintab, you confirm you have read and agree to these Terms.'),
];
