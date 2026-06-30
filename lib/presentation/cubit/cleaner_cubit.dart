import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/cleaner/disk_cleaner_engine.dart';
import '../../domain/entities/clean_outcome.dart';
import '../../domain/repositories/cleaner_repository.dart';
import '../../domain/usecases/clean_rules.dart';
import '../../domain/usecases/scan_rules.dart';
import '../l10n/app_lang.dart';
import 'cleaner_state.dart';

/// Drives the whole flow: load disk → scan → select → clean → reveal.
class CleanerCubit extends Cubit<CleanerState> {
  final ScanRules _scanRules;
  final CleanRules _cleanRules;
  final CleanerRepository _repository;
  final List<CleanupRule> _rules;

  /// How often the Trash size is re-measured while emptying, to update the
  /// progress. Injectable so tests can drive it without real-time waits.
  final Duration _emptyTrashPollInterval;

  CleanerCubit({
    required ScanRules scanRules,
    required CleanRules cleanRules,
    required CleanerRepository repository,
    List<CleanupRule>? rules,
    Duration emptyTrashPollInterval = const Duration(milliseconds: 350),
  })  : _scanRules = scanRules,
        _cleanRules = cleanRules,
        _repository = repository,
        _rules = rules ?? kRules,
        _emptyTrashPollInterval = emptyTrashPollInterval,
        super(const CleanerState());

  /// Loads the disk gauge on the Idle screen, reporting real progress while the
  /// `du` breakdown runs so the loading readout shows a percentage + the path
  /// being measured (instead of a bare spinner).
  Future<void> init() async {
    emit(state.copyWith(
        diskProgress: 0, diskScanPath: null, error: null, errorCode: null));
    try {
      final disk = await _repository.diskStats(
        onProgress: (p, path) =>
            emit(state.copyWith(diskProgress: p, diskScanPath: path)),
      );
      emit(state.copyWith(disk: disk, diskProgress: 1, diskScanPath: null));
    } catch (e) {
      final (code, detail) = _errParts(e);
      emit(state.copyWith(
          phase: CleanerPhase.error, error: detail, errorCode: code));
    }
  }

  /// Splits a caught error into (localizable code, raw detail). A
  /// [CleanerException] carries both; anything else is generic (null code).
  (CleanerErrorCode?, String) _errParts(Object e) => e is CleanerException
      ? (e.code, e.detail ?? '')
      : (null, e.toString());

  void setLang(AppLang lang) => emit(state.copyWith(lang: lang));

  /// Scans every rule (concurrently) and refreshes disk stats, then lands on
  /// Results with the default selection (safe + actionable checked).
  Future<void> scanAll() async {
    emit(state.copyWith(
        phase: CleanerPhase.scanning,
        scanProgress: 0,
        error: null,
        errorCode: null));
    try {
      final results = await _scanRules(
        _rules,
        onProgress: (i, rule) => emit(state.copyWith(
            scanningRuleId: rule.id, scanProgress: i / _rules.length)),
      );
      emit(state.copyWith(scanProgress: 1));

      // Disk stats were already loaded on Idle; only fetch if missing.
      final disk = state.disk ?? await _repository.diskStats();

      final selected = <String>{
        for (final r in results)
          if (r.rule.safety == Safety.safe && isResultActionable(r)) r.rule.id,
      };
      final expand = results.any(
              (r) => r.rule.id == 'ndk' && isResultActionable(r))
          ? 'ndk'
          : null;

      emit(state.copyWith(
        phase: CleanerPhase.results,
        results: results,
        disk: disk,
        selectedRuleIds: selected,
        expandedId: expand,
      ));
    } catch (e) {
      final (code, detail) = _errParts(e);
      emit(state.copyWith(
          phase: CleanerPhase.error, error: detail, errorCode: code));
    }
  }

  void toggleRule(String id) {
    if (!state.isActionable(id)) return;
    final next = Set<String>.from(state.selectedRuleIds);
    if (!next.remove(id)) next.add(id);
    emit(state.copyWith(selectedRuleIds: next));
  }

  /// Single-open accordion: tapping the open row collapses it.
  void expand(String id) =>
      emit(state.copyWith(expandedId: state.expandedId == id ? null : id));

