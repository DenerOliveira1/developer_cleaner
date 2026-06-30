# DevDisk Cleaner — Especificação de Build (handoff para Claude Code)

> App **Flutter para macOS** que escaneia e limpa "lixo de desenvolvedor" (caches do Xcode/CoreSimulator, SDKs Android, versões antigas de IDEs JetBrains/Android Studio, imagens Docker etc.), com seleção por nível de risco, preview dos alvos e remoção **reversível** (Lixeira, não `rm`).

Este documento é o contrato de implementação. O motor de limpeza já existe em Dart puro no arquivo **`disk_cleaner_engine.dart`** (incluir em `lib/core/cleaner/`). Use-o como base e construa a arquitetura, o estado e a UI ao redor dele.

---

## 1. Objetivo e escopo

**Faz:**
- Escanear um conjunto de regras declarativas e estimar o espaço recuperável de cada uma.
- Apresentar as regras numa lista com tamanho, descrição e badge de risco.
- Permitir seleção, mostrar **preview dos caminhos afetados** e executar a limpeza.
- Mover itens para a **Lixeira** (reversível). Comandos de sistema (`xcrun`, `docker`, `brew`) são executados via processo.
- Suportar **dry-run** em qualquer regra.

**Não faz (fora de escopo nesta versão):**
- Não roda com `sudo` / não toca em caminhos fora de `~` (tudo pertence ao usuário).
- Não vai pra Mac App Store (sandbox precisa estar desligado — ver §3).
- Sem agendamento/automação em background (pode entrar no roadmap).

**Plataforma:** macOS apenas. Abortar com mensagem clara se `!Platform.isMacOS`.

---

## 2. Stack

- **Flutter** (canal stable), target **macOS desktop** apenas.
- **Gerência de estado:** `flutter_bloc` (Cubit).
- **DI:** `get_it` (+ `injectable` opcional).
- **Dart puro** para o motor (`dart:io`, `Process`, `osascript`). Sem plugins nativos custom — não é preciso.
- **Imutabilidade/igualdade:** `equatable` ou `freezed` (à escolha; manter consistente).
- Lints: `flutter_lints` ou `very_good_analysis`.

---

## 3. Restrições do macOS (LEIA ANTES DE CODAR)

Estas são as armadilhas que quebram o app silenciosamente:

### 3.1 App Sandbox precisa ser DESLIGADO
O target macOS do Flutter vem sandboxed. O sandbox **bloqueia** ler `~/Library/Developer`, `~/Library/Application Support`, etc., e **bloqueia** `Process.run` de binários externos (`xcrun`, `docker`, `brew`, `du`, `osascript`).

Editar os dois arquivos:
- `macos/Runner/DebugProfile.entitlements`
- `macos/Runner/Release.entitlements`

Remover (ou setar `false`) a chave:
```xml
<key>com.apple.security.app-sandbox</key>
<false/>
```
Manter `com.apple.security.cs.disable-library-validation` apenas se necessário. **Consequência:** distribuição **fora da App Store**, via `.dmg` notarizado (ver §11).

### 3.2 TCC / Full Disk Access
Todos os caminhos-alvo desta versão vivem em `$HOME` e pertencem ao usuário → acessíveis sem Full Disk Access. **Não** adicionar fluxo de permissão agora. Se futuramente o app tocar fora do home, será preciso guiar o usuário até *Ajustes → Privacidade e Segurança → Acesso Total ao Disco*.

### 3.3 Execução de processos
- `du -sk <paths...>` para medir tamanho (KB; multiplicar por 1024).
- `osascript -e 'tell application "Finder" to delete POSIX file "<path>"'` para mover à Lixeira (reversível, com "Pôr de volta").
- Comandos de regra: `xcrun simctl delete unavailable`, `docker system prune -a -f`, `brew cleanup -s`.
- **Nunca** passar caminhos do usuário por `sh -c` (risco de injeção com espaços/aspas). Sempre `Process.run(exec, [args])` com lista de argumentos.
- Rodar scans pesados sem travar a UI: `Process.run` já é async; para árvores muito grandes, considerar progresso incremental.

