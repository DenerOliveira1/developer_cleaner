import 'package:flutter/widgets.dart';

/// Design tokens (dark theme) copied from the DevDisk hi-fi spec.
abstract final class AppColors {
  // Surfaces.
  static const pageTop = Color(0xFF131218);
  static const pageMid = Color(0xFF0C0B0F);
  static const pageBottom = Color(0xFF090809);
  static const window = Color(0xFF161419);
  static const raised = Color(0xFF1C1A23);
  static const raisedAlt = Color(0xFF1A1822);
  static const raisedModal = Color(0xFF1B1922);
  static const sunken = Color(0xFF121116);
  static const gaugeTrack = Color(0xFF211E2A);
  static const toggleActive = Color(0xFF33303D); // active PT|EN segment

  // Borders.
  static const border = Color(0xFF2A2733);
  static const divider = Color(0xFF211E29);
  static const borderModal = Color(0xFF322833);
  static const borderActive = Color(0xFF2E2A38);
  static const borderPreview = Color(0xFF221F2A);
  static const borderControl = Color(0xFF3A3743); // checkbox outline, minor gauge ticks

  // Overlays (modal scrim + shadow).
  static const scrim = Color(0xA8070609);
  static const modalShadow = Color(0xCC000000);

  // Ink (light → faint).
  static const heroInk = Color(0xFFF4F1EA);
  static const heroInk2 = Color(0xFFF2EEE7);
  static const baseInk = Color(0xFFECE8E1);
  static const rowName = Color(0xFFE7E2DC);
  static const secondary = Color(0xFFC7C2CC);
  static const bodyDim = Color(0xFFA39EAA);
  static const monoDim = Color(0xFF9A95A2);
  static const faint = Color(0xFF8B8693);
  static const faint2 = Color(0xFF7E7989);
  static const faintest = Color(0xFF6F6A78);
  static const faintest2 = Color(0xFF5A5563);
  static const faintest3 = Color(0xFF4D4956);

  // Accent (steel blue).
  static const accentLight = Color(0xFF7AAAE0);
  static const accentDark = Color(0xFF5E8BC9);
  static const accent = Color(0xFF6FA0D9);
  static const accentMono = Color(0xFF9CC0EA);
  static const accentDeep = Color(0xFF3E5E86);
  static const onAccent = Color(0xFF0E1622); // ink/icon on accent or bright fills
  static const accentGradient =
      LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [accentLight, accentDark]);

  // Risk semantics.
  static const safe = Color(0xFF74BE96);
  static const confirm = Color(0xFFE0B262);
  static const danger = Color(0xFFE58379);
  static const dangerBright = Color(0xFFEC9085);

  // Category colors (gauge breakdown), keyed by DiskCategory.key.
  static const catXcode = Color(0xFF5C8AC9);
  static const catCaches = Color(0xFF4FA39A);
  static const catAndroid = Color(0xFF7FA85A);
  static const catAppSupport = Color(0xFFC8924E);
  static const catOther = Color(0xFF5A5764);
  static const catFree = Color(0xFF34313D);

  // Traffic lights.
  static const tlRed = Color(0xFFED6A5E);
  static const tlYellow = Color(0xFFF4BE4F);
  static const tlGreen = Color(0xFF61C554);

  static const pageGradient = RadialGradient(
    center: Alignment(0, -1.1),
    radius: 1.2,
    colors: [pageTop, pageMid, pageBottom],
    stops: [0, 0.6, 1],
  );

  /// Maps a [DiskCategory] key to its legend color.
  static Color category(String key) => switch (key) {
        'xcode' => catXcode,
        'caches' => catCaches,
        'androidSdk' => catAndroid,
        'appSupport' => catAppSupport,
        'other' => catOther,
        'free' => catFree,
        _ => catOther,
      };
}
