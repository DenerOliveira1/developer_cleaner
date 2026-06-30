# Handoff: DevDisk — macOS developer disk cleaner

## Overview
DevDisk is a macOS desktop app (distributed outside the Mac App Store as a notarized DMG) that lets **developers** reclaim disk space by deleting dev junk: Xcode/CoreSimulator caches, Android SDK/NDK, old IDE versions (JetBrains, Android Studio), Docker layers. Audience: senior, demanding developers who trust precision tools (DaisyDisk/CleanMyMac) but dislike noisy "cleaner app" UI.

The main screen does three jobs:
1. Give an instant, trustworthy read of the disk (used/free + per-category breakdown).
2. Give granular control over what to delete, with **explicit risk** per item.
3. Deliver a clear emotional payoff at the end — how much space came back.

Everything communicates **safety**: nothing is hard-deleted; items move to the Trash and are recoverable until the Trash is emptied.

The signature element is a **disk gauge as a diagnostic instrument** — a segmented ring with an engineering tick scale and monospace numbers, NOT a generic dashboard donut. The same gauge is the hero on the Idle screen and animates "reclaiming" space on the Done screen; that continuity is the app's visual memory.

## About the Design Files
The file in this bundle (`DevDisk.dc.html`) is a **design reference created in HTML** — a working prototype that shows the intended look, motion, and behavior. It is **not production code to copy directly**. The task is to **recreate this design in the target codebase's environment** using its established patterns.

Because this is a native macOS app, the natural target is **SwiftUI** (or AppKit). The gauge would be a `Canvas`/`Shape` drawing, the rows a `List`/`LazyVStack`, the modals `.sheet`/`.alert` or a custom overlay. If you instead ship this as a web-tech desktop app (Electron/Tauri), recreate it in that stack's component model. Either way, reproduce the **visual spec and interaction model** below — don't transplant the HTML.

The prototype is built as a single self-contained component with a small state machine. Two controls in the prototype are **demo scaffolding, not app features**:
- The top segmented bar (Início/Resultados/Concluído — i.e. Idle/Results/Done) above the window is a state navigator for reviewing screens. In the real app, screens are reached through the flow (Scan → Results → Clean → Done), not a tab bar.
- The macOS window chrome (traffic lights, title bar) is drawn for the mock; in a native app it's the real OS window.

The **PT | EN language switcher in the title bar IS a real app feature** — see Localization below.

## Fidelity
**High-fidelity (hifi).** Final colors, typography, spacing, motion, and copy. Recreate pixel-faithfully using the codebase's primitives. Exact hex/size/spacing values are in Design Tokens and per-component below.

## Screens / Views
The app is one resizable macOS window (~1000pt wide design width; height ~664pt in the mock). It moves through five states plus two modals. Dark theme first (start here); light is a planned follow-up.

### 1. Idle
- **Purpose**: Calm landing. Read the disk, then invite a scan.
- **Layout**: Window body is a horizontal split. Left pane (`flex: 1.05`, centered) holds the gauge; right pane (fixed `374px`, `30px` padding) holds the breakdown + CTA. A `1px` divider (`#211E29`) separates them.
- **Left — gauge instrument** (see "Gauge" component): centered, 336×336px container. Center overlay shows: kicker `USADO`/`USED` (mono 11px, letter-spacing .22em, `#6F6A78`); hero `933` in Space Grotesk 600 / 46px with ` GB` at 18px `#8B8693`; sub line `61 GB livres · 994 GB no total` (mono 12px `#8B8693`).
- **Right pane, top→bottom**:
  - Kicker `MACINTOSH HD` (mono 11px, letter-spacing .18em, `#6F6A78`).
  - Title `Detalhamento do disco` / `Disk breakdown` (Space Grotesk 600 / 20px `#F2EEE7`).
  - **Breakdown legend** — 6 rows, each: a 9px rounded-2.5px color dot, the category name (13.5px `#C7C2CC`), and the size right-aligned (mono 13px `#9A95A2`). Data: Xcode/Simulators 33 GB `#5C8AC9`; Caches 23 GB `#4FA39A`; Android SDK 22 GB `#7FA85A`; App Support (IDEs) 29 GB `#C8924E`; Other/System 826 GB `#5A5764`; Free 61 GB `#34313D`.
  - **Reclaimable hint** card: `#1C1A23` bg, `1px #2A2733` border, radius 10, padding 14×16. A glowing 8px accent dot (`#6FA0D9`, box-shadow `0 0 10px 1px rgba(111,160,217,.55)`) + text `≈ 42 GB recuperáveis de lixo de dev` (`42 GB` in mono `#9CC0EA`).
  - Spacer pushes the CTA to the bottom.
  - **Scan button**: full width, 48px tall, radius 11, gradient `linear-gradient(180deg,#7AAAE0,#5E8BC9)`, text `#0E1622` Space Grotesk 600/16px, shadow `0 8px 22px -8px rgba(94,139,201,.6)` + inset highlight. Label `Escanear` / `Scan`.
  - Reassurance line (mono 11.5px `#6F6A78`, centered): `Os itens vão para a Lixeira — você pode restaurá-los.`

