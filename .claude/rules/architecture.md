# Arquitetura

- Dependência: `presentation → domain ← data`. **Domínio não conhece `dart:io`/`Process`/`osascript`** — por isso os tipos puros vivem em `core/cleaner/clean_models.dart` (sem IO) e o domínio só os re-exporta.
- O motor perigoso fica atrás de `CleanerRepository` + `ProcessRunner` injetável (fakeável nos testes).
- **Use cases finos:** só `ScanRules` e `CleanRules` (agregam lógica). `diskStats()`/`diskFreeBytes()`/`emptyTrash()` o Cubit chama o repositório direto — não criar use case passthrough.
- **Um único `CleanerState`** (equatable) com `enum CleanerPhase` — não criar sealed class por tela.
- **DI manual** em `core/di/injection.dart` (sem `injectable`/codegen).
- **Nova regra de limpeza** = adicionar `CleanupRule` em `kRules` (`disk_cleaner_engine.dart`) + chaves `ruleName`/`ruleDesc` nos dois `.arb`. Nada mais.
