# DevDisk — Brief de design: estados de loading

> Handoff para o time de design (claude design). Objetivo: desenhar o hi-fi de
> dois estados de carregamento que hoje existem só de forma funcional. O foco
> principal é o **loading da tela inicial (leitura do disco)**; o **progresso do
> esvaziar lixeira** entra como par visual para manter consistência.

## Contexto do produto

DevDisk é um app **macOS desktop** (Flutter) que escaneia "lixo de
desenvolvedor" (Xcode/CoreSimulator, Gradle, Android SDK/NDK, IDEs JetBrains,
Docker) e remove de forma **reversível** (vai pra Lixeira via Finder). Tema
**escuro**, estética técnica/sóbria, com um **gauge circular** (anel) como
elemento-herói. A janela útil tem layout em duas colunas: à esquerda o gauge
(~370px), à direita um painel de detalhes (~374px) separados por um divisor
vertical de 1px.

3 famílias tipográficas:
- **Space Grotesk** — display / números grandes (herói)
- **System** — texto de UI
- **JetBrains Mono** — números, paths, kickers (rótulos em caixa-alta espaçada)

---

## 1) Loading da tela inicial — "Lendo o disco" (FOCO)

### Comportamento (já implementado no app)
Ao abrir, o app calcula o detalhamento do disco rodando `df` (rápido) + 4
medições `du` sequenciais (lentas) sobre diretórios-âncora. **Agora isso reporta
progresso real**, em 5 passos de 20%:

| Passo | Medindo | Progresso ao concluir |
|------:|---------|----------------------:|
| 1 | `df /` (total/livre) | 20% |
| 2 | `~/Library/Developer` (Xcode) | 40% |
| 3 | `~/Library/Caches` | 60% |
| 4 | `~/Library/Android/sdk` | 80% |
| 5 | `~/Library/Application Support/JetBrains` + `Google` | 100% |

### Dados disponíveis em runtime (o que o front pode exibir)
- `progress`: `double` 0..1 (porcentagem real observada).
- `path`: `String?` — o caminho que está sendo medido **agora** (ex.:
  `/Users/<user>/Library/Caches`). É `null` no passo do `df` e no 100%.
- Mensagem localizada `readingDisk`: **"Lendo o disco…"** / **"Reading disk…"**.

> Tokens técnicos (paths) são **idênticos** em qualquer idioma — não traduzir.

### Estado atual (placeholder funcional — o que queremos melhorar)
Hoje renderiza um painel centralizado simples: kicker mono ("LENDO O DISCO…"),
número grande em Space Grotesk (`72px`) com "%" menor, uma `LinearProgressIndicator`
fina (5px) e o path em mono abaixo. Funciona, mas é genérico — queremos um
tratamento hi-fi à altura do gauge.

```
        LENDO O DISCO…

        62%
        ▁▁▁▁▁▁▁▁▁▁▁▁▁▁░░░░░░░
        /Users/dener/Library/Caches
```

### O que pedimos ao design
Um estado de carregamento que:
1. Comunique **porcentagem real** + **mensagem** + **path atual** com hierarquia
   clara e sensação "de máquina" (medindo o disco), sem parecer travado.
2. **Idealmente converse com o gauge** — ele é o herói da tela "pronta". Opções
   a explorar (escolha livre, proponha a melhor):
   - O **anel do gauge se preenchendo** de 0→100% conforme `progress`, com o
     número no centro (igual ao readout final, que mostra "USADO").
   - Um **skeleton** das 6 linhas de legenda (categorias) à direita,
     preenchendo conforme cada `du` conclui.
   - Os **segmentos do gauge aparecendo um a um** (Xcode → Caches → Android →
     AppSupport) à medida que cada categoria é medida.
3. Faça uma transição agradável loading → estado pronto (o gauge final já anima
   de `progress` 0→1 ao chegar os dados).

### Constraints
- **Determinístico** (a barra/anel reflete `progress`, não é spinner infinito).
- **Reduced-motion**: respeitar `MediaQuery.disableAnimations` — sem tweens/giros,
  pular direto pro valor. Forneça a versão estática.
- Apenas as 3 fontes acima; cores **somente** dos tokens abaixo.
- O número nunca finge 100% antes de terminar de verdade.

---

## 2) Progresso do "Esvaziar Lixeira" (par visual, já implementado)

Na tela **Concluído** (após a limpeza), o botão **"Esvaziar a Lixeira"** é a
única ação **permanente**. Ao confirmar, ele é substituído **in-place** (mesma
caixa de 46px de altura) por uma barra de progresso com porcentagem **real**
(medimos a Lixeira encolher via `du` enquanto o Finder apaga).

- Mensagem `emptying`: **"Esvaziando a Lixeira…"** / **"Emptying the Trash…"**
- `progress` 0..1; clampado em 99% durante a medição, 100% só ao concluir.
- Paleta: **danger** (vermelho), por ser ação permanente.

Pedido: refinar essa micro-UI (rótulo + "NN%" + barra) coerente com o item 1,
mas mantendo o **código de cor de perigo** (não usar o azul de accent aqui).

---

## Tokens (tema escuro — fonte da verdade)

### Cores relevantes (hex)
**Superfícies / bordas**
- page gradient (radial): `#131218` → `#0C0B0F` → `#090809`
- divisor vertical: `divider #211E29`
- trilho do gauge: `gaugeTrack #211E2A`

**Tinta (claro → fraco)**
- `heroInk #F4F1EA` (número herói) · `heroInk2 #F2EEE7`
- `secondary #C7C2CC` · `bodyDim #A39EAA` · `faint #8B8693`
- `faintest #6F6A78` (kickers/paths fracos) · `faintest2 #5A5563`

**Accent (azul aço) — usar no loading do disco**
- `accent #6FA0D9` · `accentMono #9CC0EA` · `accentLight #7AAAE0` ·
  `accentDark #5E8BC9` · `accentDeep #3E5E86`
- gradiente accent: vertical `accentLight → accentDark`

**Perigo — usar no esvaziar lixeira**
- `danger #E58379` · `dangerBright #EC9085`

**Categorias do gauge (legendas/segmentos)**
- xcode `#5C8AC9` · caches `#4FA39A` · androidSdk `#7FA85A` ·
  appSupport `#C8924E` · other `#5A5764` · free `#34313D`

### Tipografia (referência de uso atual)
- Kicker mono: `JetBrains Mono`, ~11px, `letterSpacing: 2`, caixa-alta, `faintest`.
- Número herói: `Space Grotesk`, 72–88px, peso ~700, `letterSpacing` negativo, `heroInk`.
- Unidade ("%", "GB"): `Space Grotesk` ~28–34px, peso 600, `accentMono`.
- Path/sub: `JetBrains Mono`, ~11.5px, `faintest`, 1 linha com ellipsis.

---

## Entregáveis esperados
1. Layout hi-fi do **loading da tela inicial** (estados 0%, ~50%, 100%) — animado
   e versão reduced-motion.
2. Como ele **transiciona** para a tela pronta (gauge + legendas).
3. Refino do **progresso de esvaziar lixeira** (em paleta danger).
4. Specs de espaçamento/tamanhos suficientes pra reimplementar em Flutter
   (reaproveitando os tokens acima).

> Layout da janela: duas colunas (gauge ~370px | painel ~374px) separadas por
> divisor de 1px. O loading pode ocupar a área toda **ou** já adotar a moldura de
> duas colunas — proponha o que ficar melhor.
