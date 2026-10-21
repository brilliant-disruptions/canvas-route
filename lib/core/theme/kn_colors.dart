import 'package:flutter/material.dart';

/// Kinetic Noir color tokens, exposed as a ThemeExtension so widgets read
/// `context.kn` instead of hardcoding hex values.
@immutable
class KnColors extends ThemeExtension<KnColors> {
  const KnColors({
    required this.surface,
    required this.surfaceLowest,
    required this.surfaceLow,
    required this.surfaceContainer,
    required this.surfaceHigh,
    required this.surfaceHighest,
    required this.primary,
    required this.primaryDim,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.tertiary,
    required this.onTertiary,
    required this.tertiaryContainer,
    required this.onTertiaryContainer,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.onSurfaceDisabled,
    required this.outline,
    required this.ghostBorder,
    required this.glass,
    required this.error,
    required this.errorContainer,
    required this.onError,
    required this.onErrorContainer,
    required this.statusBacklog,
    required this.statusTodo,
    required this.statusDevelopment,
    required this.statusTesting,
    required this.statusFutureRelease,
    required this.statusDone,
    required this.pinDefault,
    required this.pinAdded,
    required this.pinManual,
    required this.pinVisited,
    required this.pinCurrent,
    required this.tierUnknown,
    required this.tierEmerging,
    required this.tierEstablished,
    required this.warning,
  });

  final Color surface;
  final Color surfaceLowest;
  final Color surfaceLow;
  final Color surfaceContainer;
  final Color surfaceHigh;
  final Color surfaceHighest;
  final Color primary;
  final Color primaryDim;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color tertiary;
  final Color onTertiary;
  final Color tertiaryContainer;
  final Color onTertiaryContainer;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color onSurfaceDisabled;
  final Color outline;
  final Color ghostBorder;
  final Color glass;
  final Color error;
  final Color errorContainer;
  final Color onError;
  final Color onErrorContainer;
  final Color statusBacklog;
  final Color statusTodo;
  final Color statusDevelopment;
  final Color statusTesting;
  final Color statusFutureRelease;
  final Color statusDone;
  final Color pinDefault;
  final Color pinAdded;
  final Color pinManual;
  final Color pinVisited;
  final Color pinCurrent;
  final Color tierUnknown;
  final Color tierEmerging;
  final Color tierEstablished;
  final Color warning;

