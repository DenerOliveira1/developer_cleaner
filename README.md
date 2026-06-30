# DevDisk Cleaner

A **macOS-only Flutter app** that scans for "developer junk" (Xcode/CoreSimulator caches, Gradle, Android SDK/NDK, old JetBrains/Android Studio versions, Docker layers, iOS simulator runtimes, and Flutter/React Native/React-Next/PHP project artifacts) and removes it **reversibly** — files go to the **Trash** via Finder, never `rm -rf`.

🇬🇧 [English](#english) · 🇧🇷 [Português](#português)

---

## English

### Overview

DevDisk Cleaner reclaims disk space taken by developer caches and build artifacts. Everything is built around **safety**:

- **Reversible by default** — file removals go to the Trash (with "Put Back"), never a hard `rm -rf`.
- **Risk levels** per rule: `safe` (recreatable, checked by default), `confirm` (conscious opt-in + preview), `danger` (mandatory review modal).
- **Irreversible commands** (`simctl`, `docker`, `brew`, runtime deletion) are never `safe` and are clearly marked "permanent — not the Trash".
- **Dry-run** available; **emptying the Trash** is the only permanent action, behind a re-read modal.

### Features

**System / toolchain caches**

| Rule | Risk | What it does |
|------|------|--------------|
| Xcode DerivedData | safe | Trash the contents of `~/Library/Developer/Xcode/DerivedData` |
| CoreSimulator caches | safe | Trash the recreatable `CoreSimulator/Caches` |
| Gradle caches | safe | Trash `~/.gradle/caches` + `wrapper/dists` |
| Unavailable simulators | confirm | `xcrun simctl delete unavailable` (permanent) |
| Homebrew cleanup | confirm | `brew cleanup -s` (permanent) |
| IntelliJ / Android Studio — old versions | confirm | Keep the latest, trash older version caches |
| Docker — prune (no volumes) | confirm | `docker system prune -a -f` (never `--volumes`) |
| Android NDK — old versions | danger | Keep the newest by mtime, trash the rest |
| iOS Simulator — old runtimes | danger | Keep the newest iOS runtime, delete the rest (permanent) |

**Project artifacts** (discovers projects under common dev roots and trashes their recreatable folders)

| Rule | Risk | Targets |
|------|------|---------|
| Flutter | confirm | `build/`, `.dart_tool/` |
| React Native | confirm | `node_modules`, `ios/Pods`, `ios/build`, `android/build`, `android/app/build`, `android/.gradle` |
| React / Next.js | confirm | `node_modules`, `.next`, `build`, `dist`, `out` |
| PHP (Composer) | confirm | `vendor/` |

### Requirements

- macOS (the app aborts on other platforms)
- [Flutter](https://docs.flutter.dev/get-started/install/macos) (stable channel)
- Xcode command-line tools

> **App Sandbox is OFF** (`macos/Runner/*.entitlements`). Without this, reading `~/Library` and running `du`/`osascript`/`docker`/`brew` fails silently. Consequence: distribution **outside the Mac App Store**.

### Getting started

```bash
flutter pub get
flutter run -d macos                 # run the app
flutter analyze && flutter test      # lint + tests
flutter gen-l10n                     # regenerate localizations after editing .arb

# The engine also runs as a CLI (real scan; --apply cleans the safe rules):
dart run lib/core/cleaner/disk_cleaner_engine.dart
```

### Build & package a signed, notarized DMG

Produces `dist/DevDisk Cleaner.dmg`, ready to distribute on any Mac without Gatekeeper warnings.

**One-time setup** (paid Apple Developer Program):

1. Create a **"Developer ID Application"** certificate — Xcode → Settings → Accounts → your team → *Manage Certificates…* → **+** → *Developer ID Application*.
2. Store notarization credentials (uses an [app-specific password](https://support.apple.com/en-us/102654)):
   ```bash
   xcrun notarytool store-credentials devdisk-notary \
     --apple-id "you@example.com" --team-id "YOURTEAMID" \
     --password "xxxx-xxxx-xxxx-xxxx"
   ```
3. Install `create-dmg`: `brew install create-dmg`.

**Build:**

```bash
export DEVDISK_SIGN_IDENTITY="Developer ID Application: Your Name (YOURTEAMID)"
export DEVDISK_NOTARY_PROFILE="devdisk-notary"   # optional (this is the default)
./scripts/make_dmg.sh                            # build → sign → DMG → notarize → staple

./scripts/make_dmg.sh --no-sign                  # unsigned local DMG (no Apple account needed)
```

The script reads the signing identity from the environment, so nothing personal is committed.

### Architecture

Clean Architecture, `presentation → domain ← data`, with the dangerous engine hidden behind a `CleanerRepository` + an injectable `ProcessRunner` (fakeable in tests).

```
lib/
├── core/         # engine (pure Dart) + ProcessRunner + DI + byte format
├── domain/       # entities · CleanerRepository · use cases (ScanRules, CleanRules)
├── data/         # datasource (wraps the engine) · repo impl · default rules (kRules)
└── presentation/ # CleanerCubit + state · theme tokens · pages · widgets (gauge, rows, modals)
```

- State: a single equatable `CleanerState` with an `enum CleanerPhase` (idle → scanning → results → cleaning → done).
- DI: manual `get_it` wiring in `core/di/injection.dart`.

**Add a new cleanup rule:** add a `CleanupRule` to `kRules` (`disk_cleaner_engine.dart`) + `ruleName`/`ruleDesc` keys in both `.arb` files. Project-artifact rules are pure config via the `ProjectArtifacts` action.

### Localization

UI text lives in `assets/language/app_*.arb` (PT/EN), accessed via `AppLocalizations.of(context)`. The in-app PT|EN toggle drives `MaterialApp.locale` from the Cubit, so switching language is instant and preserves state. New language: add `app_<code>.arb` → `flutter gen-l10n` → extend the `AppLang` enum + `Locale` mapping in `main.dart`.

### Safety guarantees

Trash by default (never `rm -rf`); preview required for `confirm`/`danger`; dry-run has zero side effects; no `sh -c` with user input; Docker prune never `--volumes`; idempotent (missing paths are no-ops); a failing rule never aborts the others; emptying the Trash is the only permanent step.

---

## Português

### Visão geral

O DevDisk Cleaner recupera espaço em disco ocupado por caches de desenvolvimento e artefatos de build. Tudo é construído em torno de **segurança**:

- **Reversível por padrão** — remoções de arquivos vão para a **Lixeira** (com "Pôr de volta"), nunca um `rm -rf` direto.
- **Níveis de risco** por regra: `safe` (recriável, marcado por padrão), `confirm` (escolha consciente + preview), `danger` (modal de revisão obrigatório).
- **Comandos irreversíveis** (`simctl`, `docker`, `brew`, exclusão de runtime) nunca são `safe` e são claramente marcados como "permanente — não vai para a Lixeira".
- **Dry-run** disponível; **esvaziar a Lixeira** é a única ação permanente, atrás de um modal de re-leitura.

### Funcionalidades

**Caches de sistema / toolchain**

| Regra | Risco | O que faz |
|-------|-------|-----------|
| Xcode DerivedData | safe | Manda o conteúdo de `~/Library/Developer/Xcode/DerivedData` para a Lixeira |
| Caches do CoreSimulator | safe | Limpa o `CoreSimulator/Caches` (recriável) |
| Caches do Gradle | safe | Limpa `~/.gradle/caches` + `wrapper/dists` |
| Simuladores indisponíveis | confirm | `xcrun simctl delete unavailable` (permanente) |
| Limpeza do Homebrew | confirm | `brew cleanup -s` (permanente) |
| IntelliJ / Android Studio — versões antigas | confirm | Mantém a mais recente, manda as antigas para a Lixeira |
| Docker — prune (sem volumes) | confirm | `docker system prune -a -f` (nunca `--volumes`) |
| Android NDK — versões antigas | danger | Mantém a mais nova por mtime, remove o resto |
| Simulador iOS — runtimes antigos | danger | Mantém o iOS mais recente, remove o resto (permanente) |

**Artefatos de projeto** (descobre projetos nas pastas de dev comuns e manda as pastas recriáveis para a Lixeira)

| Regra | Risco | Alvos |
|-------|-------|-------|
| Flutter | confirm | `build/`, `.dart_tool/` |
| React Native | confirm | `node_modules`, `ios/Pods`, `ios/build`, `android/build`, `android/app/build`, `android/.gradle` |
| React / Next.js | confirm | `node_modules`, `.next`, `build`, `dist`, `out` |
| PHP (Composer) | confirm | `vendor/` |

### Requisitos

- macOS (o app aborta em outras plataformas)
- [Flutter](https://docs.flutter.dev/get-started/install/macos) (canal stable)
- Ferramentas de linha de comando do Xcode

> **O App Sandbox está DESLIGADO** (`macos/Runner/*.entitlements`). Sem isso, ler `~/Library` e rodar `du`/`osascript`/`docker`/`brew` falha silenciosamente. Consequência: distribuição **fora da Mac App Store**.

### Como começar

```bash
flutter pub get
flutter run -d macos                 # roda o app
flutter analyze && flutter test      # lint + testes
flutter gen-l10n                     # regenera as traduções após editar .arb

# O motor também roda como CLI (scan real; --apply limpa as regras safe):
dart run lib/core/cleaner/disk_cleaner_engine.dart
```

### Build & empacotar um DMG assinado e notarizado

Gera `dist/DevDisk Cleaner.dmg`, pronto pra distribuir em qualquer Mac sem aviso do Gatekeeper.

**Configuração única** (Apple Developer Program pago):

1. Crie um certificado **"Developer ID Application"** — Xcode → Settings → Accounts → seu time → *Manage Certificates…* → **+** → *Developer ID Application*.
2. Salve as credenciais de notarização (usa uma [senha específica de app](https://support.apple.com/pt-br/102654)):
   ```bash
   xcrun notarytool store-credentials devdisk-notary \
     --apple-id "voce@exemplo.com" --team-id "SEUTEAMID" \
     --password "xxxx-xxxx-xxxx-xxxx"
   ```
3. Instale o `create-dmg`: `brew install create-dmg`.

**Build:**

```bash
export DEVDISK_SIGN_IDENTITY="Developer ID Application: Seu Nome (SEUTEAMID)"
export DEVDISK_NOTARY_PROFILE="devdisk-notary"   # opcional (este é o padrão)
./scripts/make_dmg.sh                            # build → assina → DMG → notariza → staple

./scripts/make_dmg.sh --no-sign                  # DMG local sem assinatura (não precisa de conta Apple)
```

O script lê a identidade de assinatura do ambiente, então nada pessoal é commitado.

### Arquitetura

Clean Architecture, `presentation → domain ← data`, com o motor perigoso escondido atrás de um `CleanerRepository` + um `ProcessRunner` injetável (fakeável nos testes).

```
lib/
├── core/         # motor (Dart puro) + ProcessRunner + DI + formatação de bytes
├── domain/       # entities · CleanerRepository · use cases (ScanRules, CleanRules)
├── data/         # datasource (envolve o motor) · repo impl · regras padrão (kRules)
└── presentation/ # CleanerCubit + estado · tokens de tema · páginas · widgets (gauge, linhas, modais)
```

- Estado: um único `CleanerState` equatable com um `enum CleanerPhase` (idle → scanning → results → cleaning → done).
- DI: wiring manual com `get_it` em `core/di/injection.dart`.

**Adicionar uma regra de limpeza:** adicione um `CleanupRule` em `kRules` (`disk_cleaner_engine.dart`) + chaves `ruleName`/`ruleDesc` nos dois `.arb`. Regras de artefato de projeto são pura configuração via a action `ProjectArtifacts`.

### Localização

Os textos de UI ficam em `assets/language/app_*.arb` (PT/EN), acessados via `AppLocalizations.of(context)`. O toggle PT|EN dentro do app dirige o `MaterialApp.locale` a partir do Cubit, então trocar de idioma é instantâneo e preserva o estado. Novo idioma: adicione `app_<código>.arb` → `flutter gen-l10n` → estenda o enum `AppLang` + o mapeamento `Locale` no `main.dart`.

### Garantias de segurança

Lixeira por padrão (nunca `rm -rf`); preview obrigatório para `confirm`/`danger`; dry-run sem efeito colateral; sem `sh -c` com input do usuário; Docker prune nunca com `--volumes`; idempotente (caminhos inexistentes são no-op); uma regra que falha nunca derruba as outras; esvaziar a Lixeira é o único passo permanente.
