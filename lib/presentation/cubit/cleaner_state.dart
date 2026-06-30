import 'package:equatable/equatable.dart';

import '../../core/cleaner/clean_models.dart';
import '../../domain/entities/clean_outcome.dart';
import '../../domain/usecases/clean_rules.dart';
import '../l10n/app_lang.dart';

/// The screen the app is currently showing (maps to the prototype's `screen`).
enum CleanerPhase { idle, scanning, results, cleaning, done, error }

/// A scanned rule is actionable when it has something to clean: a command
/// (size unknown) or a non-empty target list with a positive size.
bool isResultActionable(ScanResult r) =>
    r.targets.isNotEmpty && (r.bytes == null || r.bytes! > 0);

const Object _undef = Object();

/// Single immutable state for the whole flow. Equatable so the UI only rebuilds
/// on real changes; a [CleanerPhase] enum replaces per-screen sealed classes.
class CleanerState extends Equatable {
  final CleanerPhase phase;
  final AppLang lang;
  final DiskStats? disk;
  final List<ScanResult> results;
  final Set<String> selectedRuleIds;
  final String? expandedId;

  // Idle disk-stats loading progress (the `df` + `du` breakdown on startup).
  final double diskProgress; // 0..1
  final String? diskScanPath; // path currently being measured

  // Scanning progress.
  final double scanProgress; // 0..1
  final String? scanningRuleId;

  // Cleaning progress.
  final int cleanIndex;
  final int cleanTotal;
  final String? cleaningRuleId;

  // Empty-Trash progress (stays on the Done screen — only the CTA swaps for a
  // progress bar). [emptyTrashProgress] is the observed fraction removed, 0..1.
  final bool emptyingTrash;
  final double emptyTrashProgress;

  // Flow gates / outcome.
  final bool dangerConfirmed;
  final bool trashEmptied;
  final CleanOutcome? outcome;
  final List<CleanFailure> failures;
  final String? error;

  const CleanerState({
    this.phase = CleanerPhase.idle,
    this.lang = AppLang.pt,
    this.disk,
    this.results = const [],
    this.selectedRuleIds = const {},
    this.expandedId,
    this.diskProgress = 0,
    this.diskScanPath,
    this.scanProgress = 0,
    this.scanningRuleId,
    this.cleanIndex = 0,
    this.cleanTotal = 0,
    this.cleaningRuleId,
    this.emptyingTrash = false,
    this.emptyTrashProgress = 0,
    this.dangerConfirmed = false,
    this.trashEmptied = false,
    this.outcome,
    this.failures = const [],
    this.error,
  });

  ScanResult? resultFor(String id) {
    for (final r in results) {
      if (r.rule.id == id) return r;
    }
    return null;
  }

  bool isActionable(String id) {
    final r = resultFor(id);
    return r != null && isResultActionable(r);
  }

  bool isSelected(String id) => selectedRuleIds.contains(id);

  /// Sum of known reclaimable bytes across selected rules.
  int get selectedReclaimableBytes {
    var sum = 0;
    for (final r in results) {
      if (selectedRuleIds.contains(r.rule.id) && r.bytes != null) {
        sum += r.bytes!;
      }
    }
    return sum;
  }

  /// True when a `danger` rule is selected and not yet confirmed — the
  /// "Clean selected" action must route through the danger modal first.
  bool get hasUnconfirmedDanger =>
      !dangerConfirmed &&
      results.any((r) =>
          r.rule.safety == Safety.danger && selectedRuleIds.contains(r.rule.id));

  CleanerState copyWith({
    CleanerPhase? phase,
    AppLang? lang,
    DiskStats? disk,
    List<ScanResult>? results,
    Set<String>? selectedRuleIds,
    Object? expandedId = _undef,
    double? diskProgress,
    Object? diskScanPath = _undef,
    double? scanProgress,
    String? scanningRuleId,
    int? cleanIndex,
    int? cleanTotal,
    String? cleaningRuleId,
    bool? emptyingTrash,
    double? emptyTrashProgress,
    bool? dangerConfirmed,
    bool? trashEmptied,
    CleanOutcome? outcome,
    List<CleanFailure>? failures,
    Object? error = _undef,
  }) {
    return CleanerState(
      phase: phase ?? this.phase,
      lang: lang ?? this.lang,
      disk: disk ?? this.disk,
      results: results ?? this.results,
      selectedRuleIds: selectedRuleIds ?? this.selectedRuleIds,
      expandedId:
          identical(expandedId, _undef) ? this.expandedId : expandedId as String?,
      diskProgress: diskProgress ?? this.diskProgress,
      diskScanPath: identical(diskScanPath, _undef)
          ? this.diskScanPath
          : diskScanPath as String?,
      scanProgress: scanProgress ?? this.scanProgress,
      scanningRuleId: scanningRuleId ?? this.scanningRuleId,
      cleanIndex: cleanIndex ?? this.cleanIndex,
      cleanTotal: cleanTotal ?? this.cleanTotal,
      cleaningRuleId: cleaningRuleId ?? this.cleaningRuleId,
      emptyingTrash: emptyingTrash ?? this.emptyingTrash,
      emptyTrashProgress: emptyTrashProgress ?? this.emptyTrashProgress,
      dangerConfirmed: dangerConfirmed ?? this.dangerConfirmed,
      trashEmptied: trashEmptied ?? this.trashEmptied,
      outcome: outcome ?? this.outcome,
      failures: failures ?? this.failures,
      error: identical(error, _undef) ? this.error : error as String?,
    );
  }

  @override
  List<Object?> get props => [
        phase,
        lang,
        disk,
        results,
        selectedRuleIds,
        expandedId,
        diskProgress,
        diskScanPath,
        scanProgress,
        scanningRuleId,
        cleanIndex,
        cleanTotal,
        cleaningRuleId,
        emptyingTrash,
        emptyTrashProgress,
        dangerConfirmed,
        trashEmptied,
        outcome,
        failures,
        error,
      ];
}
