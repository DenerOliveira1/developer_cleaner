import 'package:bloc_test/bloc_test.dart';
import 'package:developer_cleaner/core/cleaner/clean_models.dart';
import 'package:developer_cleaner/domain/entities/clean_outcome.dart';
import 'package:developer_cleaner/domain/repositories/cleaner_repository.dart';
import 'package:developer_cleaner/domain/usecases/clean_rules.dart';
import 'package:developer_cleaner/domain/usecases/scan_rules.dart';
import 'package:developer_cleaner/presentation/cubit/cleaner_cubit.dart';
import 'package:developer_cleaner/presentation/cubit/cleaner_state.dart';
import 'package:developer_cleaner/presentation/l10n/app_lang.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCleanerRepository extends Mock implements CleanerRepository {}

const _safe = CleanupRule(
  id: 'gradle',
  label: 'gradle',
  description: '',
  safety: Safety.safe,
  action: TrashPaths(['/tmp/gradle'], contentsOnly: true),
);
const _confirm = CleanupRule(
  id: 'docker',
  label: 'docker',
  description: '',
  safety: Safety.confirm,
  action: RunCommand('docker', ['system', 'prune', '-a', '-f']),
);
const _danger = CleanupRule(
  id: 'ndk',
  label: 'ndk',
  description: '',
  safety: Safety.danger,
  action: KeepLatest('/tmp/ndk', keep: 1),
);
const _flutter = CleanupRule(
  id: 'flutter',
  label: 'flutter',
  description: '',
  safety: Safety.confirm,
  action: FlutterArtifacts(roots: ['/tmp/projects']),
);
const _rules = [_safe, _confirm, _danger];

const _disk = DiskStats(totalBytes: 1000, freeBytes: 100, categories: []);

ScanResult _scanOf(CleanupRule r) {
  switch (r.id) {
    case 'gradle':
      return ScanResult(rule: r, bytes: 300, targets: const ['/tmp/gradle']);
    case 'docker':
      return ScanResult(rule: r, bytes: null, targets: const ['docker ...']);
    case 'ndk':
      return ScanResult(
          rule: r, bytes: 500, targets: const ['/tmp/ndk/21'], keepNote: '25');
    default:
      return ScanResult(rule: r, bytes: 0, targets: const []);
  }
}

