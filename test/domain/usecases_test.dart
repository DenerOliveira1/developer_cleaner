import 'package:developer_cleaner/core/cleaner/clean_models.dart';
import 'package:developer_cleaner/domain/repositories/cleaner_repository.dart';
import 'package:developer_cleaner/domain/usecases/clean_rules.dart';
import 'package:developer_cleaner/domain/usecases/scan_rules.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCleanerRepository extends Mock implements CleanerRepository {}

CleanupRule _rule(String id, {CleanAction? action, Safety safety = Safety.safe}) =>
    CleanupRule(
      id: id,
      label: id,
      description: '',
      safety: safety,
      action: action ?? const RunCommand('noop', []),
    );

void main() {
  late MockCleanerRepository repo;

  setUp(() {
    repo = MockCleanerRepository();
    registerFallbackValue(_rule('fallback'));
  });

  group('ScanRules', () {
    test('scans every rule and preserves order', () async {
      final rules = [_rule('a'), _rule('b'), _rule('c')];
      when(() => repo.scan(any())).thenAnswer((inv) async {
        final r = inv.positionalArguments.first as CleanupRule;
        return ScanResult(rule: r, bytes: 1, targets: const []);
      });

      final results = await ScanRules(repo)(rules);

      expect(results.map((r) => r.rule.id), ['a', 'b', 'c']);
      verify(() => repo.scan(any())).called(3);
    });
  });

  group('CleanRules', () {
    test('dry-run delegates with dryRun:true', () async {
      when(() => repo.clean(any(), dryRun: any(named: 'dryRun')))
          .thenAnswer((_) async {});

      await CleanRules(repo)([_rule('a')], dryRun: true);

      verify(() => repo.clean(any(), dryRun: true)).called(1);
      verifyNever(() => repo.clean(any(), dryRun: false));
    });

    test('a failing rule does not abort the rest and is reported', () async {
      final rules = [_rule('a'), _rule('boom'), _rule('c')];
      when(() => repo.clean(any(), dryRun: any(named: 'dryRun')))
          .thenAnswer((inv) async {
        final r = inv.positionalArguments.first as CleanupRule;
        if (r.id == 'boom') throw const CleanerException('kaboom');
      });

      final failures = await CleanRules(repo)(rules);

      expect(failures.map((f) => f.ruleId), ['boom']);
      expect(failures.single.message, contains('kaboom'));
      // All three were still attempted.
      verify(() => repo.clean(any(), dryRun: any(named: 'dryRun'))).called(3);
    });

    test('reports progress in order', () async {
      final rules = [_rule('a'), _rule('b')];
      when(() => repo.clean(any(), dryRun: any(named: 'dryRun')))
          .thenAnswer((_) async {});
      final seen = <String>[];

      await CleanRules(repo)(rules,
          onProgress: (i, rule) => seen.add('$i:${rule.id}'));

      expect(seen, ['0:a', '1:b']);
    });
  });
}