### 2. Scanning (transient)
- **Purpose**: Show progress between Idle and Results.
- **Layout**: centered column. The gauge with a **single accent arc** (`#6FA0D9`, dasharray `140 677`, round cap) rotating: `@keyframes spin` 1.3s linear infinite. Center overlay: kicker `ESCANEANDO`/`SCANNING`, then `{pct}%` in Space Grotesk 600/44px. Below the gauge a mono 12.5px `#9A95A2` line `Lendo {current rule}…` that pulses (opacity .55↔1, 1.4s). Auto-advances to Results after ~1.7s.

### 3. Results
- **Purpose**: Pick what to delete, with risk explicit per row.
- **Header** (padding 18×22, bottom border `#211E29`): left = title `Limpeza`/`Cleanup` (Space Grotesk 600/18px) + reversibility note (mono 11.5px `#6F6A78`). Right column = `selecionado 15.1 GB` (mono 12px, number `#9CC0EA`) above the **Clean selected** button (40px tall, radius 10, same accent gradient, label `Limpar selecionados · {total}`). When total is 0 the button is disabled (`#26232D` bg, `#5A5563` text, not-allowed).
- **List** (scrollable, padding 8×14). Each rule row is a column container (radius 11; when expanded: border `#2E2A38`, bg `#1B1922`). Top line is a grid `26px 84px 1fr auto 22px`, gap 14, padding 13×15:
  1. **Checkbox** 22×22, radius 7. Checked = accent gradient fill + `#0E1622` ✓; unchecked = `1.5px #3A3743` border transparent. Non-selectable (empty rule) = muted `#2A2733` border on `#1A1822`.
  2. **Risk badge** — fixed 84px, centered, mono 10px, letter-spacing .1em, weight 600, radius 6, padding 4×0. Three variants (see Risk semantics).
  3. **Name + description** (click toggles expand). Name 14px/500 (`#E7E2DC`, or `#7E7989` if empty); desc 12px `#7E7989`. Both truncate with ellipsis.
  4. **Size** — mono 13.5px, right-aligned, min-width 62px. Color `#9CC0EA` when checked, else `#9A95A2`; `#5A5563` if empty.
  5. **Chevron** `▸`, `#5A5563`, rotates 90° when expanded (transition .18s).
- **Expanded preview** (margin 0×15×13, padding 12×14, bg `#121116`, border `#221F2A`, radius 9): each affected path as a mono 12px `#A39EAA` line prefixed with a `›` (`#4D4956`). Empty rules show `Nada para limpar aqui.`/`Nothing to clean here.` instead. The NDK row also shows a green keep-note (mono 11.5px `#74BE96`): `✓ Mantém 26.1.10909125 — exigido por 2 projetos`.
- The NDK (danger) row is **expanded by default** so the affected paths are visible.

### 4. Confirm — Danger modal (only for `danger` items)
- Triggered when **Clean selected** runs with a `danger` item checked (NDK) and it hasn't been confirmed yet.
- Card 472px, bg `#1B1922`, border `#322833`, radius 15, big shadow. Backdrop `rgba(7,6,9,.66)` + `blur(3px)`.
- Header: 36px rounded-9 danger chip (`rgba(214,112,104,.14)` bg, `#E58379` `!` glyph) + title `Remover versões antigas do Android NDK?` (Space Grotesk 600/18px) + body (13px `#A39EAA`) explaining **why** it's risky, with `ndkVersion` inline in mono amber `#E0B262`: "The right NDK depends on your projects' `ndkVersion`. Review the versions below before removing — the wrong one breaks native builds."
- Path list box (same style as the row preview) listing the 3 NDK versions + the green keep-note.
- **Review gate**: a checkbox row `Revisei as versões acima.`/`I reviewed the versions above.` The destructive button stays **disabled** (`#221F2A` bg, `#5A5563` text) until checked, then becomes `rgba(214,112,104,.18)` bg / `#EC9085` text. Buttons: `Cancelar` (ghost) and `Mover 5 GB para a Lixeira`. This is a deliberate re-read, not a reflex OK.

