# UI / design

- Source of truth for the visuals: `docs/README.md` + `docs/DevDisk.dc.html`. Tokens (colors/typography/spacing) centralized in `presentation/theme/{app_colors,app_text}.dart` — copy hex from there, don't invent.
- 3 fonts: **Space Grotesk** (display), **system** (UI), **JetBrains Mono** (mono/numbers/paths/kickers). They are variable and bundled — weight applied via `fontVariations` in `AppText`.
- The gauge is a bespoke `CustomPainter` (`disk_gauge.dart`); reused in Idle/Scanning/Done.
- **Respect reduced-motion** (`MediaQuery.disableAnimations`): jump to the final value, no tweens/spins.