### 3.4 Remoção reversível por padrão
Regra de ouro: **mover para a Lixeira, nunca `rm -rf`**. `rm` real só é aceitável para caches 100% recriáveis e, mesmo assim, atrás de confirmação. Um bug num cleaner que apaga de verdade é catastrófico.

---

## 4. Arquitetura (Clean Architecture)

```
lib/
├── core/
│   ├── cleaner/
│   │   └── disk_cleaner_engine.dart   # motor já pronto (mover pra cá)
│   └── di/
│       └── injection.dart
├── domain/
│   ├── entities/
│   │   ├── cleanup_rule.dart          # CleanupRule, Safety, CleanAction (sealed)
│   │   └── scan_result.dart           # ScanResult
│   ├── repositories/
│   │   └── cleaner_repository.dart     # interface
│   └── usecases/
│       ├── scan_rules.dart            # escaneia todas/uma regra
│       └── clean_rules.dart           # executa regras selecionadas (dry-run opcional)
├── data/
│   ├── datasources/
│   │   └── system_cleaner_datasource.dart  # wrapper do CleanerEngine
│   ├── repositories/
│   │   └── cleaner_repository_impl.dart
│   └── rules/
│       └── default_rules.dart         # registro kRules (§6)
└── presentation/
    ├── cubit/
    │   ├── cleaner_cubit.dart
    │   └── cleaner_state.dart
    └── pages/
        └── cleaner_page.dart
```

**Regra de dependência:** `presentation → domain ← data`. O `CleanerEngine` é detalhe de infra — fica atrás do `CleanerRepository`. A camada de domínio não conhece `dart:io`, `Process` ou `osascript`.

---

## 5. Contrato do domínio

O motor já define estes tipos (em `disk_cleaner_engine.dart`). Reexpor/alinhar na camada de domínio:

```dart
enum Safety { safe, confirm, danger }

sealed class CleanAction {}
class TrashPaths   extends CleanAction { final List<String> paths; final bool contentsOnly; }
class RunCommand   extends CleanAction { final String executable; final List<String> args; }
class KeepLatest   extends CleanAction { final String parentDir; final String namePrefix; final int keep; }

class CleanupRule {
  final String id;
  final String label;
  final String description;
  final Safety safety;
  final CleanAction action;
}

class ScanResult {
  final CleanupRule rule;
  final int? bytes;            // null = desconhecido (comandos)
  final List<String> targets; // caminhos a serem afetados (preview)
}
```

**Interface do repositório:**
```dart
abstract class CleanerRepository {
  Future<ScanResult> scan(CleanupRule rule);
  Future<void> clean(CleanupRule rule, {bool dryRun = false});
}
```

**Use cases:**
- `ScanRules`: recebe `List<CleanupRule>`, retorna `List<ScanResult>` (paralelizável com `Future.wait`).
- `CleanRules`: recebe regras selecionadas + `dryRun`, executa em ordem (safe → confirm → danger é indiferente; respeitar seleção do usuário).

---

## 6. Regras de limpeza (registro inicial)

Já implementadas em `kRules` dentro do motor. `safe` = automatizável; `confirm`/`danger` = exigem clique consciente + preview obrigatório.

