/// Pure data types shared by the cleaner engine and the domain layer.
///
/// This file intentionally has **no** `dart:io` / Flutter imports so the
/// domain layer can re-export it without learning about processes or the
/// filesystem.
library;

/// Risk level of a cleanup rule. Drives the UI badge and the confirm gates.
enum Safety { safe, confirm, danger }

/// What a rule does when executed. Sealed so the engine can exhaustively
/// switch over every variant.
sealed class CleanAction {
  const CleanAction();
}

/// Move paths to the Trash (reversible). When [contentsOnly] is true the
/// directory itself is kept and each child entry is trashed instead.
class TrashPaths extends CleanAction {
  final List<String> paths;
  final bool contentsOnly;
  const TrashPaths(this.paths, {this.contentsOnly = false});
}

/// Run an external command (e.g. `xcrun`, `docker`, `brew`). Always a list of
/// arguments — never a shell string — to avoid injection.
class RunCommand extends CleanAction {
  final String executable;
  final List<String> args;
  const RunCommand(this.executable, this.args);
}

/// Keep the [keep] newest entries (by mtime) under [parentDir] (optionally
/// filtered by [namePrefix]) and trash the rest.
class KeepLatest extends CleanAction {
  final String parentDir;
  final String? namePrefix;
  final int keep;
  const KeepLatest(this.parentDir, {this.namePrefix, this.keep = 1});
}

/// Keep the [keep] newest iOS simulator runtimes (by version) and permanently
/// delete the rest via `simctl runtime delete`. **Irreversible** — runtimes
/// don't go to the Trash.
class DeleteSimRuntimes extends CleanAction {
  final int keep;
  const DeleteSimRuntimes({this.keep = 1});
}

/// Discover projects under [roots] — a project is a dir containing
/// [markerFile] whose content matches [markerPattern] — and trash each one's
/// recreatable [artifactDirs] (relative paths, may be nested like `ios/Pods`).
/// Reversible (Trash). Powers both Flutter and React Native rules.
class ProjectArtifacts extends CleanAction {
  final List<String> roots;
  final String markerFile; // e.g. 'pubspec.yaml' | 'package.json'
  final String markerPattern; // regex validating the marker's content
  final List<String> artifactDirs; // relative dirs to trash
  final int maxDepth;
  const ProjectArtifacts({
    required this.roots,
    required this.markerFile,
    required this.markerPattern,
    required this.artifactDirs,
    this.maxDepth = 4,
  });
}

/// Whether a rule's effect can be undone. File moves (Trash) are reversible;
/// external commands (`simctl`/`docker`/`brew`) and runtime deletions are not.
bool isReversibleAction(CleanAction action) =>
    action is TrashPaths || action is KeepLatest || action is ProjectArtifacts;

/// A declarative cleanup rule. [label]/[description] are defaults for the CLI
/// and debugging; the UI overrides them per-language via the i18n dictionary
/// keyed by [id].
class CleanupRule {
  final String id;
  final String label;
  final String description;
  final Safety safety;
  final CleanAction action;
  const CleanupRule({
    required this.id,
    required this.label,
    required this.description,
    required this.safety,
    required this.action,
  });
}

/// Result of scanning a single rule.
class ScanResult {
  final CleanupRule rule;

  /// Reclaimable bytes, or `null` when unknown (command rules can't be sized
  /// before running).
  final int? bytes;

  /// Paths that will be affected — shown as the expand preview.
  final List<String> targets;

  /// For [KeepLatest] rules: the human-readable note about what is kept.
  final String? keepNote;

  const ScanResult({
    required this.rule,
    required this.bytes,
    required this.targets,
    this.keepNote,
  });
}

/// One slice of the disk-usage breakdown (for the gauge). [key] is a stable
/// identifier the UI maps to a localized name and color.
class DiskCategory {
  final String key;
  final int bytes;
  const DiskCategory(this.key, this.bytes);
}

/// Whole-disk stats plus the per-category breakdown.
class DiskStats {
  final int totalBytes;
  final int freeBytes;
  final List<DiskCategory> categories;
  const DiskStats({
    required this.totalBytes,
    required this.freeBytes,
    required this.categories,
  });

  int get usedBytes => totalBytes - freeBytes;
}

/// Identifies an engine failure so the presentation layer can localize it. The
/// engine stays Flutter-free and carries no user-facing text — only the code
/// plus a raw [CleanerException.detail] (path/stderr) for diagnostics.
enum CleanerErrorCode { trashMove, emptyTrash, removeRuntime, runCommand }

/// Raised when a cleaning operation fails. Localized at the UI boundary by
/// mapping [code] to an ARB string; [detail] is the raw, non-localized
/// diagnostic (offending path / command stderr).
class CleanerException implements Exception {
  final CleanerErrorCode code;
  final String? detail;
  const CleanerException(this.code, {this.detail});
  @override
  String toString() => detail == null ? code.name : '${code.name} — $detail';
}
