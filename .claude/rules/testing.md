# Testes

- `flutter analyze` e `flutter test` limpos antes de considerar pronto.
- **Nunca rodar `osascript`/`docker`/`brew` reais nos testes** — fakear via `ProcessRunner`/mock do repositório.
- Cobertura por camada: **engine** (`Directory.systemTemp` + `ProcessRunner` fake), **use cases** (mock repo, `mocktail`), **cubit** (`bloc_test`).
- Mtime de diretório em teste: usar `touch -t` (dart:io não seta mtime de `Directory`).
