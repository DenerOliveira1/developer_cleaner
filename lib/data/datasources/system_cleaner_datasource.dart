// The engine re-exports the pure cleaning types (CleanupRule/ScanResult/
// DiskStats), so a single import covers both the engine and the entities.
import 'package:developer_cleaner/core/cleaner/disk_cleaner_engine.dart';

/// Thin wrapper exposing the [CleanerEngine] to the data layer. Keeps the
/// engine (infra detail) separable from the repository implementation.
class SystemCleanerDataSource {
  final CleanerEngine _engine;
  const SystemCleanerDataSource(this._engine);

  Future<ScanResult> scan(CleanupRule rule) => _engine.scan(rule);

  Future<void> clean(CleanupRule rule, {bool dryRun = false}) =>
      _engine.clean(rule, dryRun: dryRun);

  Future<DiskStats> diskStats(
          {void Function(double progress, String? path)? onProgress}) =>
      _engine.diskStats(onProgress: onProgress);

  Future<int> diskFreeBytes() => _engine.diskFreeBytes();

  Future<int> trashSizeBytes() => _engine.trashSizeBytes();

  Future<void> emptyTrash() => _engine.emptyTrash();
}
