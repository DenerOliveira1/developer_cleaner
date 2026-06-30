# DevDisk Cleaner

App **Flutter macOS-only** que escaneia "lixo de dev" (Xcode/CoreSimulator, Gradle, Android SDK/NDK, IDEs JetBrains/Android Studio, Docker) e remove de forma **reversível** (vai pra Lixeira via Finder, nunca `rm -rf`).

## Stack
Flutter (stable) · `flutter_bloc` (Cubit) · `get_it` (DI manual) · `equatable` · `flutter_localizations`/`gen_l10n` (i18n) · motor em Dart puro. macOS desktop apenas — aborta se `!Platform.isMacOS`.

## Arquitetura (Clean Architecture: `presentation → domain ← data`)
```
lib/
├── core/
│   ├── cleaner/clean_models.dart        # tipos puros (Safety, CleanAction, CleanupRule, ScanResult, DiskStats)
│   ├── cleaner/disk_cleaner_engine.dart # MOTOR (du/df/trash/keepLatest) + kRules + CLI main()
│   ├── process/process_runner.dart      # fronteira de processo injetável (fakeável)
│   ├── util/byte_format.dart            # formatBytes()
│   └── di/injection.dart                # wiring get_it
├── domain/   # entities (re-export dos tipos puros) · repositories · usecases (ScanRules, CleanRules)
├── data/     # datasource (envolve o motor) · repository impl · rules/default_rules.dart (kRules)
├── presentation/
│   ├── cubit/   # CleanerCubit + CleanerState (único, equatable, enum CleanerPhase)
│   ├── theme/   # AppColors, AppText (tokens do design)
│   ├── pages/cleaner_page.dart   # orquestra idle→scanning→results→cleaning→done + modais
│   └── widgets/ # disk_gauge (CustomPainter), rule_row, risk_badge, danger_modal, empty_trash_modal, top_bar
├── l10n/app_localizations.dart   # GERADO por gen_l10n (não editar à mão)
└── main.dart  # BlocProvider acima do MaterialApp; locale dirigido pelo AppLang do Cubit
assets/language/app_*.arb   # fonte das traduções (PT/EN)
assets/fonts/*.ttf          # Space Grotesk + JetBrains Mono (variáveis, bundladas)
docs/                       # disk_cleaner_spec.md (engenharia) + README.md/DevDisk.dc.html (design hi-fi)
```

## Comandos
```bash
flutter run -d macos                                   # dev
flutter build macos --debug                            # build nativo (valida entitlements)
flutter analyze && flutter test                        # lint + testes
flutter gen-l10n                                        # regenera AppLocalizations após editar .arb
dart run lib/core/cleaner/disk_cleaner_engine.dart      # CLI: scan real (--apply limpa as safe)
```

## Regras do projeto (`.claude/rules/`)
@.claude/rules/security.md
@.claude/rules/architecture.md
@.claude/rules/i18n.md
@.claude/rules/ui-design.md
@.claude/rules/testing.md