  static const dark = KnColors(
    surface: Color(0xFF0E0E0E),
    surfaceLowest: Color(0xFF0B0B0B),
    surfaceLow: Color(0xFF131313),
    surfaceContainer: Color(0xFF1A1A1A),
    surfaceHigh: Color(0xFF20201F),
    surfaceHighest: Color(0xFF262626),
    primary: Color(0xFFA3A6FF),
    primaryDim: Color(0xFF6063EE),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFF2A2D6E),
    onPrimaryContainer: Color(0xFFC8CAFF),
    tertiary: Color(0xFFBCFF5F),
    onTertiary: Color(0xFF0E0E0E),
    tertiaryContainer: Color(0xFF2A3D14),
    onTertiaryContainer: Color(0xFFD6FF99),
    onSurface: Color(0xFFE6E1E5),
    onSurfaceVariant: Color(0xFFADAAAA),
    onSurfaceDisabled: Color(0xFF6C6C70),
    outline: Color(0xFF484847),
    ghostBorder: Color(0x33484847),
    glass: Color(0xB30E0E0E),
    error: Color(0xFFFF6E84),
    errorContainer: Color(0xFF3D1520),
    onError: Color(0xFFFFFFFF),
    onErrorContainer: Color(0xFFFFB3BE),
    statusBacklog: Color(0xFF6C6C70),
    statusTodo: Color(0xFF5B9BD5),
    statusDevelopment: Color(0xFFF0C040),
    statusTesting: Color(0xFFE87A3F),
    statusFutureRelease: Color(0xFFB07AE8),
    statusDone: Color(0xFF4ECF73),
    pinDefault: Color(0xFFADAAAA),
    pinAdded: Color(0xFFA3A6FF),
    pinManual: Color(0xFFBCFF5F),
    pinVisited: Color(0xFF6C6C70),
    pinCurrent: Color(0xFFA3A6FF),
    tierUnknown: Color(0xFF6C6C70),
    tierEmerging: Color(0xFFF0C040),
    tierEstablished: Color(0xFF4ECF73),
    warning: Color(0xFFF0C040),
  );

  static const light = KnColors(
    surface: Color(0xFFF5F5F5),
    surfaceLowest: Color(0xFFFFFFFF),
    surfaceLow: Color(0xFFF0F0F0),
    surfaceContainer: Color(0xFFEAEAEA),
    surfaceHigh: Color(0xFFE2E2E2),
    surfaceHighest: Color(0xFFDCDCDC),
    primary: Color(0xFF4A4DE0),
    primaryDim: Color(0xFF6063EE),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFDEE0FF),
    onPrimaryContainer: Color(0xFF1A1D5C),
    tertiary: Color(0xFF4A7A1A),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFC8F090),
    onTertiaryContainer: Color(0xFF1A3300),
    onSurface: Color(0xFF1C1B1F),
    onSurfaceVariant: Color(0xFF49454F),
    onSurfaceDisabled: Color(0xFF9E9E9E),
    outline: Color(0xFFC4C4C4),
    ghostBorder: Color(0x14000000),
    glass: Color(0xCCFFFFFF),
    error: Color(0xFFBA1A1A),
    errorContainer: Color(0xFFFFDAD6),
    onError: Color(0xFFFFFFFF),
    onErrorContainer: Color(0xFF410002),
    statusBacklog: Color(0xFF9E9E9E),
    statusTodo: Color(0xFF3A7AC0),
    statusDevelopment: Color(0xFFC09A10),
    statusTesting: Color(0xFFC0621A),
    statusFutureRelease: Color(0xFF8A50D0),
    statusDone: Color(0xFF2E9A50),
    pinDefault: Color(0xFF49454F),
    pinAdded: Color(0xFF4A4DE0),
    pinManual: Color(0xFF4A7A1A),
    pinVisited: Color(0xFF9E9E9E),
    pinCurrent: Color(0xFF4A4DE0),
    tierUnknown: Color(0xFF9E9E9E),
    tierEmerging: Color(0xFFC09A10),
    tierEstablished: Color(0xFF2E9A50),
    warning: Color(0xFFC09A10),
  );

  @override
  KnColors copyWith({Color? primary, Color? tertiary}) => KnColors(
        surface: surface,
        surfaceLowest: surfaceLowest,
        surfaceLow: surfaceLow,
        surfaceContainer: surfaceContainer,
        surfaceHigh: surfaceHigh,
        surfaceHighest: surfaceHighest,
        primary: primary ?? this.primary,
        primaryDim: primaryDim,
        onPrimary: onPrimary,
        primaryContainer: primaryContainer,
        onPrimaryContainer: onPrimaryContainer,
        tertiary: tertiary ?? this.tertiary,
        onTertiary: onTertiary,
        tertiaryContainer: tertiaryContainer,
        onTertiaryContainer: onTertiaryContainer,
        onSurface: onSurface,
        onSurfaceVariant: onSurfaceVariant,
        onSurfaceDisabled: onSurfaceDisabled,
        outline: outline,
        ghostBorder: ghostBorder,
        glass: glass,
        error: error,
        errorContainer: errorContainer,
        onError: onError,
        onErrorContainer: onErrorContainer,
        statusBacklog: statusBacklog,
        statusTodo: statusTodo,
        statusDevelopment: statusDevelopment,
        statusTesting: statusTesting,
        statusFutureRelease: statusFutureRelease,
        statusDone: statusDone,
        pinDefault: pinDefault,
        pinAdded: pinAdded,
        pinManual: pinManual,
        pinVisited: pinVisited,
        pinCurrent: pinCurrent,
        tierUnknown: tierUnknown,
        tierEmerging: tierEmerging,
        tierEstablished: tierEstablished,
        warning: warning,
      );

  @override
  KnColors lerp(ThemeExtension<KnColors>? other, double t) {
    if (other is! KnColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return KnColors(
      surface: l(surface, other.surface),
      surfaceLowest: l(surfaceLowest, other.surfaceLowest),
      surfaceLow: l(surfaceLow, other.surfaceLow),
      surfaceContainer: l(surfaceContainer, other.surfaceContainer),
      surfaceHigh: l(surfaceHigh, other.surfaceHigh),
      surfaceHighest: l(surfaceHighest, other.surfaceHighest),
      primary: l(primary, other.primary),
      primaryDim: l(primaryDim, other.primaryDim),
      onPrimary: l(onPrimary, other.onPrimary),
      primaryContainer: l(primaryContainer, other.primaryContainer),
      onPrimaryContainer: l(onPrimaryContainer, other.onPrimaryContainer),
      tertiary: l(tertiary, other.tertiary),
      onTertiary: l(onTertiary, other.onTertiary),
      tertiaryContainer: l(tertiaryContainer, other.tertiaryContainer),
      onTertiaryContainer: l(onTertiaryContainer, other.onTertiaryContainer),
      onSurface: l(onSurface, other.onSurface),
      onSurfaceVariant: l(onSurfaceVariant, other.onSurfaceVariant),
      onSurfaceDisabled: l(onSurfaceDisabled, other.onSurfaceDisabled),
      outline: l(outline, other.outline),
      ghostBorder: l(ghostBorder, other.ghostBorder),
      glass: l(glass, other.glass),
      error: l(error, other.error),
      errorContainer: l(errorContainer, other.errorContainer),
      onError: l(onError, other.onError),
      onErrorContainer: l(onErrorContainer, other.onErrorContainer),
      statusBacklog: l(statusBacklog, other.statusBacklog),
      statusTodo: l(statusTodo, other.statusTodo),
      statusDevelopment: l(statusDevelopment, other.statusDevelopment),
      statusTesting: l(statusTesting, other.statusTesting),
      statusFutureRelease: l(statusFutureRelease, other.statusFutureRelease),
      statusDone: l(statusDone, other.statusDone),
      pinDefault: l(pinDefault, other.pinDefault),
      pinAdded: l(pinAdded, other.pinAdded),
      pinManual: l(pinManual, other.pinManual),
      pinVisited: l(pinVisited, other.pinVisited),
      pinCurrent: l(pinCurrent, other.pinCurrent),
      tierUnknown: l(tierUnknown, other.tierUnknown),
      tierEmerging: l(tierEmerging, other.tierEmerging),
      tierEstablished: l(tierEstablished, other.tierEstablished),
      warning: l(warning, other.warning),
    );
  }
}

extension KnContext on BuildContext {
  KnColors get kn => Theme.of(this).extension<KnColors>() ?? KnColors.dark;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
