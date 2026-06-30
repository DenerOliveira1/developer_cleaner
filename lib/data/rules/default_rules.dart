/// The initial rule registry (spec §6 / design `ruleMeta`). Defined as
/// `kRules` in the engine; re-exported here so the data layer owns the
/// "registry" concept and new rules are added in one obvious place.
library;

export 'package:developer_cleaner/core/cleaner/disk_cleaner_engine.dart'
    show kRules;
