import 'dart:io';

/// Injectable boundary around external process execution.
///
/// Abstracted so tests can fake `du`/`osascript`/`docker`/`brew` without
/// touching the real system (spec §10).
abstract class ProcessRunner {
  Future<ProcessResult> run(String executable, List<String> args);
}

/// Default implementation backed by [Process.run]. Never uses `sh -c` — the
/// executable and its arguments are passed as a list (spec §3.3 / §9.4).
class SystemProcessRunner implements ProcessRunner {
  const SystemProcessRunner();

  @override
  Future<ProcessResult> run(String executable, List<String> args) =>
      Process.run(executable, args);
}
