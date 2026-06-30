# Architecture

- Dependency: `presentation → domain ← data`. **The domain does not know `dart:io`/`Process`/`osascript`** — that's why the pure types live in `core/cleaner/clean_models.dart` (no IO) and the domain only re-exports them.
- The dangerous engine sits behind `CleanerRepository` + an injectable `ProcessRunner` (fakeable in tests).
- **Thin use cases:** only `ScanRules` and `CleanRules` (they aggregate logic). For `diskStats()`/`diskFreeBytes()`/`emptyTrash()` the Cubit calls the repository directly — do not create passthrough use cases.
- **A single `CleanerState`** (equatable) with an `enum CleanerPhase` — do not create a sealed class per screen.
- **Manual DI** in `core/di/injection.dart` (no `injectable`/codegen).
- **A new cleanup rule** = add a `CleanupRule` to `kRules` (`disk_cleaner_engine.dart`) + `ruleName`/`ruleDesc` keys in both `.arb` files. Nothing more.
