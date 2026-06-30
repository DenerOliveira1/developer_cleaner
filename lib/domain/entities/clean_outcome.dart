/// Result of a cleanup run, split by reversibility for the Done/reveal screen.
class CleanOutcome {
  /// Space reclaimed immediately (command rules like brew/docker/simctl free
  /// space on disk right away) — measured as the `df` free-space delta.
  final int freedBytes;

  /// Bytes moved to the Trash — recoverable until the Trash is emptied.
  final int inTrashBytes;

  const CleanOutcome({required this.freedBytes, required this.inTrashBytes});

  /// Total reclaimable (freed now + waiting in Trash).
  int get totalBytes => freedBytes + inTrashBytes;
}