| id | label | risco | ação |
|----|-------|-------|------|
| `xcode_derived`   | Xcode DerivedData              | safe    | TrashPaths (conteúdo de `~/Library/Developer/Xcode/DerivedData`) |
| `sim_unavailable` | Simuladores indisponíveis      | safe    | `xcrun simctl delete unavailable` |
| `coresim_caches`  | CoreSimulator / Caches         | safe    | TrashPaths (conteúdo de `.../CoreSimulator/Caches`) |
| `gradle_caches`   | Gradle caches                  | safe    | TrashPaths (conteúdo de `~/.gradle/caches`) |
| `brew_cleanup`    | Homebrew cleanup               | safe    | `brew cleanup -s` |
| `jetbrains_old`   | IntelliJ — versões antigas     | confirm | KeepLatest (`Application Support/JetBrains`, prefixo `IntelliJIdea`, keep 1) |
| `studio_old`      | Android Studio — versões antigas | confirm | KeepLatest (`Application Support/Google`, prefixo `AndroidStudio`, keep 1) |
| `ndk_old`         | Android NDK — versões antigas  | danger  | KeepLatest (`~/Library/Android/sdk/ndk`, keep 1) |
| `docker_prune`    | Docker — prune (sem volumes)   | confirm | `docker system prune -a -f` |

**Notas de segurança que a UI deve refletir:**
- `ndk_old` é **danger**: a versão correta depende do `ndkVersion` dos projetos. Manter "mais recente por mtime" é heurística — preview obrigatório e aviso explícito.
- `docker_prune` **nunca** usa `--volumes` (dados de banco em containers sobrevivem). Não adicionar essa flag.
- `KeepLatest` ordena por **mtime desc** e mantém os `keep` mais novos (a versão em uso costuma ter mtime mais recente).

**Extensível:** novas regras = só adicionar `CleanupRule` ao registro. Considerar futuramente: pub cache, CocoaPods cache, `node_modules` órfãos (estilo npkill), system-images Android.

---

## 7. Estado (Cubit)

```dart
sealed class CleanerState {}

class CleanerInitial   extends CleanerState {}
class CleanerScanning  extends CleanerState {}                      // spinner global
class CleanerLoaded    extends CleanerState {                       // resultados prontos
  final List<ScanResult> results;
  final Set<String> selectedRuleIds;
  final int totalReclaimable;                                       // soma dos bytes selecionados conhecidos
}
class CleanerCleaning  extends CleanerState {                       // executando
  final String currentRuleId;
  final int done;
  final int total;
}
class CleanerDone      extends CleanerState { final int freedBytes; }
class CleanerError     extends CleanerState { final String message; }
```

**API do Cubit:**
- `scanAll()` → `Scanning` → `Loaded`.
- `toggleRule(String id)` → atualiza `selectedRuleIds` + recalcula `totalReclaimable`.
- `cleanSelected({bool dryRun = false})` → `Cleaning` (progresso) → `Done` (re-scan opcional p/ atualizar números).

---

## 8. UI / UX

**Tela única** (`cleaner_page.dart`), layout desktop:
- **Header:** título + total recuperável estimado (atualiza com a seleção) + botão **Escanear**.
- **Lista de regras:** cada item mostra `checkbox · label · tamanho formatado · badge de risco · descrição`. Tamanho `?` para comandos (reclaim desconhecido até rodar).
- **Badge de risco:** verde `safe` · âmbar `confirm` · vermelho `danger`.
- **Preview:** expandir um item lista os `targets` (caminhos). Para `confirm`/`danger`, o preview é **obrigatório** antes de habilitar a limpeza.
- **Ações:** botão **Limpar selecionadas** + toggle **Dry-run**. Para itens `danger`, diálogo de confirmação extra que exige reler o aviso.
- **Durante a limpeza:** barra de progresso com a regra atual (`done/total`).
- **Resultado:** snackbar/painel "Liberados X GB. Itens foram para a Lixeira." com atalho pra abrir a Lixeira.
- **Estados vazios/erro:** mensagens claras; nunca deixar a UI travada num spinner.

Formatação de tamanho: helper `_fmt(bytes)` (B/KB/MB/GB/TB) — já existe no motor, extrair para util compartilhado.

> Para a direção visual (tipografia, tokens, hierarquia), consultar a skill **frontend-design** ao construir a `cleaner_page`. Manter macOS-nativo no espírito: denso, legível, sem firulas.

---

## 9. Requisitos de segurança (não negociáveis)