### 5. Cleaning (transient)
- Centered column: kicker `LIMPANDO`/`CLEANING`, current rule name (Space Grotesk 600/24px), a 440px progress bar (8px tall, track `#221F2A`, fill accent gradient, width transitions .3s), and a mono step line `3 de 7` / `3 of 7`. Steps through the selected rules, then → Done.

### 6. Done / Reveal
- **Purpose**: the payoff + an honest Trash distinction.
- **Layout**: horizontal split. Left = the gauge (312px) now showing reclaimed space: gray "other" arc shrinks while a bright green `#74BE96` "freed" arc (6 GB) and a translucent accent `rgba(111,160,217,.42)` "in-Trash" arc (36 GB) grow in. Center overlay: `LIVRE AGORA`/`FREE NOW`, the free total counting `61 → 67` GB (Space Grotesk 600/44px), and `+6 GB devolvidos ao disco` (mono 12px `#74BE96`).
- Right pane: kicker `LIMPEZA CONCLUÍDA`/`CLEANUP COMPLETE` (mono 11px green `#74BE96`). **Hero number**: `42` in Space Grotesk **700 / 88px**, letter-spacing -.03em, `#F4F1EA`, with `GB` at 34px `#9CC0EA`; counts up 0→42 on entry. Sublabel `recuperáveis`/`reclaimable` (Space Grotesk 18px `#8B8693`).
- **Trash split** card (border `#2A2733`, radius 11, bg `#1A1822`): two halves — `6 GB` / `liberados` (mono 20px green) and `36 GB` / `aguardando na Lixeira` (mono 20px `#9CC0EA`), divided by a `1px` border.
- **Empty Trash button**: 46px, radius 11, danger-tinted (`rgba(214,112,104,.10)` bg, `1px rgba(214,112,104,.36)` border, `#EC9085` text). Label `Esvaziar a Lixeira para liberar de vez`. Opens the Empty-Trash modal.
- Note (mono 11.5px `#6F6A78`): `Itens na Lixeira são recuperáveis até você esvaziá-la.`

### Empty Trash modal
- Card 440px, same chrome as the danger modal. Title `Esvaziar a Lixeira?` + body warning this is the **one permanent step** — `36 GB` in mono `#E58379`, `não pode ser desfeito`/`cannot be undone` in `#E58379`. Buttons: `Manter na Lixeira` (ghost) and `Esvaziar Lixeira` (danger). On confirm, the Trash split flips to `0 GB · Lixeira esvaziada` and the Empty button becomes a disabled `Lixeira vazia`.

## Interactions & Behavior
- **Flow**: Idle —Scan→ Scanning (~1.7s) → Results. Results —Clean selected→ (if a `danger` item is checked & unconfirmed) Danger modal → on confirm → Cleaning (steps through selected, ~1.9s total) → Done. Done —Empty Trash→ Empty modal → confirm flips Trash to emptied.
- **Selection**: clicking a checkbox toggles that rule; the header total and the button label update live. Safe items are checked by default; `confirm` and `danger` items start unchecked (conscious opt-in). Default checked total = **15.1 GB** (CoreSimulator 12 + Gradle 3.1; the two `—` safe items contribute 0). All selectable items checked = **42.0 GB**.
- **Expand**: clicking a row's name area or chevron toggles its path preview (single-open accordion in the prototype; multi-open is fine too). NDK starts expanded.
- **Risk gate**: the danger confirm button is disabled until the "I reviewed" checkbox is on. Once confirmed in a session, re-running Clean doesn't re-prompt.
- **Animations** (all respect `prefers-reduced-motion` — when reduced, jump to final values, no tweens/spins):
  - Gauge fill on load: segments draw from the top clockwise over **1100ms**, ease-out (`1 - (1-t)^3`).
  - Scanning: accent arc spins (1.3s linear), label pulses (1.4s).
  - Cleaning: progress bar width transitions .3s.
  - Reveal: hero number rolls 0→42 and free counts 61→67 while the freed/Trash arcs grow, over **1400ms** ease-out — one orchestrated moment, not scattered effects.
  - Row hover: subtle background lift (prototype uses the expanded bg tint; a `#1C1A23` hover is appropriate).
- **Accessibility**: visible keyboard focus, AA contrast, reduced-motion honored. Hit targets ≥ the 22px controls shown (bump to ≥28–32px touch/click where possible).

