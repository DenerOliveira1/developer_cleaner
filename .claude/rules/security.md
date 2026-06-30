# Segurança (CRÍTICO — um bug aqui apaga dados de verdade)

- **Lixeira por padrão.** Remoção de arquivos é sempre via Finder (`osascript … delete`), **nunca `rm -rf`**. `rm` real só seria aceitável para cache 100% recriável e ainda assim atrás de confirmação.
- **Trash em lote.** Mover muitos caminhos = `CleanerEngine.trashAll` (um `osascript` por chunk de 100), nunca um processo por arquivo.
- **Nunca `sh -c`** com input do usuário. Sempre `Process.run(exec, [args])` com lista de argumentos (evita injeção com espaços/aspas).
- **Comandos são IRREVERSÍVEIS — nunca `safe`.** `RunCommand`/`DeleteSimRuntimes` (`simctl`, `docker`, `brew`) não vão pra Lixeira. Toda regra de comando é no mínimo `confirm` (desmarcada por padrão) e a UI mostra `permanentWarning` no preview. Só `TrashPaths`/`KeepLatest` (que vão pra Lixeira) podem ser `safe`. Use `isReversibleAction(action)` pra decidir o aviso.
- **`simctl delete unavailable` apaga simuladores de verdade** (não cache) — por isso `simun` é `confirm`. Em `coresim`, limpar **só** `CoreSimulator/Caches`; **nunca** `Cryptex`/`Devices`/`Volumes` (são runtime e dados do simulador).
- **Docker prune nunca com `--volumes`** (dados de banco em containers sobrevivem).
- **Dry-run = zero efeito colateral.** `clean(rule, dryRun: true)` só retorna os alvos.
- **Idempotência:** caminho inexistente é no-op (não erro). Rodar duas vezes não quebra.
- **Falha graciosa:** erro numa regra não derruba as outras — registrar e seguir.
- **Esvaziar a Lixeira é a única ação permanente** — sempre atrás do modal de re-leitura (`empty_trash_modal`).
- **App Sandbox DESLIGADO** em `macos/Runner/{DebugProfile,Release}.entitlements` (`app-sandbox = false`). Sem isso, ler `~/Library` e rodar `du/osascript/docker/brew` falha silenciosamente. Consequência: distribuição fora da App Store.