  /// Records that the user re-read the danger warning. Once confirmed in a
  /// session, re-running Clean doesn't re-prompt.
  void confirmDanger() => emit(state.copyWith(dangerConfirmed: true));

  /// Cleans the selected rules in order, then reveals the outcome.
  ///
  /// [dryRun] performs no side effects and reports a zero outcome. Reveal
  /// split: `freed` = real `df` free-space delta (command rules free disk
  /// immediately); `inTrash` = bytes moved to the Trash (still on disk).
  Future<void> cleanSelected({bool dryRun = false}) async {
    final selected =
        _rules.where((r) => state.selectedRuleIds.contains(r.id)).toList();
    if (selected.isEmpty) return;

    final freeBefore = state.disk?.freeBytes ?? 0;
    emit(state.copyWith(
      phase: CleanerPhase.cleaning,
      cleanTotal: selected.length,
      cleanIndex: 0,
      cleaningRuleId: selected.first.id,
    ));

    final failures = await _cleanRules(
      selected,
      dryRun: dryRun,
      onProgress: (i, rule) =>
          emit(state.copyWith(cleanIndex: i, cleaningRuleId: rule.id)),
    );

    if (dryRun) {
      emit(state.copyWith(
        phase: CleanerPhase.done,
        outcome: const CleanOutcome(freedBytes: 0, inTrashBytes: 0),
        failures: failures,
      ));
      return;
    }

    // Reversible rules (TrashPaths/KeepLatest/FlutterArtifacts) move bytes to
    // the Trash — they don't free disk until it's emptied, so they count as
    // "waiting in Trash", not "freed".
    final inTrash = selected
        .where((r) => isReversibleAction(r.action))
        .fold<int>(0, (sum, r) => sum + (state.resultFor(r.id)?.bytes ?? 0));

    // Cheap `df` (no `du`) so the Cleaning→Done transition isn't blocked.
    var freeAfter = freeBefore;
    try {
      freeAfter = await _repository.diskFreeBytes();
    } catch (_) {
      // A failed free check shouldn't block the reveal.
    }
    final total = state.disk?.totalBytes ?? freeAfter;
    final freed = (freeAfter - freeBefore).clamp(0, total);

    emit(state.copyWith(
      phase: CleanerPhase.done,
      outcome: CleanOutcome(freedBytes: freed, inTrashBytes: inTrash),
      failures: failures,
    ));
  }

  /// Returns to Idle for another pass, preserving the chosen language and
  /// refreshing disk stats so the gauge reflects the space just reclaimed.
  Future<void> restart() async {
    emit(CleanerState(lang: state.lang));
    await init();
  }

  /// Empties the Trash — the one permanent action (behind the modal gate).
  ///
  /// Reports a real percentage: Finder's `empty trash` gives no progress, so we
  /// measure the Trash size up front, then poll it while the deletion runs and
  /// report the observed fraction removed. If the size can't be measured we
  /// fall back to an indeterminate run (no percentage) — the deletion still
  /// proceeds. Errors revert [emptyingTrash] so the CTA comes back.
  Future<void> emptyTrash() async {
    emit(state.copyWith(
        emptyingTrash: true,
        emptyTrashProgress: 0,
        error: null,
        errorCode: null));
    try {
      var initial = 0;
      try {
        initial = await _repository.trashSizeBytes();
      } catch (_) {
        initial = 0; // can't measure → empty without a percentage
      }

      var done = false;
      final op = _repository.emptyTrash().whenComplete(() => done = true);

      if (initial > 0) {
        while (!done) {
          await Future<void>.delayed(_emptyTrashPollInterval);
          if (done) break;
          try {
            final current = await _repository.trashSizeBytes();
            final progress = ((initial - current) / initial).clamp(0.0, 0.99);
            emit(state.copyWith(emptyTrashProgress: progress));
          } catch (_) {
            // A transient `du` failure shouldn't abort — keep waiting for op.
          }
        }
      }

      await op; // surface a Finder failure
      emit(state.copyWith(
          emptyingTrash: false, emptyTrashProgress: 1, trashEmptied: true));
    } catch (e) {
      final (code, detail) = _errParts(e);
      emit(state.copyWith(
          emptyingTrash: false, error: detail, errorCode: code));
    }
  }
}
