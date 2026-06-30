import '../entities/cleanup_rule.dart';
import '../entities/scan_result.dart';
import '../repositories/cleaner_repository.dart';

/// Scans a set of rules in order, reporting progress so the Scanning screen can
/// show the current rule and a percentage. Sequential (not `Future.wait`) so the
/// "Reading {rule}…" readout is meaningful.
class ScanRules {
  final CleanerRepository _repo;
  const ScanRules(this._repo);

  Future<List<ScanResult>> call(
    List<CleanupRule> rules, {
    void Function(int index, CleanupRule rule)? onProgress,
  }) async {
    final out = <ScanResult>[];
    for (var i = 0; i < rules.length; i++) {
      onProgress?.call(i, rules[i]);
      out.add(await _repo.scan(rules[i]));
    }
    return out;
  }
}