void main() {
  late MockCleanerRepository repo;

  setUpAll(() => registerFallbackValue(_safe));

  setUp(() {
    repo = MockCleanerRepository();
    when(() => repo.diskStats()).thenAnswer((_) async => _disk);
    when(() => repo.scan(any())).thenAnswer(
        (inv) async => _scanOf(inv.positionalArguments.first as CleanupRule));
    when(() => repo.clean(any(), dryRun: any(named: 'dryRun')))
        .thenAnswer((_) async {});
    when(() => repo.diskFreeBytes()).thenAnswer((_) async => 100);
    when(() => repo.emptyTrash()).thenAnswer((_) async {});
  });

  CleanerCubit build() => CleanerCubit(
        scanRules: ScanRules(repo),
        cleanRules: CleanRules(repo),
        repository: repo,
        rules: _rules,
      );

  blocTest<CleanerCubit, CleanerState>(
    'scanAll: passes through scanning then lands on results with defaults',
    build: build,
    act: (c) => c.scanAll(),
    verify: (c) {
      expect(c.state.phase, CleanerPhase.results);
      expect(c.state.selectedRuleIds, {'gradle'});
      expect(c.state.expandedId, 'ndk');
      expect(c.state.selectedReclaimableBytes, 300);
    },
  );

  blocTest<CleanerCubit, CleanerState>(
    'toggleRule adds the danger rule and flags an unconfirmed gate',
    build: build,
    seed: () => CleanerState(
      phase: CleanerPhase.results,
      results: _rules.map(_scanOf).toList(),
      selectedRuleIds: const {'gradle'},
    ),
    act: (c) => c.toggleRule('ndk'),
    verify: (c) {
      expect(c.state.selectedRuleIds, {'gradle', 'ndk'});
      expect(c.state.hasUnconfirmedDanger, isTrue);
    },
  );

  blocTest<CleanerCubit, CleanerState>(
    'confirmDanger clears the gate',
    build: build,
    seed: () => CleanerState(
      phase: CleanerPhase.results,
      results: _rules.map(_scanOf).toList(),
      selectedRuleIds: const {'ndk'},
    ),
    act: (c) => c.confirmDanger(),
    verify: (c) => expect(c.state.hasUnconfirmedDanger, isFalse),
  );

  blocTest<CleanerCubit, CleanerState>(
    'cleanSelected: cleaning → done with freed (df delta) and in-Trash split',
    build: build,
    seed: () => CleanerState(
      phase: CleanerPhase.results,
      disk: _disk, // freeBefore = 100
      results: _rules.map(_scanOf).toList(),
      selectedRuleIds: const {'gradle', 'ndk'},
      dangerConfirmed: true,
    ),
    act: (c) {
      // After cleaning, free grows to 250 → freed = 150.
      when(() => repo.diskFreeBytes()).thenAnswer((_) async => 250);
      return c.cleanSelected();
    },
    verify: (c) {
      expect(c.state.phase, CleanerPhase.done);
      expect(c.state.outcome!.freedBytes, 150);
      // gradle(300) + ndk(500) are trash-type rules → 800 in Trash.
      expect(c.state.outcome!.inTrashBytes, 800);
    },
  );

  blocTest<CleanerCubit, CleanerState>(
    'a reversible Flutter-artifacts rule counts as in-Trash, not freed',
    build: () => CleanerCubit(
      scanRules: ScanRules(repo),
      cleanRules: CleanRules(repo),
      repository: repo,
      rules: const [_flutter],
    ),
    seed: () => CleanerState(
      phase: CleanerPhase.results,
      disk: _disk, // freeBefore = 100
      results: const [
        ScanResult(rule: _flutter, bytes: 500, targets: ['/tmp/projects/a/build']),
      ],
      selectedRuleIds: const {'flutter'},
    ),
    act: (c) {
      // Trashing doesn't free disk, so df is unchanged.
      when(() => repo.diskFreeBytes()).thenAnswer((_) async => 100);
      return c.cleanSelected();
    },
    verify: (c) {
      expect(c.state.outcome!.inTrashBytes, 500); // went to Trash
      expect(c.state.outcome!.freedBytes, 0); // not freed yet
    },
  );

  blocTest<CleanerCubit, CleanerState>(
    'dry-run cleans nothing and reveals a zero outcome',
    build: build,
    seed: () => CleanerState(
      phase: CleanerPhase.results,
      disk: _disk,
      results: _rules.map(_scanOf).toList(),
      selectedRuleIds: const {'gradle'},
    ),
    act: (c) => c.cleanSelected(dryRun: true),
    verify: (c) {
      expect(c.state.phase, CleanerPhase.done);
      expect(c.state.outcome!.totalBytes, 0);
      verify(() => repo.clean(any(), dryRun: true)).called(1);
      verifyNever(() => repo.clean(any(), dryRun: false));
    },
  );

  blocTest<CleanerCubit, CleanerState>(
    'restart returns to idle, clears the run, keeps language, reloads disk',
    build: build,
    seed: () => const CleanerState(
      phase: CleanerPhase.done,
      lang: AppLang.en,
      selectedRuleIds: {'gradle'},
      dangerConfirmed: true,
      outcome: CleanOutcome(freedBytes: 1, inTrashBytes: 2),
    ),
    act: (c) => c.restart(),
    verify: (c) {
      expect(c.state.phase, CleanerPhase.idle);
      expect(c.state.lang, AppLang.en);
      expect(c.state.selectedRuleIds, isEmpty);
      expect(c.state.dangerConfirmed, isFalse);
      expect(c.state.outcome, isNull);
      expect(c.state.disk, _disk);
    },
  );

  blocTest<CleanerCubit, CleanerState>(
    'scanAll surfaces an error when scanning throws',
    build: build,
    setUp: () => when(() => repo.scan(any()))
        .thenThrow(const CleanerException('boom')),
    act: (c) => c.scanAll(),
    verify: (c) {
      expect(c.state.phase, CleanerPhase.error);
      expect(c.state.error, contains('boom'));
    },
  );
}
