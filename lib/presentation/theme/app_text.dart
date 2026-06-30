import 'package:flutter/widgets.dart';

/// Typography helpers (spec §Typography — 3 roles). Space Grotesk and JetBrains
/// Mono are bundled as variable fonts, so weight is applied via [FontVariation]
/// on the `wght` axis (with [FontWeight] set too for metrics/fallback).
abstract final class AppText {
  static const _display = 'Space Grotesk';
  static const _mono = 'JetBrains Mono';

  static FontWeight _weight(double wght) {
    if (wght >= 700) return FontWeight.w700;
    if (wght >= 600) return FontWeight.w600;
    if (wght >= 500) return FontWeight.w500;
    return FontWeight.w400;
  }

  /// Display face — titles, readouts, the reveal hero number.
  static TextStyle space(
    double size, {
    double wght = 400,
    Color? color,
    double? letterSpacing,
    double? height,
  }) =>
      TextStyle(
        fontFamily: _display,
        fontSize: size,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
        fontWeight: _weight(wght),
        fontVariations: [FontVariation('wght', wght)],
      );

  /// Mono face — counters, percentages, paths, kickers, the language toggle.
  static TextStyle mono(
    double size, {
    double wght = 400,
    Color? color,
    double? letterSpacing,
    double? height,
  }) =>
      TextStyle(
        fontFamily: _mono,
        fontSize: size,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
        fontWeight: _weight(wght),
        fontVariations: [FontVariation('wght', wght)],
      );

  /// Body/UI — system stack (renders SF on macOS). Row names, descriptions.
  static TextStyle ui(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color? color,
    double? height,
  }) =>
      TextStyle(
        fontSize: size,
        color: color,
        height: height,
        fontWeight: weight,
      );
}
