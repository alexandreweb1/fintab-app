# Fintab — Ficha App Store (pt-BR) — pronta para colar

> Gerada por processo multi-agente (4 estratégias → painel de juízes → síntese → verificação de
> limites e compliance Apple). Limites conferidos de forma determinística.
> **Versão segura para iOS**: a captura por *notificação do banco* é Android-only; no iOS o
> herói é **valor copiado** (clipboard) + **compartilhamento** (Share Extension). Os textos abaixo
> já evitam prometer leitura de notificação no iPhone (Guideline 2.3.1).

---

## Campos (App Store Connect → App Information / Version)

### Nome do app (App Name) — 26/30
```
Fintab: Controle de Gastos
```

### Subtítulo (Subtitle) — 29/30
```
Copie o valor e lance sozinho
```
> Alternativa, se preferir clareza a manter as palavras-chave "copie/valor":
> `Seus gastos lançados sozinhos` (29/30).

### Palavras-chave (Keywords) — 98/100 — vírgula SEM espaço
```
orçamento,dinheiro,financeiro,carteira,fatura,crédito,boleto,extrato,poupar,casal,familia,parcelas
```
> Regra de ouro: a Apple indexa **Nome + Subtítulo + Keywords** como um só conjunto.
> Não repita aqui nenhuma palavra do nome/subtítulo (já checado: zero sobreposição).
> "controle" e "gastos" já vêm do nome; "copie/valor/lance/sozinho" já vêm do subtítulo.

### Texto promocional (Promotional Text) — ~142/170 — atualizável sem revisão
```
Pare de digitar os gastos. Copiou um valor? O Fintab detecta e lança a transação sozinho. Controle suas finanças no automático — baixe grátis.
```

### Descrição (Description) — ~2.5k/4000
```
Cansado de esquecer de anotar os gastos? O Fintab registra por você.

Copiou um valor — no app do banco, num comprovante ou numa mensagem? O Fintab detecta e lança a transação na hora, sem você digitar. Completo de verdade, mas simples no dia a dia.

⚡ REGISTRE GASTOS SEM DIGITAR
• Copiou um valor? O Fintab detecta e sugere o lançamento na hora
• Compartilhe um texto (comprovante, mensagem) com o app e ele vira transação
• No Android, o Fintab ainda lê a notificação do banco e lança sozinho (opcional)
• Widget na tela inicial e atalho rápido (segure o ícone → Novo lançamento)
• Você no controle: a captura automática é opcional e fica sob seu comando

E quando quiser lançar na mão, leva menos de um minuto.

📊 GRÁTIS PARA SEMPRE
• Receitas e despesas em segundos
• Dashboard com saldo, últimas transações e próximas contas — arraste e oculte os cards
• Extrato completo e relatórios com gráficos
• Categorias prontas para começar agora
• Bloqueio com PIN e biometria (Face ID / Touch ID)
• Sincronização na nuvem entre celular, tablet e web
• Login com Apple e Google

🧭 FEITO PARA O SEU NÍVEL
Iniciante ou avançado? No primeiro acesso o Fintab pergunta o seu jeito de lidar com dinheiro e se adapta a você. Sem jargão, sem complicação. Bem-vindo ao Fintab! 👋

🚀 FINTAB PRO
Para quem quer ir além:
• Múltiplas carteiras (conta, poupança, dinheiro físico…)
• Categorias ilimitadas com ícone e cor
• Orçamentos por categoria em tempo real
• Metas financeiras (viagem, reserva de emergência…)
• Visão anual com comparativos mês a mês
• Transações recorrentes (aluguel, salário, assinaturas)
• Compartilhe as finanças com o casal ou a família, na mesma conta, em tempo real
• Tags livres para organizar do seu jeito
• Importação de extratos OFX/CSV do banco
• Exportação de relatórios em PDF e Excel
• Saúde financeira: um score de 0 a 100 que mostra como você está

💚 Verde, leve e brasileiro. O Fintab te ajuda a entender para onde vai o seu dinheiro — e a sobrar mais no fim do mês.

Baixe agora e comece lançando sua primeira transação.

—

O Fintab Pro é uma assinatura auto-renovável, de duração mensal ou anual.
• Mensal: R$ 4,90 (com 7 dias grátis)
• Anual: R$ 49,90 (≈ R$ 4,16/mês — economize 15%)

O pagamento é cobrado na sua conta da App Store na confirmação da compra. A assinatura renova automaticamente, a menos que seja cancelada com pelo menos 24 horas de antecedência ao fim do período. Gerencie ou cancele a qualquer momento nos Ajustes da sua conta. Os recursos gratuitos continuam liberados.

Termos de Uso: https://fintab.info
Política de Privacidade: https://fintab.info
```

