# Security (CRITICAL — a bug here deletes real data)

- **Trash by default.** File removal is always via Finder (`osascript … delete`), **never `rm -rf`**. A real `rm` would only be acceptable for 100% recreatable cache, and even then behind confirmation.
- **Batch trash.** Moving many paths = `CleanerEngine.trashAll` (one `osascript` per chunk of 100), never one process per file.
- **Never `sh -c`** with user input. Always `Process.run(exec, [args])` with an argument list (avoids injection via spaces/quotes).
- **Commands are IRREVERSIBLE — never `safe`.** `RunCommand`/`DeleteSimRuntimes` (`simctl`, `docker`, `brew`) do not go to the Trash. Every command rule is at minimum `confirm` (unchecked by default) and the UI shows `permanentWarning` in the preview. Only `TrashPaths`/`KeepLatest` (which go to the Trash) can be `safe`. Use `isReversibleAction(action)` to decide the warning.
- **`simctl delete unavailable` deletes real simulators** (not cache) — that's why `simun` is `confirm`. In `coresim`, clean **only** `CoreSimulator/Caches`; **never** `Cryptex`/`Devices`/`Volumes` (they are runtime and simulator data).
- **Docker prune never with `--volumes`** (database data in containers survives).
- **Dry-run = zero side effects.** `clean(rule, dryRun: true)` only returns the targets.
- **Idempotency:** a nonexistent path is a no-op (not an error). Running twice does not break.
- **Graceful failure:** an error in one rule does not take down the others — log it and move on.
- **Emptying the Trash is the only permanent action** — always behind the re-read modal (`empty_trash_modal`).
- **App Sandbox OFF** in `macos/Runner/{DebugProfile,Release}.entitlements` (`app-sandbox = false`). Without it, reading `~/Library` and running `du/osascript/docker/brew` fails silently. Consequence: distribution outside the App Store.
