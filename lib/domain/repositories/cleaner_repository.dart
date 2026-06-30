import '../entities/cleanup_rule.dart';
import '../entities/disk_stats.dart';
import '../entities/scan_result.dart';

/// The boundary the engine (Process/osascript) hides behind. The presentation
/// layer talks only to this — never to `dart:io`.
abstract class CleanerRepository {
  /// Estimates reclaimable space and affected paths for a rule.
  Future<ScanResult> scan(CleanupRule rule);

  /// Executes a rule. [dryRun] performs no side effect (spec §9.3).
  Future<void> clean(CleanupRule rule, {bool dryRun = false});

  /// Whole-disk usage + breakdown for the gauge.
  Future<DiskStats> diskStats();

  /// Free bytes on `/` — cheap (no `du`). For measuring space freed post-clean.
  Future<int> diskFreeBytes();

  /// Bytes currently in the Trash. Polled during [emptyTrash] to report the
  /// observed progress as Finder deletes.
  Future<int> trashSizeBytes();

  /// Permanently empties the Trash — the one irreversible action.
  Future<void> emptyTrash();
}
