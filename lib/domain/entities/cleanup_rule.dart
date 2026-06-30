/// Domain re-export of the pure cleaning types defined in the engine layer
/// (spec §5 — "re-export/align in the domain layer"). The domain never sees
/// `dart:io` because [clean_models] has no IO imports.
library;

export 'package:developer_cleaner/core/cleaner/clean_models.dart'
    show
        Safety,
        CleanAction,
        TrashPaths,
        RunCommand,
        KeepLatest,
        CleanupRule,
        CleanerException,
        CleanerErrorCode;
