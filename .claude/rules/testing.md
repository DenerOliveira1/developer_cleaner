# Tests

- `flutter analyze` and `flutter test` clean before considering it done.
- **Never run real `osascript`/`docker`/`brew` in tests** — fake them via `ProcessRunner`/mock of the repository.
- Coverage by layer: **engine** (`Directory.systemTemp` + fake `ProcessRunner`), **use cases** (mock repo, `mocktail`), **cubit** (`bloc_test`).
- Directory mtime in tests: use `touch -t` (dart:io doesn't set mtime on a `Directory`).