## State Management
State variables needed:
- `lang`: `'pt' | 'en'` (default `'pt'`) — drives all strings.
- `screen`: `'idle' | 'scanning' | 'results' | 'cleaning' | 'done'`.
- `selected`: map of ruleId → bool (defaults: coresim, gradle, simun, brew = true).
- `expandedId`: ruleId | null (default `'ndk'`).
- Animation progress: `gaugeP` (0→1), `scanP` (0→1), `revealP` (0→1); cleaning `cleanIdx`/`cleanTotal`/`cleanCur`.
- Modal/flow flags: `dangerOpen`, `emptyOpen`, `reviewed`, `dangerConfirmed`, `trashEmptied`.
- Derived: selected total (sum of checked selectable rule sizes), `freeNow = 61 + round(6 * revealP)`, hero = `42 * revealP`.
- No data fetching in the mock. In the real app these map to actual filesystem scans; the numbers here are fixed sample data (use them for layout, replace with live values).

## Sample data (use these exact numbers)
Disk: **994 GB total · 61 GB free** before. Rules (id · name · size · risk · default-checked):
- `derived` · Xcode DerivedData · 0 B · safe · n/a (empty, non-selectable; demonstrates a "nothing to clean" state)
- `simun` · Unavailable simulators · — (0) · safe · checked
- `coresim` · CoreSimulator caches · 12 GB · safe · checked
- `gradle` · Gradle caches · 3.1 GB · safe · checked
- `brew` · Homebrew cleanup · — (0) · safe · checked
- `intellij` · IntelliJ — old versions · 10 GB · confirm · unchecked
- `studio` · Android Studio — old versions · 1.5 GB · confirm · unchecked
- `ndk` · Android NDK — old versions · 5 GB · **danger** · unchecked (expanded by default; keeps 26.1.10909125)
- `docker` · Docker — prune (no volumes) · 10.4 GB · confirm · unchecked

Reveal: **42 GB reclaimable · 6 GB freed · 36 GB waiting in Trash**.
Each rule's affected paths and both-language name/desc strings are in `DevDisk.dc.html` (the `RULE_I18N` and `ruleMeta` objects) — copy them verbatim.

## Risk semantics (the badge is the most important info after size)
- **safe** (`SEGURO`/`SAFE`) — recreatable, delete freely. Badge: bg `rgba(95,163,125,.12)`, text `#74BE96`, border `rgba(95,163,125,.30)`.
- **confirm** (`CONFIRMAR`/`CONFIRM`, amber) — needs a conscious click. Badge: bg `rgba(214,162,78,.12)`, text `#E0B262`, border `rgba(214,162,78,.32)`.
- **danger** (`PERIGO`/`DANGER`, red) — could delete the wrong version; mandatory preview + review modal. Badge: bg `rgba(214,112,104,.13)`, text `#E58379`, border `rgba(214,112,104,.34)`.

## Localization
The PT|EN switcher lives **inside the app**, in the title bar (right side). Switching updates every string instantly without resetting state or selection. All UI strings live in a per-language dictionary (`STR.pt` / `STR.en` in the prototype) plus per-rule names/descriptions (`RULE_I18N`). App ships defaulting to **PT**. Technical tokens stay identical across languages: `ndkVersion`, all file paths, Docker commands, `Macintosh HD`, version string. Structure is ready to extend to more languages — add a dictionary entry.

## Design Tokens
**Surfaces** (dark): page bg `radial-gradient(120% 120% at 50% -10%, #131218, #0C0B0F 60%, #090809)`; window `#161419`; raised card `#1C1A23`/`#1A1822`/`#1B1922`; sunken/preview `#121116`; gauge track `#211E2A`.
**Borders**: `#2A2733` (primary), `#211E29` (divider), `#322833` (modal), `#2E2A38` (active), `#221F2A` (preview).
**Ink**: `#F4F1EA`/`#F2EEE7` (hero/near-white), `#ECE8E1` (base), `#E7E2DC` (row name), `#C7C2CC` (secondary), `#A39EAA` (body dim), `#9A95A2` (mono dim), `#8B8693` / `#7E7989` (faint), `#6F6A78` / `#5A5563` / `#4D4956` (faintest).
**Accent (steel blue)**: primary gradient `#7AAAE0 → #5E8BC9`; solid `#6FA0D9`; mono number `#9CC0EA`; deep `#3E5E86`.
**Risk semantics**: safe `#74BE96` (green); warn/confirm `#E0B262` (amber); danger `#E58379` / `#EC9085` (red).
**Category colors**: `#5C8AC9` (blue), `#4FA39A` (teal), `#7FA85A` (green), `#C8924E` (copper), `#5A5764` (system gray), `#34313D` (free, near-track).
**Traffic lights**: `#ED6A5E` / `#F4BE4F` / `#61C554`.
**Radii**: 6 (badge), 7 (checkbox), 8–11 (cards/buttons), 13–15 (window/modal).
**Spacing**: 8/12/14/16/18/22/28/30/34px rhythm.
**Shadows**: window `0 50px 120px -28px rgba(0,0,0,.78)`; modal `0 40px 90px -20px rgba(0,0,0,.8)`; CTA `0 8px 22px -8px rgba(94,139,201,.6)`; accent glow `0 0 10px 1px rgba(111,160,217,.55)`.

