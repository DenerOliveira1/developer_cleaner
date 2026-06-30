/// DevDisk cleaning engine — pure Dart, no Flutter.
///
/// Also runnable as a CLI for validation:
///   dart run lib/core/cleaner/disk_cleaner_engine.dart          # scan only
///   dart run lib/core/cleaner/disk_cleaner_engine.dart --apply  # clean safe rules
library;

import 'dart:io';

import '../process/process_runner.dart';
import '../util/byte_format.dart';
import 'clean_models.dart';

export 'clean_models.dart';

/// Plan produced by [CleanerEngine._keepLatestPlan].
typedef _KeepPlan = ({List<String> remove, String? keepNote});

/// Scans and cleans developer junk. Reversible by default: filesystem targets
/// go to the Trash via Finder; never `rm -rf`.
class CleanerEngine {
  final ProcessRunner _runner;

  CleanerEngine({ProcessRunner runner = const SystemProcessRunner()})
      : _runner = runner;

  String get _home => Platform.environment['HOME'] ?? '';

  /// Expands a leading `~` to `$HOME`.
  String expandHome(String p) {
    if (p == '~') return _home;
    if (p.startsWith('~/')) return '$_home/${p.substring(2)}';
    return p;
  }

  bool _exists(String path) =>
      FileSystemEntity.typeSync(path) != FileSystemEntityType.notFound;

  /// Total size of [paths] in bytes via `du -sk`. Missing paths are ignored
  /// (idempotency, spec §9.6).
  Future<int> du(List<String> paths) async {
    final existing = paths.where(_exists).toList();
    if (existing.isEmpty) return 0;
    final res = await _runner.run('du', ['-sk', ...existing]);
    final out = (res.stdout as String?) ?? '';
    var totalKb = 0;
    for (final line in out.split('\n')) {
      final t = line.trim();
      if (t.isEmpty) continue;
      final kb = int.tryParse(t.split(RegExp(r'\s+')).first);
      if (kb != null) totalKb += kb;
    }
    return totalKb * 1024;
  }

  /// Moves a single path to the Trash (reversible — "Put Back" works).
  Future<void> trash(String path) async {
    final script = 'tell application "Finder" to delete POSIX file "$path"';
    final res = await _runner.run('osascript', ['-e', script]);
    if (res.exitCode != 0) {
      throw CleanerException(
          'Falha ao mover para a Lixeira: $path — ${res.stderr}');
    }
  }

  /// Moves many paths to the Trash in as few Finder calls as possible. One
  /// `osascript` per chunk (a list `delete {POSIX file …, …}`) instead of one
  /// process per path — orders of magnitude faster for caches with many
  /// entries. Chunked to stay under the command-argument length limit.
  Future<void> trashAll(List<String> paths) async {
    const chunkSize = 100;
    for (var start = 0; start < paths.length; start += chunkSize) {
      final chunk = paths.sublist(
          start, start + chunkSize > paths.length ? paths.length : start + chunkSize);
      final list = chunk.map((p) => 'POSIX file "$p"').join(', ');
      final res = await _runner.run(
          'osascript', ['-e', 'tell application "Finder" to delete {$list}']);
      if (res.exitCode != 0) {
        throw CleanerException('Falha ao mover para a Lixeira — ${res.stderr}');
      }
    }
  }

  /// Empties the Trash. The one irreversible step in the app.
  Future<void> emptyTrash() async {
    final res = await _runner.run(
        'osascript', ['-e', 'tell application "Finder" to empty trash']);
    if (res.exitCode != 0) {
      throw CleanerException('Falha ao esvaziar a Lixeira — ${res.stderr}');
    }
  }

  /// Resolves the directories to remove under a [KeepLatest] action: keep the
  /// [keep] newest by mtime, remove the rest.
  _KeepPlan _keepLatestPlan(String parent, String? prefix, int keep) {
    final dir = Directory(parent);
    if (!dir.existsSync()) return (remove: <String>[], keepNote: null);
    final entries = dir.listSync().whereType<Directory>().where((d) {
      final name = d.path.split('/').last;
      return prefix == null || prefix.isEmpty || name.startsWith(prefix);
    }).toList()
      ..sort((a, b) =>
          b.statSync().modified.compareTo(a.statSync().modified)); // mtime desc
    final kept = entries.take(keep).toList();
    final remove = entries.skip(keep).map((e) => e.path).toList();
    final keepNote = kept.isEmpty
        ? null
        : kept.map((e) => e.path.split('/').last).join(', ');
    return (remove: remove, keepNote: keepNote);
  }