### Novidades desta versão (What's New) — v1.0.5
```
Deixamos o Fintab ainda mais rápido e estável para você:

• Captura automática de gastos mais certeira
• Sincronização na nuvem mais ágil entre seus aparelhos
• Pequenos ajustes na tela inicial e nos relatórios
• Correção de erros e melhorias de desempenho

Obrigado por usar o Fintab! Tem alguma sugestão? A gente adora ouvir você. 💚
```

### Categorias
- Primária: **Finanças**
- Secundária: **Produtividade**

### URLs
- Marketing / Suporte / Privacidade: `https://fintab.info`

---

## Plano de screenshots (ordem de impacto — o 1º é o que mais converte)

| # | Tela a capturar | Texto grande (headline) | Apoio |
|---|---|---|---|
| 1 | Detecção de **valor copiado** sobre a home — banner "Detectamos R$ X → Lançar" (fluxo real no iOS) | Seu gasto, lançado sozinho | Copiou um valor? O Fintab detecta e lança por você |
| 2 | Dashboard (saldo, carteiras, últimas transações, próximas recorrências) | Tudo do seu dinheiro num só lugar | Saldo, contas e transações em tempo real |
| 3 | Novo lançamento preenchido em poucos toques | Lance um gasto em segundos | Receita ou despesa, sem complicação |
| 4 | Relatórios (pizza/barras por categoria e período) | Veja para onde vai o seu dinheiro | Gráficos claros, sem planilha |
| 5 | Orçamentos por categoria (barras em tempo real) | Orçamentos que avisam na hora | Acompanhe cada categoria em tempo real (Pro) |
| 6 | Saúde financeira (medidor 0–100) | Sua saúde financeira de 0 a 100 | Saiba na hora como você está (Pro) |
| 7 | Compartilhamento (casal na mesma conta) + ícone Face ID | Finanças a dois, protegidas | Mesma conta em tempo real, com Face ID e PIN (Pro) |
| 8 | Onboarding de nível financeiro | Feito para o seu nível | O Fintab se adapta a você desde o início |

> ⚠️ Screenshot 1 deve retratar o fluxo de **valor copiado / compartilhado** (real no iOS),
> nunca leitura automática de notificação do banco (Android-only) — senão cai na Guideline 2.3.3.

---

## ⚠️ Verificar antes de submeter
1. **Share Extension iOS** está ativa no build? (O target existe no repo, mas pode faltar o passo de
   Xcode.) Se não estiver, o bullet "Compartilhe um texto… vira transação" não funciona no iPhone —
   remova-o ou conclua a configuração. O fluxo de **valor copiado** funciona sem nada extra.
2. Screenshot 1 coerente com o fluxo de valor copiado (não notificação).
3. App demo/credenciais e "Notas para a Revisão" preenchidas no App Store Connect.

---

## Apple Search Ads — onde colocar os R$ 200 (alta intenção primeiro)
Comece com **correspondência exata** e teto diário baixo (~R$ 15–20/dia) para durar ~10 dias:
- `controle de gastos`, `controle financeiro`, `organizar finanças`, `app de finanças`
- `controle de despesas`, `finanças pessoais`, `gastos`, `orçamento`
- Defesa de marca: `fintab`
Pause os termos sem instalação após 3–4 dias e concentre no que converter.
