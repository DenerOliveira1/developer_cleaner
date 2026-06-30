/// DevDisk cleaning engine — pure Dart, no Flutter.
///
/// Also runnable as a CLI for validation:
///   dart run lib/core/cleaner/disk_cleaner_engine.dart          # scan only
///   dart run lib/core/cleaner/disk_cleaner_engine.dart --apply  # clean safe rules
library;

import 'dart:convert';
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

  /// Bytes currently sitting in the user's Trash (`~/.Trash`). Drives the
  /// empty-Trash progress: as Finder deletes, this shrinks and we report the
  /// observed fraction removed. A missing/empty Trash is 0 (idempotency).
  /// Volume-level Trashes (`/Volumes/.../.Trashes`) are intentionally out of
  /// scope — `du ~/.Trash` doesn't reach them.
  Future<int> trashSizeBytes() async => du(['$_home/.Trash']);

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

  /// Plan for [DeleteSimRuntimes]: keep the [keep] newest **deletable iOS**
  /// simulator runtime disk images (by version), remove the rest.
  ///
  /// Uses `simctl runtime list -j` (a map keyed by image UUID) — that UUID is
  /// what `simctl runtime delete` expects (the SimRuntime identifier does NOT
  /// work), and the entries carry `sizeBytes` so no `du` is needed.
  Future<({List<String> ids, List<String> labels, int bytes, String? keepNote})>
      _simRuntimePlan(int keep) async {
    final res = await _runner.run('xcrun', ['simctl', 'runtime', 'list', '-j']);
    final out = (res.stdout as String?) ?? '';
    if (out.trim().isEmpty) {
      return (ids: <String>[], labels: <String>[], bytes: 0, keepNote: null);
    }
    final map = (jsonDecode(out) as Map).cast<String, dynamic>();
    final runtimes = map.values
        .cast<Map<String, dynamic>>()
        .where((r) =>
            r['platformIdentifier'] == 'com.apple.platform.iphonesimulator' &&
            r['deletable'] == true)
        .toList()
      ..sort((a, b) =>
          _compareVersions('${b['version']}', '${a['version']}')); // desc
    final remove = runtimes.skip(keep).toList();
    return (
      ids: remove.map((r) => '${r['identifier']}').toList(), // image UUID
      labels: remove.map((r) => 'iOS ${r['version']} (${r['build']})').toList(),
      bytes: remove.fold<int>(
          0, (s, r) => s + ((r['sizeBytes'] as num?)?.toInt() ?? 0)),
      keepNote: runtimes.take(keep).map((r) => 'iOS ${r['version']}').join(', '),
    );
  }

  /// Numeric dotted-version compare (`18.10` > `18.9`).
  static int _compareVersions(String a, String b) {
    final pa = a.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final pb = b.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    for (var i = 0; i < pa.length || i < pb.length; i++) {
      final x = i < pa.length ? pa[i] : 0;
      final y = i < pb.length ? pb[i] : 0;
      if (x != y) return x.compareTo(y);
    }
    return 0;
  }

  /// Directory names never descended into while discovering Flutter projects
  /// (heavy/irrelevant trees), mirroring the user's clean scripts.
  static const _pruneDirs = {
    'build', '.dart_tool', 'node_modules', 'Pods', '.git', '.fvm', '.symlinks',
  };

  /// Finds the recreatable artifact dirs of projects under [a.roots]: a project
  /// is a dir with [a.markerFile] matching [a.markerPattern]; its existing
  /// [a.artifactDirs] become targets. Walks at most [a.maxDepth] levels,
  /// pruning [_pruneDirs] (so it never descends into node_modules/Pods/etc.).
  List<String> _findProjectArtifacts(ProjectArtifacts a) {
    final out = <String>[];
    final pattern = RegExp(a.markerPattern);

    void walk(Directory dir, int depth) {
      List<FileSystemEntity> entries;
      try {
        entries = dir.listSync(followLinks: false);
      } catch (_) {
        return; // unreadable dir — skip
      }

      final marker = File('${dir.path}/${a.markerFile}');
      if (marker.existsSync()) {
        try {
          if (pattern.hasMatch(marker.readAsStringSync())) {
            for (final rel in a.artifactDirs) {
              final d = Directory('${dir.path}/$rel');
              if (d.existsSync()) out.add(d.path);
            }
          }
        } catch (_) {/* ignore unreadable marker */}
      }

      if (depth >= a.maxDepth) return;
      for (final e in entries) {
        if (e is Directory && !_pruneDirs.contains(e.path.split('/').last)) {
          walk(e, depth + 1);
        }
      }
    }

    for (final r in a.roots) {
      final d = Directory(expandHome(r));
      if (d.existsSync()) walk(d, 0);
    }
    return out;
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
      case DeleteSimRuntimes(:final keep):
        final plan = await _simRuntimePlan(keep);
        return ScanResult(
          rule: rule,
          bytes: plan.bytes, // from sizeBytes — fast and accurate
          targets: plan.labels,
          keepNote: plan.keepNote,
        );
      case ProjectArtifacts a:
        final targets = _findProjectArtifacts(a);
        return ScanResult(rule: rule, bytes: await du(targets), targets: targets);
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
      case DeleteSimRuntimes(:final keep):
        final plan = await _simRuntimePlan(keep);
        if (dryRun) return;
        // Irreversible: simctl runtime delete (no Trash). One per runtime so a
        // single failure doesn't abort the rest.
        for (final id in plan.ids) {
          final res =
              await _runner.run('xcrun', ['simctl', 'runtime', 'delete', id]);
          if (res.exitCode != 0) {
            throw CleanerException(
                'Falha ao remover runtime $id — ${res.stderr}');
          }
        }
      case ProjectArtifacts a:
        if (dryRun) return;
        await trashAll(_findProjectArtifacts(a)); // reversible
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
    // Irreversible (simctl delete — no Trash), so never 'safe' by default.
    safety: Safety.confirm,
    action: RunCommand('xcrun', ['simctl', 'delete', 'unavailable']),
  ),
  CleanupRule(
    id: 'coresim',
    label: 'Caches do CoreSimulator',
    description: 'Dados de simulador em cache e snapshots de dispositivos.',
    safety: Safety.safe,
    // Recreatable cache only. NEVER include Cryptex/Devices/Volumes — those are
    // the simulator runtime and data, not cache.
    action: TrashPaths([
      '~/Library/Developer/CoreSimulator/Caches',
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
    // Irreversible (brew cleanup — no Trash), so never 'safe' by default.
    safety: Safety.confirm,
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
  CleanupRule(
    id: 'simruntime',
    label: 'Simulador iOS — runtimes antigos',
    description:
        'Mantém só o iOS mais recente; remove os runtimes antigos. Irreversível.',
    safety: Safety.danger,
    action: DeleteSimRuntimes(keep: 1),
  ),
  CleanupRule(
    id: 'flutter',
    label: 'Flutter — build/.dart_tool',
    description:
        'build/ e .dart_tool/ de todos os projetos Flutter (recriáveis no próximo build).',
    safety: Safety.confirm,
    action: ProjectArtifacts(
      roots: kProjectRoots,
      markerFile: 'pubspec.yaml',
      markerPattern: r'(^|\n)\s*(flutter:|sdk:\s*flutter)',
      artifactDirs: ['build', '.dart_tool'],
    ),
  ),
  CleanupRule(
    id: 'react',
    label: 'React Native — node_modules/Pods/build',
    description:
        'node_modules, Pods e saídas de build dos projetos React Native (recriáveis com install/build).',
    safety: Safety.confirm,
    action: ProjectArtifacts(
      roots: kProjectRoots,
      markerFile: 'package.json',
      markerPattern: r'"(react-native|expo)"',
      artifactDirs: [
        'node_modules',
        'ios/Pods',
        'ios/build',
        'android/build',
        'android/app/build',
        'android/.gradle',
      ],
    ),
  ),
  CleanupRule(
    id: 'web',
    label: 'React / Next.js — node_modules/.next/build',
    description:
        'node_modules e saídas de build web (.next, build, dist, out) de projetos React/Next.',
    safety: Safety.confirm,
    action: ProjectArtifacts(
      roots: kProjectRoots,
      markerFile: 'package.json',
      markerPattern: r'"(next|react)"',
      artifactDirs: ['node_modules', '.next', 'build', 'dist', 'out'],
    ),
  ),
  CleanupRule(
    id: 'php',
    label: 'PHP — vendor (Composer)',
    description:
        'Dependências do Composer (vendor/) de projetos PHP (recriáveis com composer install).',
    safety: Safety.confirm,
    action: ProjectArtifacts(
      roots: kProjectRoots,
      markerFile: 'composer.json',
      markerPattern: r'.', // composer.json presence already signals PHP
      artifactDirs: ['vendor'],
    ),
  ),
];

/// Common developer project roots scanned by the project-artifact rules. Only
/// the ones that exist are walked.
const List<String> kProjectRoots = [
  '~/StudioProjects',
  '~/IdeaProjects',
  '~/AndroidStudioProjects',
  '~/Projects',
  '~/Documents',
  '~/dev',
  '~/development',
  '~/code',
  '~/src',
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
        // Graceful failure: one rule's error doesn't abort the others (spec §9.7).
        stdout.writeln('  ERRO ${rule.id}: $e');
      }
    }
  }
}