1. **Lixeira por padrão.** `TrashPaths`/`KeepLatest` sempre via Finder. `rm` real só para caches recriáveis e atrás de confirmação.
2. **Preview antes de apagar** para qualquer regra `confirm`/`danger`.
3. **Dry-run disponível** em todas as regras; deve apenas imprimir/retornar os alvos, sem efeito.
4. **Sem `sh -c`** com input do usuário — sempre lista de argumentos.
5. **Docker prune nunca com `--volumes`.**
6. **Idempotência:** rodar duas vezes não deve causar erro (alvos já removidos → no-op).
7. **Falha graciosa:** erro numa regra não aborta as outras; registrar e seguir.

---

## 10. Testes

- **Unit (domínio):** `ScanRules`/`CleanRules` com `CleanerRepository` fake. Verificar dry-run não chama efeitos, seleção filtra corretamente, soma de bytes.
- **Engine (integração leve):** apontar regras para um diretório temporário (`Directory.systemTemp`), validar `_du`, `KeepLatest` (mantém N mais recentes por mtime), e que `trash` em dry-run não move nada.
- **Cubit:** `bloc_test` cobrindo `Initial → Scanning → Loaded → Cleaning → Done` e o caminho de erro.
- Não testar `osascript`/`docker`/`brew` reais em CI (mockar a fronteira de processo).

**Dica de testabilidade:** abstrair a execução de processo num `ProcessRunner` injetável (`Future<ProcessResult> run(String exec, List<String> args)`) para o motor/datasource, permitindo fake nos testes.

---

## 11. Build e distribuição

```bash
flutter create --platforms=macos --org com.deneroliveira disk_cleaner
# mover disk_cleaner_engine.dart para lib/core/cleaner/
# editar os 2 .entitlements (desligar sandbox — §3.1)
flutter run -d macos                 # dev
flutter build macos --release        # release → build/macos/Build/Products/Release/*.app
```

Assinatura + notarização (uso pessoal, fora da App Store):
```bash
codesign --deep --force --options runtime \
  --sign "Developer ID Application: <SEU NOME>" <App>.app
# empacotar em .dmg, então:
xcrun notarytool submit <App>.dmg --apple-id <id> --team-id <team> --wait
xcrun stapler staple <App>.dmg
```
Requer conta Apple Developer paga para "Developer ID". Sem ela, o app roda localmente, mas o Gatekeeper avisa em outras máquinas.

---

## 12. Fases de implementação (sugestão pro Claude Code)

1. **Scaffold + engine:** `flutter create`, mover o motor, editar entitlements, `flutter run` mostrando "Hello".
2. **Domínio + data:** entidades, `CleanerRepository`, `system_cleaner_datasource` envolvendo o `CleanerEngine`, `default_rules.dart`, DI.
3. **Cubit:** estados + `scanAll`/`toggleRule`/`cleanSelected`, com `bloc_test`.
4. **UI:** `cleaner_page` com lista, badges, preview, dry-run e progresso (consultar frontend-design).
5. **Segurança/polish:** confirmação extra pra `danger`, re-scan pós-limpeza, estados de erro, abrir Lixeira.
6. **Build:** release + notarização + `.dmg`.

---

## 13. Critérios de aceite

- [ ] App roda em macOS (`flutter run -d macos`) sem erro de sandbox.
- [ ] Escanear lista todas as regras com tamanho correto (validado contra `du -sh` manual).
- [ ] Itens vão para a **Lixeira** e aparecem com "Pôr de volta".
- [ ] `confirm`/`danger` exigem preview + confirmação; `danger` tem aviso reforçado.
- [ ] Dry-run não causa nenhum efeito colateral.
- [ ] Docker prune não remove volumes.
- [ ] Erro em uma regra não derruba as demais.
- [ ] Testes de domínio e Cubit passando.

---

### Referência
- Motor pronto: `disk_cleaner_engine.dart` (Dart puro, roda como CLI: `dart run disk_cleaner_engine.dart [--apply]`).
