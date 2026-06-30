// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get breakdown => 'Disk breakdown';

  @override
  String get used => 'USED';

  @override
  String diskSub(String free, String total) {
    return '$free free · $total total';
  }

  @override
  String get reclaimRest => 'reclaimable from developer junk';

  @override
  String get scan => 'Scan';

  @override
  String get reversible => 'Items move to the Trash — you can put them back.';

  @override
  String get scanning => 'SCANNING';

  @override
  String reading(String rule) {
    return 'Reading $rule…';
  }

  @override
  String get cleanup => 'Cleanup';

  @override
  String get selected => 'selected';

  @override
  String get cleanSelected => 'Clean selected';

  @override
  String get nothing => 'Nothing to clean here.';

  @override
  String get cleaning => 'CLEANING';

  @override
  String get stepOf => 'of';

  @override
  String get freeNow => 'FREE NOW';

  @override
  String returnedReal(String freed) {
    return '+$freed returned to disk';
  }

  @override
  String get complete => 'CLEANUP COMPLETE';

  @override
  String get reclaimable => 'reclaimable';

  @override
  String get freed => 'freed';

  @override
  String get waiting => 'waiting in Trash';

  @override
  String get trashEmptiedLbl => 'Trash emptied';

  @override
  String get emptyCta => 'Empty Trash to free it for good';

  @override
  String get trashEmpty => 'Trash is empty';

  @override
  String get recoverNote =>
      'Trashed items are recoverable until you empty the Trash.';

  @override
  String removeTitle(String name) {
    return 'Remove $name?';
  }

  @override
  String get reviewed => 'I reviewed the items above.';

  @override
  String get cancel => 'Cancel';

  @override
  String moveTrash(String size) {
    return 'Move $size to Trash';
  }

  @override
  String get removePermanently => 'Remove permanently';

  @override
  String get permanentWarning => 'Permanent — does not go to the Trash.';

  @override
  String keeps(String version) {
    return 'Keeps $version';
  }

  @override
  String get eTitle => 'Empty Trash?';

  @override
  String get eBody1 => 'This permanently deletes ';

  @override
  String get eBody2 => ' of trashed items. This is the one step that ';

  @override
  String get eCant => 'cannot be undone';

  @override
  String get eBody3 => ' — everything before it was recoverable.';

  @override
  String get keepTrash => 'Keep in Trash';

  @override
  String get emptyTrash => 'Empty Trash';

  @override
  String get genericError => 'Something went wrong.';

  @override
  String get scanAgain => 'Scan again';

  @override
  String cleanFailures(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rules could not be cleaned',
      one: '1 rule could not be cleaned',
    );
    return '$_temp0';
  }

  @override
  String badge(String safety) {
    String _temp0 = intl.Intl.selectLogic(safety, {
      'safe': 'SAFE',
      'confirm': 'CONFIRM',
      'danger': 'DANGER',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String category(String key) {
    String _temp0 = intl.Intl.selectLogic(key, {
      'xcode': 'Xcode / Simulators',
      'caches': 'Caches',
      'androidSdk': 'Android SDK',
      'appSupport': 'App Support (IDEs)',
      'free': 'Free',
      'other': 'Other / System',
    });
    return '$_temp0';
  }

  @override
  String ruleName(String ruleId) {
    String _temp0 = intl.Intl.selectLogic(ruleId, {
      'derived': 'Xcode DerivedData',
      'simun': 'Unavailable simulators',
      'coresim': 'CoreSimulator caches',
      'gradle': 'Gradle caches',
      'brew': 'Homebrew cleanup',
      'intellij': 'IntelliJ — old versions',
      'studio': 'Android Studio — old versions',
      'ndk': 'Android NDK — old versions',
      'docker': 'Docker — prune (no volumes)',
      'simruntime': 'iOS Simulator — old runtimes',
      'flutter': 'Flutter — build/.dart_tool',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String ruleDesc(String ruleId) {
    String _temp0 = intl.Intl.selectLogic(ruleId, {
      'derived': 'Build intermediates Xcode regenerates on the next build.',
      'simun': 'Simulator runtimes no longer supported by your Xcode.',
      'coresim': 'Cached simulator data and device snapshots.',
      'gradle': 'Downloaded dependencies Gradle re-fetches as needed.',
      'brew': 'Old downloads and stale formula versions.',
      'intellij': 'Caches and plugins from IDE versions you no longer run.',
      'studio': 'Caches from Android Studio releases you have replaced.',
      'ndk':
          'The right NDK depends on your projects’ ndkVersion. Review before removing.',
      'docker':
          'Dangling images and stopped build layers. Named volumes are left untouched.',
      'simruntime':
          'Keeps only the latest iOS; removes old simulator runtimes. Irreversible.',
      'flutter':
          'build/ and .dart_tool/ from all your Flutter projects (regenerated on the next build).',
      'other': '',
    });
    return '$_temp0';
  }
}