  /// Scans one rule: estimates reclaimable bytes and the affected paths.
  Future<ScanResult> scan(CleanupRule rule) async {
    switch (rule.action) {
      case TrashPaths(:final paths):
        final resolved = paths.map(expandHome).where(_exists).toList();
        return ScanResult(
            rule: rule, bytes: await du(resolved), targets: resolved);
      case RunCommand(:final executable, :final args):
        return ScanResult(
          rule: rule,
          bytes: null,
          targets: ['$executable ${args.join(' ')}'],
        );
      case KeepLatest(:final parentDir, :final namePrefix, :final keep):
        final plan = _keepLatestPlan(expandHome(parentDir), namePrefix, keep);
        return ScanResult(
          rule: rule,
          bytes: await du(plan.remove),
          targets: plan.remove,
          keepNote: plan.keepNote,
        );
    }
  }

  /// Executes one rule. [dryRun] returns without any side effect (spec §9.3).
  Future<void> clean(CleanupRule rule, {bool dryRun = false}) async {
    switch (rule.action) {
      case TrashPaths(:final paths, :final contentsOnly):
        final resolved = paths.map(expandHome).where(_exists).toList();
        final targets = <String>[];
        if (contentsOnly) {
          for (final p in resolved) {
            targets.addAll(Directory(p).listSync().map((e) => e.path));
          }
        } else {
          targets.addAll(resolved);
        }
        if (dryRun) return;
        await trashAll(targets);
      case RunCommand(:final executable, :final args):
        if (dryRun) return;
        final res = await _runner.run(executable, args);
        if (res.exitCode != 0) {
          throw CleanerException(
              'Comando falhou: $executable ${args.join(' ')} — ${res.stderr}');
        }
      case KeepLatest(:final parentDir, :final namePrefix, :final keep):
        final plan = _keepLatestPlan(expandHome(parentDir), namePrefix, keep);
        if (dryRun) return;
        await trashAll(plan.remove);
    }
  }

  /// `df -k /` → (total, free) in bytes. Fast (no `du`).
  Future<(int, int)> _dfTotalFree() async {
    final df = await _runner.run('df', ['-k', '/']);
    final lines = ((df.stdout as String?) ?? '').trim().split('\n');
    if (lines.length >= 2) {
      // Filesystem 1024-blocks Used Available Capacity ... Mounted-on
      final parts = lines[1].split(RegExp(r'\s+'));
      if (parts.length >= 4) {
        return (
          (int.tryParse(parts[1]) ?? 0) * 1024,
          (int.tryParse(parts[3]) ?? 0) * 1024,
        );
      }
    }
    return (0, 0);
  }

  /// Free bytes on `/` — cheap (`df` only). Used to measure space freed by a
  /// cleanup without re-running the slow `du` breakdown.
  Future<int> diskFreeBytes() async => (await _dfTotalFree()).$2;

  /// Whole-disk stats for the gauge: `df -k /` for total/free, plus a `du`
  /// breakdown over anchor directories mapped to the design's 6 categories.
  Future<DiskStats> diskStats() async {
    final (total, free) = await _dfTotalFree();

    final xcode = await du([expandHome('~/Library/Developer')]);
    final caches = await du([expandHome('~/Library/Caches')]);
    final androidSdk = await du([expandHome('~/Library/Android/sdk')]);
    final appSupport = await du([
      expandHome('~/Library/Application Support/JetBrains'),
      expandHome('~/Library/Application Support/Google'),
    ]);
    final used = total - free;
    final other =
        (used - xcode - caches - androidSdk - appSupport).clamp(0, used);

    return DiskStats(
      totalBytes: total,
      freeBytes: free,
      categories: [
        DiskCategory('xcode', xcode),
        DiskCategory('caches', caches),
        DiskCategory('androidSdk', androidSdk),
        DiskCategory('appSupport', appSupport),
        DiskCategory('other', other),
        DiskCategory('free', free),
      ],
    );
  }
}

