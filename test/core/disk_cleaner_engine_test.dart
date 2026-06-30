import 'dart:io';

import 'package:developer_cleaner/core/cleaner/disk_cleaner_engine.dart';
import 'package:developer_cleaner/core/process/process_runner.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records every process invocation and returns canned results. Lets us assert
/// that dry-run never invokes `osascript`, and that real `du` is used.
class FakeProcessRunner implements ProcessRunner {
  final calls = <(String, List<String>)>[];

  /// Optional override keyed by executable name.
  final Map<String, ProcessResult> responses;

  FakeProcessRunner([this.responses = const {}]);

  @override
  Future<ProcessResult> run(String executable, List<String> args) async {
    calls.add((executable, args));
    final canned = responses[executable];
    if (canned != null) return canned;
    return ProcessResult(0, 0, '', '');
  }
}

/// Runs `du` for real (so size logic is exercised) but fakes everything else.
class DuRealRunner implements ProcessRunner {
  final calls = <(String, List<String>)>[];
  @override
  Future<ProcessResult> run(String executable, List<String> args) async {
    calls.add((executable, args));
    if (executable == 'du') return Process.run('du', args);
    return ProcessResult(0, 0, '', '');
  }
}

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('devdisk_engine_');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('du sums real sizes and ignores missing paths', () async {
    final runner = DuRealRunner();
    final engine = CleanerEngine(runner: runner);

    final f = File('${tmp.path}/blob.bin')..createSync();
    f.writeAsBytesSync(List.filled(100 * 1024, 0)); // ~100 KB

    final bytes =
        await engine.du(['${tmp.path}/blob.bin', '${tmp.path}/missing']);
    expect(bytes, greaterThanOrEqualTo(100 * 1024));
  });

  test('KeepLatest keeps the N newest by mtime and trashes the rest',
      () async {
    final runner = FakeProcessRunner();
    final engine = CleanerEngine(runner: runner);

    final parent = Directory('${tmp.path}/ndk')..createSync();
    // Create three versions with increasing mtime (dart:io can't set a
    // directory's mtime, so use `touch -t CCYYMMDDhhmm`).
    final older = Directory('${parent.path}/21.0')..createSync();
    final mid = Directory('${parent.path}/23.0')..createSync();
    final newest = Directory('${parent.path}/25.0')..createSync();
    Process.runSync('touch', ['-t', '202001010000', older.path]);
    Process.runSync('touch', ['-t', '202201010000', mid.path]);
    Process.runSync('touch', ['-t', '202401010000', newest.path]);

    final rule = CleanupRule(
      id: 'ndk',
      label: 'ndk',
      description: '',
      safety: Safety.danger,
      action: KeepLatest(parent.path, keep: 1),
    );

    final result = await engine.scan(rule);
    // Keeps the newest, removes the two older.
    expect(result.keepNote, '25.0');
    expect(result.targets, containsAll([older.path, mid.path]));
    expect(result.targets, isNot(contains(newest.path)));

    // Cleaning trashes the two older dirs in one batched osascript call.
    await engine.clean(rule);
    final osascriptCalls =
        runner.calls.where((c) => c.$1 == 'osascript').toList();
    expect(osascriptCalls.length, 1);
    final script = osascriptCalls.single.$2[1];
    expect(script, contains(older.path));
    expect(script, contains(mid.path));
    expect(script, isNot(contains(newest.path)));
  });

  test('dry-run does not trash anything', () async {
    final runner = FakeProcessRunner();
    final engine = CleanerEngine(runner: runner);

    final dir = Directory('${tmp.path}/DerivedData')..createSync();
    File('${dir.path}/a.o').createSync();

    final rule = CleanupRule(
      id: 'derived',
      label: 'derived',
      description: '',
      safety: Safety.safe,
      action: TrashPaths([dir.path], contentsOnly: true),
    );

    await engine.clean(rule, dryRun: true);
    expect(runner.calls.any((c) => c.$1 == 'osascript'), isFalse);
    // The file is untouched.
    expect(File('${dir.path}/a.o').existsSync(), isTrue);
  });

  test('RunCommand rule scans with unknown bytes and runs the exact command',
      () async {
    final runner = FakeProcessRunner();
    final engine = CleanerEngine(runner: runner);

    const rule = CleanupRule(
      id: 'docker',
      label: 'docker',
      description: '',
      safety: Safety.confirm,
      action: RunCommand('docker', ['system', 'prune', '-a', '-f']),
    );

    final scan = await engine.scan(rule);
    expect(scan.bytes, isNull);
    expect(scan.targets.single, 'docker system prune -a -f');

    await engine.clean(rule);
    expect(runner.calls.single.$1, 'docker');
    expect(runner.calls.single.$2, ['system', 'prune', '-a', '-f']);
    // Safety: never with --volumes.
    expect(runner.calls.single.$2, isNot(contains('--volumes')));
  });

  test('DeleteSimRuntimes keeps the latest iOS runtime, deletes older ones',
      () async {
    // `simctl runtime list -j` shape: a map keyed by disk-image UUID.
    const ios = 'com.apple.platform.iphonesimulator';
    const watch = 'com.apple.platform.watchsimulator';
    final json = '''
    {
      "UUID-180": {"identifier":"UUID-180","version":"18.0","build":"22A","platformIdentifier":"$ios","deletable":true,"sizeBytes":8000000000},
      "UUID-185": {"identifier":"UUID-185","version":"18.5","build":"22F","platformIdentifier":"$ios","deletable":true,"sizeBytes":9000000000},
      "UUID-265": {"identifier":"UUID-265","version":"26.5","build":"23F","platformIdentifier":"$ios","deletable":true,"sizeBytes":8000000000},
      "UUID-watch": {"identifier":"UUID-watch","version":"11.0","build":"x","platformIdentifier":"$watch","deletable":true,"sizeBytes":5000000000}
    }''';
    final runner = FakeProcessRunner({'xcrun': ProcessResult(0, 0, json, '')});
    final engine = CleanerEngine(runner: runner);
    const rule = CleanupRule(
      id: 'simruntime',
      label: 'simruntime',
      description: '',
      safety: Safety.danger,
      action: DeleteSimRuntimes(keep: 1),
    );

    final scan = await engine.scan(rule);
    expect(scan.keepNote, 'iOS 26.5'); // newest by version
    expect(scan.targets.length, 2); // 18.0 + 18.5; watchOS filtered out
    expect(scan.targets.any((t) => t.contains('18.0')), isTrue);
    expect(scan.bytes, 8000000000 + 9000000000); // sum of removed sizeBytes

    await engine.clean(rule);
    final deletes = runner.calls
        .where((c) => c.$1 == 'xcrun' && c.$2.contains('delete'))
        .toList();
    expect(deletes.length, 2);
    // Deletes by image UUID (not the SimRuntime identifier).
    expect(deletes.any((c) => c.$2.contains('UUID-180')), isTrue);
    expect(deletes.any((c) => c.$2.contains('UUID-265')), isFalse); // kept
  });

  test('FlutterArtifacts discovers projects and trashes build/.dart_tool',
      () async {
    final runner = FakeProcessRunner();
    final engine = CleanerEngine(runner: runner);

    // A Flutter project with build/ + .dart_tool/.
    final app = Directory('${tmp.path}/app')..createSync();
    File('${app.path}/pubspec.yaml')
        .writeAsStringSync('name: app\ndependencies:\n  flutter:\n    sdk: flutter\n');
    Directory('${app.path}/build').createSync();
    Directory('${app.path}/.dart_tool').createSync();
    Directory('${app.path}/lib').createSync(); // not an artifact

    // A pure Dart package (no flutter) — must be ignored.
    final pkg = Directory('${tmp.path}/pure')..createSync();
    File('${pkg.path}/pubspec.yaml').writeAsStringSync('name: pure\n');
    Directory('${pkg.path}/.dart_tool').createSync();

    final rule = CleanupRule(
      id: 'flutter',
      label: 'flutter',
      description: '',
      safety: Safety.confirm,
      action: FlutterArtifacts(roots: [tmp.path]),
    );

    final scan = await engine.scan(rule);
    expect(scan.targets, containsAll([
      '${app.path}/build',
      '${app.path}/.dart_tool',
    ]));
    // The pure Dart package's .dart_tool is not targeted.
    expect(scan.targets, isNot(contains('${pkg.path}/.dart_tool')));

    await engine.clean(rule);
    expect(runner.calls.where((c) => c.$1 == 'osascript').length, greaterThan(0));
  });

  test('trash uses osascript Finder and never sh -c', () async {
    final runner = FakeProcessRunner();
    final engine = CleanerEngine(runner: runner);
    await engine.trash('/Users/me/Library/Caches/x');
    final call = runner.calls.single;
    expect(call.$1, 'osascript');
    expect(call.$2.first, '-e');
    expect(call.$2[1], contains('tell application "Finder" to delete'));
    expect(runner.calls.any((c) => c.$1 == 'sh'), isFalse);
  });
}