## Typography (3 roles)
- **Display** — `Space Grotesk` (Google Fonts), weights 400–700. Used for titles, the used/free readouts, and the reveal hero number (700/88px). The hero is the typographic climax — keep it big and tight.
- **Body/UI** — system stack `-apple-system, BlinkMacSystemFont, system-ui, 'Segoe UI', sans-serif` (renders SF on macOS — native feel). Row names, descriptions, labels.
- **Mono** — `JetBrains Mono` (Google Fonts), weights 400–600. **All** sizes, counters, percentages, file paths, kickers, and the language toggle. Devs read bytes/paths better in mono and it carries the app's identity.

## The gauge instrument (build spec)
SVG `viewBox 0 0 320 320`, ring at `cx/cy 160`, `r 130`, `stroke-width 22`.
- **Tick scale**: 60 ticks at 6° steps (`rotate(i*6 160 160)`), drawn as vertical lines. Major every 5th (12 majors): y 9→22, `#6F6A78`, width 1.6, opacity .55. Minor: y 13→19, `#3A3743`, width 1, opacity .7. Static decoration that gives the "instrument" read.
- **Track**: full circle, stroke `#211E2A`.
- **Segments**: one arc per category, `stroke-dasharray "len rest"` where `len = (size/total) * circumference * progress` (circumference = 2π·130 ≈ 816.8), each rotated to its cumulative start (`rotate(startFraction*360 - 90 160 160)` so the ring starts at 12 o'clock). Animate by scaling `progress` 0→1.
- **Center readout**: an absolutely-positioned overlay div (flex column, centered, pointer-events none) — easier than SVG text. Reuse the same gauge object on Idle, Scanning, and Done for visual continuity.
- Idle segments (over 994): 33 blue, 23 teal, 22 green, 29 copper, 826 system-gray, 61 free. Done segments: shrinking gray `891 + 42*(1-p)`, growing green `6*p`, growing translucent-accent `36*p`, free `61`.

## Constraints (reflect in layout)
- macOS window ~960–1040pt wide, resizable; respect the title bar with traffic lights. The design width here is 1000px; let it reflow/resize rather than hard-locking.
- Native macOS density: comfortable and legible, no "web template" air.
- Accessibility: visible keyboard focus, AA contrast, reduced motion honored.

## Voice / microcopy
Direct, active, reassuring about reversibility — no apologies, no vagueness. Reference EN strings (and their PT counterparts) live in the prototype dictionary. Key lines:
- CTA: `Scan` → `Scanning…` → `Clean selected`.
- Reversibility: `Items move to the Trash — you can put them back.`
- Reveal: `42 GB reclaimable` / `6 GB freed · 36 GB waiting in Trash`.
- Empty Trash: `Empty Trash to free it for good` (modal explains permanence).
- Empty rule: `Nothing to clean here.`
- Danger: explains *why* — `The right NDK depends on your projects' ndkVersion. Review before removing.`

## Files
- `DevDisk.dc.html` — the full hi-fi prototype (all five states + both modals + PT/EN). It's a single self-contained HTML component; open it in a browser to interact. All strings, sample data, risk semantics, gauge geometry, and animation timings are in its inline `<script>` (the `STR`, `RULE_I18N`, `ruleMeta`, `buildSegments`, `tween`, and `renderVals` definitions). Treat it as the source of truth for any value not spelled out above.

## Assets
No external image assets — everything is drawn (SVG gauge, CSS chrome). Fonts: Space Grotesk + JetBrains Mono from Google Fonts (bundle them locally in a shipping app). If your codebase already has a design system / icon set, prefer its primitives for the chrome and controls; the gauge is bespoke and should be recreated as a custom view.