/// Initial rule registry (spec §6). Rule ids match the design prototype.
const List<CleanupRule> kRules = [
  CleanupRule(
    id: 'derived',
    label: 'Xcode DerivedData',
    description: 'Intermediários de build que o Xcode recria no próximo build.',
    safety: Safety.safe,
    action: TrashPaths(['~/Library/Developer/Xcode/DerivedData'],
        contentsOnly: true),
  ),
  CleanupRule(
    id: 'simun',
    label: 'Simuladores indisponíveis',
    description: 'Runtimes de simulador sem suporte no seu Xcode.',
    safety: Safety.safe,
    action: RunCommand('xcrun', ['simctl', 'delete', 'unavailable']),
  ),
  CleanupRule(
    id: 'coresim',
    label: 'Caches do CoreSimulator',
    description: 'Dados de simulador em cache e snapshots de dispositivos.',
    safety: Safety.safe,
    action: TrashPaths([
      '~/Library/Developer/CoreSimulator/Caches',
      '~/Library/Developer/CoreSimulator/Cryptex',
    ], contentsOnly: true),
  ),
  CleanupRule(
    id: 'gradle',
    label: 'Caches do Gradle',
    description: 'Dependências baixadas que o Gradle rebaixa quando preciso.',
    safety: Safety.safe,
    action: TrashPaths([
      '~/.gradle/caches',
      '~/.gradle/wrapper/dists',
    ], contentsOnly: true),
  ),
  CleanupRule(
    id: 'brew',
    label: 'Limpeza do Homebrew',
    description: 'Downloads antigos e versões obsoletas de fórmulas.',
    safety: Safety.safe,
    action: RunCommand('brew', ['cleanup', '-s']),
  ),
  CleanupRule(
    id: 'intellij',
    label: 'IntelliJ — versões antigas',
    description: 'Caches e plugins de versões da IDE que você não usa mais.',
    safety: Safety.confirm,
    action: KeepLatest('~/Library/Application Support/JetBrains',
        namePrefix: 'IntelliJIdea', keep: 1),
  ),
  CleanupRule(
    id: 'studio',
    label: 'Android Studio — versões antigas',
    description: 'Caches de versões do Android Studio que você já substituiu.',
    safety: Safety.confirm,
    action: KeepLatest('~/Library/Application Support/Google',
        namePrefix: 'AndroidStudio', keep: 1),
  ),
  CleanupRule(
    id: 'ndk',
    label: 'Android NDK — versões antigas',
    description:
        'O NDK certo depende do ndkVersion dos seus projetos. Revise antes de remover.',
    safety: Safety.danger,
    action: KeepLatest('~/Library/Android/sdk/ndk', keep: 1),
  ),
  CleanupRule(
    id: 'docker',
    label: 'Docker — prune (sem volumes)',
    description:
        'Imagens órfãs e camadas de build paradas. Volumes nomeados não são tocados.',
    safety: Safety.confirm,
    // NEVER add --volumes (spec §9.5).
    action: RunCommand('docker', ['system', 'prune', '-a', '-f']),
  ),
];

/// CLI entry point. Scans all rules; `--apply` cleans the `safe` ones.
Future<void> main(List<String> argv) async {
  if (!Platform.isMacOS) {
    stderr.writeln('DevDisk roda apenas no macOS.');
    exitCode = 1;
    return;
  }
  final apply = argv.contains('--apply');
  final engine = CleanerEngine();

  stdout.writeln('DevDisk — scan\n');
  final results = await Future.wait(kRules.map(engine.scan));
  for (final r in results) {
    final size = formatBytes(r.bytes);
    stdout.writeln(
        '${r.rule.safety.name.padRight(8)} ${r.rule.id.padRight(16)} ${size.padLeft(10)}  ${r.rule.label}');
    for (final t in r.targets) {
      stdout.writeln('    › $t');
    }
    if (r.keepNote != null) {
      stdout.writeln('    ✓ mantém ${r.keepNote}');
    }
  }

  if (apply) {
    stdout.writeln('\n--apply: limpando regras safe...');
    for (final rule in kRules.where((r) => r.safety == Safety.safe)) {
      try {
        await engine.clean(rule);
        stdout.writeln('  ok ${rule.id}');
      } catch (e) {
        // Falha graciosa: uma regra não derruba as outras (spec §9.7).
        stdout.writeln('  ERRO ${rule.id}: $e');
      }
    }
  }
}
