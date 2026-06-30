# UI / design

- Fonte da verdade do visual: `docs/README.md` + `docs/DevDisk.dc.html`. Tokens (cores/tipografia/espaçamento) centralizados em `presentation/theme/{app_colors,app_text}.dart` — copiar hex de lá, não inventar.
- 3 fontes: **Space Grotesk** (display), **system** (UI), **JetBrains Mono** (mono/números/paths/kickers). São variáveis e bundladas — peso aplicado via `fontVariations` em `AppText`.
- O gauge é um `CustomPainter` bespoke (`disk_gauge.dart`); reusado em Idle/Scanning/Done.
- **Respeitar reduced-motion** (`MediaQuery.disableAnimations`): pular pro valor final, sem tweens/spins.
