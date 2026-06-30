import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('pt'),
  ];

  /// No description provided for @breakdown.
  ///
  /// In en, this message translates to:
  /// **'Disk breakdown'**
  String get breakdown;

  /// No description provided for @readingDisk.
  ///
  /// In en, this message translates to:
  /// **'Reading disk…'**
  String get readingDisk;

  /// No description provided for @used.
  ///
  /// In en, this message translates to:
  /// **'USED'**
  String get used;

  /// No description provided for @diskSub.
  ///
  /// In en, this message translates to:
  /// **'{free} free · {total} total'**
  String diskSub(String free, String total);

  /// No description provided for @reclaimRest.
  ///
  /// In en, this message translates to:
  /// **'reclaimable from developer junk'**
  String get reclaimRest;

  /// No description provided for @scan.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get scan;

  /// No description provided for @reversible.
  ///
  /// In en, this message translates to:
  /// **'Items move to the Trash — you can put them back.'**
  String get reversible;

  /// No description provided for @scanning.
  ///
  /// In en, this message translates to:
  /// **'SCANNING'**
  String get scanning;

  /// No description provided for @reading.
  ///
  /// In en, this message translates to:
  /// **'Reading {rule}…'**
  String reading(String rule);

  /// No description provided for @cleanup.
  ///
  /// In en, this message translates to:
  /// **'Cleanup'**
  String get cleanup;

  /// No description provided for @selected.
  ///
  /// In en, this message translates to:
  /// **'selected'**
  String get selected;

  /// No description provided for @cleanSelected.
  ///
  /// In en, this message translates to:
  /// **'Clean selected'**
  String get cleanSelected;

  /// No description provided for @nothing.
  ///
  /// In en, this message translates to:
  /// **'Nothing to clean here.'**
  String get nothing;

  /// No description provided for @cleaning.
  ///
  /// In en, this message translates to:
  /// **'CLEANING'**
  String get cleaning;

  /// No description provided for @stepOf.
  ///
  /// In en, this message translates to:
  /// **'of'**
  String get stepOf;

  /// No description provided for @freeNow.
  ///
  /// In en, this message translates to:
  /// **'FREE NOW'**
  String get freeNow;

  /// No description provided for @returnedReal.
  ///
  /// In en, this message translates to:
  /// **'+{freed} returned to disk'**
  String returnedReal(String freed);

  /// No description provided for @complete.
  ///
  /// In en, this message translates to:
  /// **'CLEANUP COMPLETE'**
  String get complete;

  /// No description provided for @reclaimable.
  ///
  /// In en, this message translates to:
  /// **'reclaimable'**
  String get reclaimable;

  /// No description provided for @freed.
  ///
  /// In en, this message translates to:
  /// **'freed'**
  String get freed;

  /// No description provided for @waiting.
  ///
  /// In en, this message translates to:
  /// **'waiting in Trash'**
  String get waiting;

  /// No description provided for @trashEmptiedLbl.
  ///
  /// In en, this message translates to:
  /// **'Trash emptied'**
  String get trashEmptiedLbl;

  /// No description provided for @emptyCta.
  ///
  /// In en, this message translates to:
  /// **'Empty Trash to free it for good'**
  String get emptyCta;

  /// No description provided for @emptying.
  ///
  /// In en, this message translates to:
  /// **'Emptying the Trash…'**
  String get emptying;

  /// No description provided for @trashEmpty.
  ///
  /// In en, this message translates to:
  /// **'Trash is empty'**
  String get trashEmpty;

  /// No description provided for @recoverNote.
  ///
  /// In en, this message translates to:
  /// **'Trashed items are recoverable until you empty the Trash.'**
  String get recoverNote;

  /// No description provided for @removeTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}?'**
  String removeTitle(String name);

  /// No description provided for @reviewed.
  ///
  /// In en, this message translates to:
  /// **'I reviewed the items above.'**
  String get reviewed;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @moveTrash.
  ///
  /// In en, this message translates to:
  /// **'Move {size} to Trash'**
  String moveTrash(String size);

  /// No description provided for @removePermanently.
  ///
  /// In en, this message translates to:
  /// **'Remove permanently'**
  String get removePermanently;

  /// No description provided for @permanentWarning.
  ///
  /// In en, this message translates to:
  /// **'Permanent — does not go to the Trash.'**
  String get permanentWarning;

  /// No description provided for @keeps.
  ///
  /// In en, this message translates to:
  /// **'Keeps {version}'**
  String keeps(String version);

  /// No description provided for @eTitle.
  ///
  /// In en, this message translates to:
  /// **'Empty Trash?'**
  String get eTitle;

  /// No description provided for @eBody1.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes '**
  String get eBody1;

  /// No description provided for @eBody2.
  ///
  /// In en, this message translates to:
  /// **' of trashed items. This is the one step that '**
  String get eBody2;

  /// No description provided for @eCant.
  ///
  /// In en, this message translates to:
  /// **'cannot be undone'**
  String get eCant;

  /// No description provided for @eBody3.
  ///
  /// In en, this message translates to:
  /// **' — everything before it was recoverable.'**
  String get eBody3;

  /// No description provided for @keepTrash.
  ///
  /// In en, this message translates to:
  /// **'Keep in Trash'**
  String get keepTrash;

  /// No description provided for @emptyTrash.
  ///
  /// In en, this message translates to:
  /// **'Empty Trash'**
  String get emptyTrash;

  /// No description provided for @genericError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong.'**
  String get genericError;

  /// No description provided for @scanAgain.
  ///
  /// In en, this message translates to:
  /// **'Scan again'**
  String get scanAgain;

  /// No description provided for @cleanFailures.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 rule could not be cleaned} other{{count} rules could not be cleaned}}'**
  String cleanFailures(int count);

  /// No description provided for @badge.
  ///
  /// In en, this message translates to:
  /// **'{safety, select, safe{SAFE} confirm{CONFIRM} danger{DANGER} other{}}'**
  String badge(String safety);

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'{key, select, xcode{Xcode / Simulators} caches{Caches} androidSdk{Android SDK} appSupport{App Support (IDEs)} free{Free} other{Other / System}}'**
  String category(String key);

  /// No description provided for @ruleName.
  ///
  /// In en, this message translates to:
  /// **'{ruleId, select, derived{Xcode DerivedData} simun{Unavailable simulators} coresim{CoreSimulator caches} gradle{Gradle caches} brew{Homebrew cleanup} intellij{IntelliJ — old versions} studio{Android Studio — old versions} ndk{Android NDK — old versions} docker{Docker — prune (no volumes)} simruntime{iOS Simulator — old runtimes} flutter{Flutter — build/.dart_tool} react{React Native — node_modules/Pods/build} web{React / Next.js — node_modules/.next} php{PHP — vendor (Composer)} other{}}'**
  String ruleName(String ruleId);

  /// No description provided for @ruleDesc.
  ///
  /// In en, this message translates to:
  /// **'{ruleId, select, derived{Build intermediates Xcode regenerates on the next build.} simun{Simulator runtimes no longer supported by your Xcode.} coresim{Cached simulator data and device snapshots.} gradle{Downloaded dependencies Gradle re-fetches as needed.} brew{Old downloads and stale formula versions.} intellij{Caches and plugins from IDE versions you no longer run.} studio{Caches from Android Studio releases you have replaced.} ndk{The right NDK depends on your projects’ ndkVersion. Review before removing.} docker{Dangling images and stopped build layers. Named volumes are left untouched.} simruntime{Keeps only the latest iOS; removes old simulator runtimes. Irreversible.} flutter{build/ and .dart_tool/ from all your Flutter projects (regenerated on the next build).} react{node_modules, Pods and build outputs from your React Native projects (recreated with install/build).} web{node_modules and web build output (.next, build, dist, out) from React/Next projects.} php{Composer dependencies (vendor/) from PHP projects (recreated with composer install).} other{}}'**
  String ruleDesc(String ruleId);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
