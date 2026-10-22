import 'package:flutter/material.dart';

import 'kn_colors.dart';

/// Bundled in pubspec.yaml under assets/fonts.
const kFontFamily = 'Manrope';

/// Spacing scale, 4px base unit.
abstract final class Sp {
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 20;
  static const double s6 = 24;
  static const double s8 = 32;
  static const double s10 = 40;
  static const double s12 = 48;
  static const double s16 = 64;
  static const double s20 = 80;
  static const double s24 = 96;
}

abstract final class Rad {
  static const double sm = 4;
  static const double md = 8;
  static const double lg = 12;
  static const double xl = 16;
  static const double xxl = 24;
  static const double full = 999;
}

/// Builds Material ThemeData from Kinetic Noir tokens. Manrope throughout.
ThemeData knTheme(Brightness brightness) {
  final c = brightness == Brightness.dark ? KnColors.dark : KnColors.light;
  final base = ThemeData(brightness: brightness, useMaterial3: true, fontFamily: kFontFamily);
  final manrope = base.textTheme;

  TextStyle s(TextStyle? t, double size, FontWeight w, double height, [double? ls]) =>
      (t ?? const TextStyle()).copyWith(
        fontFamily: kFontFamily,
        fontSize: size,
        fontWeight: w,
        height: height / size,
        letterSpacing: ls,
        color: c.onSurface,
      );

  final text = TextTheme(
    displayLarge: s(manrope.displayLarge, 40, FontWeight.w800, 48, -0.8),
    displayMedium: s(manrope.displayMedium, 32, FontWeight.w800, 40, -0.64),
    displaySmall: s(manrope.displaySmall, 28, FontWeight.w700, 36, -0.56),
    headlineLarge: s(manrope.headlineLarge, 24, FontWeight.w700, 32, -0.24),
    headlineMedium: s(manrope.headlineMedium, 20, FontWeight.w700, 28),
    headlineSmall: s(manrope.headlineSmall, 18, FontWeight.w600, 26),
    titleLarge: s(manrope.titleLarge, 16, FontWeight.w600, 24),
    titleMedium: s(manrope.titleMedium, 14, FontWeight.w600, 20),
    titleSmall: s(manrope.titleSmall, 12, FontWeight.w600, 16),
    bodyLarge: s(manrope.bodyLarge, 16, FontWeight.w400, 26),
    bodyMedium: s(manrope.bodyMedium, 14, FontWeight.w400, 22),
    bodySmall: s(manrope.bodySmall, 12, FontWeight.w400, 18),
    labelLarge: s(manrope.labelLarge, 14, FontWeight.w500, 20, 0.1),
    labelMedium: s(manrope.labelMedium, 12, FontWeight.w500, 16, 0.3),
    labelSmall: s(manrope.labelSmall, 10, FontWeight.w500, 14, 0.4),
  );

  final scheme = ColorScheme(
    brightness: brightness,
    primary: c.primary,
    onPrimary: c.onPrimary,
    primaryContainer: c.primaryContainer,
    onPrimaryContainer: c.onPrimaryContainer,
    secondary: c.primaryDim,
    onSecondary: c.onPrimary,
    tertiary: c.tertiary,
    onTertiary: c.onTertiary,
    tertiaryContainer: c.tertiaryContainer,
    onTertiaryContainer: c.onTertiaryContainer,
    error: c.error,
    onError: c.onError,
    errorContainer: c.errorContainer,
    onErrorContainer: c.onErrorContainer,
    surface: c.surface,
    onSurface: c.onSurface,
    onSurfaceVariant: c.onSurfaceVariant,
    surfaceContainerLowest: c.surfaceLowest,
    surfaceContainerLow: c.surfaceLow,
    surfaceContainer: c.surfaceContainer,
    surfaceContainerHigh: c.surfaceHigh,
    surfaceContainerHighest: c.surfaceHighest,
    outline: c.outline,
    outlineVariant: c.ghostBorder,
  );

  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: c.surface,
    canvasColor: c.surface,
    textTheme: text,
    extensions: [c],
    appBarTheme: AppBarTheme(
      backgroundColor: c.surface,
      foregroundColor: c.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.headlineSmall,
    ),
    cardTheme: CardThemeData(
      color: c.surfaceHighest,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rad.xl)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surfaceContainer,
      modalBackgroundColor: c.surfaceContainer,
      showDragHandle: true,
      dragHandleColor: c.outline,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Rad.xxl)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surfaceHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rad.xl)),
      titleTextStyle: text.headlineSmall,
      contentTextStyle: text.bodyMedium?.copyWith(color: c.onSurfaceVariant),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surfaceHigh,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Rad.lg),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Rad.lg),
        borderSide: BorderSide(color: c.ghostBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Rad.lg),
        borderSide: BorderSide(color: c.primary, width: 1.5),
      ),
      labelStyle: text.labelLarge?.copyWith(color: c.onSurfaceVariant),
      hintStyle: text.bodyMedium?.copyWith(color: c.onSurfaceDisabled),
      contentPadding: const EdgeInsets.symmetric(horizontal: Sp.s4, vertical: Sp.s3),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: c.surfaceHigh,
      selectedColor: c.primaryContainer,
      labelStyle: text.labelLarge,
      side: BorderSide(color: c.ghostBorder),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rad.full)),
      padding: const EdgeInsets.symmetric(horizontal: Sp.s3, vertical: Sp.s2),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.primary,
        foregroundColor: c.onPrimary,
        minimumSize: const Size(64, 52),
        textStyle: text.titleLarge,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rad.lg)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.onSurface,
        minimumSize: const Size(64, 52),
        textStyle: text.titleLarge,
        side: BorderSide(color: c.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rad.lg)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: c.primary, textStyle: text.labelLarge),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: c.tertiary,
      foregroundColor: c.onTertiary,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rad.xl)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.surfaceLow,
      indicatorColor: c.primaryContainer,
      labelTextStyle: WidgetStatePropertyAll(text.labelMedium),
      iconTheme: WidgetStatePropertyAll(IconThemeData(color: c.onSurfaceVariant)),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: c.onSurfaceVariant,
      textColor: c.onSurface,
      titleTextStyle: text.titleMedium,
      subtitleTextStyle: text.bodySmall?.copyWith(color: c.onSurfaceVariant),
    ),
    dividerTheme: DividerThemeData(color: c.ghostBorder, thickness: 1, space: 1),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStatePropertyAll(c.onPrimary),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? c.primary : c.outline,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.surfaceHighest,
      contentTextStyle: text.bodyMedium,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rad.lg)),
    ),
  );
}
