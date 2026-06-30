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

  CleanerCubit({
    required ScanRules scanRules,
    required CleanRules cleanRules,
    required CleanerRepository repository,
    List<CleanupRule>? rules,
  })  : _scanRules = scanRules,
        _cleanRules = cleanRules,
        _repository = repository,
        _rules = rules ?? kRules,
        super(const CleanerState());

  /// Loads the disk gauge on the Idle screen.
  Future<void> init() async {
    try {
      final disk = await _repository.diskStats();
      emit(state.copyWith(disk: disk));
    } catch (e) {
      emit(state.copyWith(phase: CleanerPhase.error, error: e.toString()));
    }
  }

  void setLang(AppLang lang) => emit(state.copyWith(lang: lang));

  /// Scans every rule (concurrently) and refreshes disk stats, then lands on
  /// Results with the default selection (safe + actionable checked).
  Future<void> scanAll() async {
    emit(state.copyWith(
        phase: CleanerPhase.scanning, scanProgress: 0, error: null));
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
      emit(state.copyWith(phase: CleanerPhase.error, error: e.toString()));
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
  Future<void> emptyTrash() async {
    try {
      await _repository.emptyTrash();
      emit(state.copyWith(trashEmptied: true));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }
}
