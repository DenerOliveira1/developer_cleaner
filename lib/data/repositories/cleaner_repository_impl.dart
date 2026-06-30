import '../../domain/entities/cleanup_rule.dart';
import '../../domain/entities/disk_stats.dart';
import '../../domain/entities/scan_result.dart';
import '../../domain/repositories/cleaner_repository.dart';
import '../datasources/system_cleaner_datasource.dart';

class CleanerRepositoryImpl implements CleanerRepository {
  final SystemCleanerDataSource _ds;
  const CleanerRepositoryImpl(this._ds);

  @override
  Future<ScanResult> scan(CleanupRule rule) => _ds.scan(rule);

  @override
  Future<void> clean(CleanupRule rule, {bool dryRun = false}) =>
      _ds.clean(rule, dryRun: dryRun);

  @override
  Future<DiskStats> diskStats(
          {void Function(double progress, String? path)? onProgress}) =>
      _ds.diskStats(onProgress: onProgress);

  @override
  Future<int> diskFreeBytes() => _ds.diskFreeBytes();

  @override
  Future<int> trashSizeBytes() => _ds.trashSizeBytes();

  @override
  Future<void> emptyTrash() => _ds.emptyTrash();
}
