import '../entities/cleanup_rule.dart';
import '../repositories/cleaner_repository.dart';

/// A rule that failed during a cleanup run. [code] identifies the failure for
/// localization (null = an unexpected/non-engine error); [detail] is the raw,
/// non-localized diagnostic (path / command stderr).
class CleanFailure {
  final String ruleId;
  final CleanerErrorCode? code;
  final String? detail;
  const CleanFailure(this.ruleId, {this.code, this.detail});
}

/// Cleans the selected rules in order. A failure in one rule is recorded and
/// the run continues (spec §9.7 — graceful failure). [dryRun] performs no
/// side effects (spec §9.3).
class CleanRules {
  final CleanerRepository _repo;
  const CleanRules(this._repo);

  Future<List<CleanFailure>> call(
    List<CleanupRule> rules, {
    bool dryRun = false,
    void Function(int index, CleanupRule rule)? onProgress,
  }) async {
    final failures = <CleanFailure>[];
    for (var i = 0; i < rules.length; i++) {
      onProgress?.call(i, rules[i]);
      try {
        await _repo.clean(rules[i], dryRun: dryRun);
      } catch (e) {
        failures.add(e is CleanerException
            ? CleanFailure(rules[i].id, code: e.code, detail: e.detail)
            : CleanFailure(rules[i].id, detail: e.toString()));
      }
    }
    return failures;
  }
}
