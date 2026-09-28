import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Yazı sistemi: başlıklarda editoryal serif (Fraunces), metinde sade grotesk (Manrope).
abstract final class AppType {
  /// Dergi başlığı gibi serif. İtalik vurgu kelimeleri için [italic] kullanılır.
  static TextStyle serif({
    double size = 28,
    FontWeight weight = FontWeight.w500,
    Color? color,
    bool italic = false,
    double height = 1.08,
    double? letterSpacing,
  }) => GoogleFonts.fraunces(
    fontSize: size,
    fontWeight: weight,
    fontStyle: italic ? FontStyle.italic : FontStyle.normal,
    color: color,
    height: height,
    letterSpacing: letterSpacing ?? -size * 0.025,
  );

  /// Büyük harfli, geniş aralıklı üst etiket ("KABİN · DENEME").
  static TextStyle overline(Color color, {double size = 11}) =>
      GoogleFonts.manrope(fontSize: size, fontWeight: FontWeight.w800, letterSpacing: size * 0.2, color: color, height: 1.2);

  /// Sayısal değerler için eşit genişlikli rakamlar.
  static TextStyle numeric({double size = 14, FontWeight weight = FontWeight.w700, Color? color}) =>
      GoogleFonts.manrope(fontSize: size, fontWeight: weight, color: color, fontFeatures: const [FontFeature.tabularFigures()]);
}

abstract final class AppTheme {
  static const double radius = 16;
  static const double radiusLg = 24;

  static TextTheme _text(Color body, Color display) {
    final sans = GoogleFonts.manropeTextTheme();
    TextStyle s(TextStyle? base, double size, FontWeight w, {double? height, double? ls}) =>
        (base ?? const TextStyle()).copyWith(fontSize: size, fontWeight: w, height: height, letterSpacing: ls, color: body);
    return sans.copyWith(
      displayLarge: AppType.serif(size: 44, color: display),
      displayMedium: AppType.serif(size: 38, color: display),
      displaySmall: AppType.serif(size: 32, color: display),
      headlineLarge: AppType.serif(size: 30, color: display),
      headlineMedium: AppType.serif(size: 26, color: display),
      headlineSmall: AppType.serif(size: 22, weight: FontWeight.w600, color: display, height: 1.15),
      titleLarge: AppType.serif(size: 20, weight: FontWeight.w600, color: display, height: 1.2),
      titleMedium: s(sans.titleMedium, 16, FontWeight.w700, height: 1.3),
      titleSmall: s(sans.titleSmall, 14, FontWeight.w700, height: 1.3),
      bodyLarge: s(sans.bodyLarge, 16, FontWeight.w500, height: 1.5),
      bodyMedium: s(sans.bodyMedium, 14, FontWeight.w500, height: 1.5),
      bodySmall: s(sans.bodySmall, 12.5, FontWeight.w500, height: 1.45),
      labelLarge: s(sans.labelLarge, 15, FontWeight.w700, ls: 0.1),
      labelMedium: s(sans.labelMedium, 12.5, FontWeight.w700, ls: 0.2),
      labelSmall: s(sans.labelSmall, 11, FontWeight.w700, ls: 0.3),
    );
  }

  static ThemeData get light => _base(
    const ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.plum900,
      onPrimary: AppColors.ivory,
      primaryContainer: AppColors.plum100,
      onPrimaryContainer: AppColors.plum900,
      secondary: AppColors.terracotta,
      onSecondary: AppColors.white,
      secondaryContainer: AppColors.terracottaSoft,
      onSecondaryContainer: AppColors.terracottaDeep,
      tertiary: AppColors.brass,
      onTertiary: AppColors.white,
      error: AppColors.error,
      onError: AppColors.white,
      errorContainer: AppColors.errorSoft,
      onErrorContainer: AppColors.error,
      surface: AppColors.ivory,
      onSurface: AppColors.ink,
      surfaceContainerLowest: AppColors.paper,
      surfaceContainerLow: AppColors.sand50,
      surfaceContainer: AppColors.sand100,
      surfaceContainerHigh: AppColors.sand100,
      surfaceContainerHighest: AppColors.sand200,
      onSurfaceVariant: AppColors.ink2,
      outline: AppColors.sand300,
      outlineVariant: AppColors.sand200,
      shadow: AppColors.plum950,
      scrim: AppColors.plum950,
      inverseSurface: AppColors.ink,
      onInverseSurface: AppColors.ivory,
      inversePrimary: AppColors.plum300,
    ),
  );

  static ThemeData get dark => _base(
    const ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.moon,
      onPrimary: AppColors.plum950,
      primaryContainer: AppColors.plum800,
      onPrimaryContainer: AppColors.plum100,
      secondary: AppColors.terracotta,
      onSecondary: AppColors.white,
      secondaryContainer: AppColors.terracottaNight,
      onSecondaryContainer: AppColors.terracottaSoft,
      tertiary: AppColors.brass,
      onTertiary: AppColors.night,
      error: AppColors.errorNight,
      onError: AppColors.night,
      errorContainer: AppColors.errorNightContainer,
      onErrorContainer: AppColors.errorNightOn,
      surface: AppColors.night,
      onSurface: AppColors.moon,
      surfaceContainerLowest: AppColors.night2,
      surfaceContainerLow: AppColors.night2,
      surfaceContainer: AppColors.night3,
      surfaceContainerHigh: AppColors.night3,
      surfaceContainerHighest: AppColors.night4,
      onSurfaceVariant: AppColors.moon2,
      outline: AppColors.night4,
      outlineVariant: AppColors.night3,
      shadow: AppColors.black,
      scrim: AppColors.black,
      inverseSurface: AppColors.moon,
      onInverseSurface: AppColors.night,
      inversePrimary: AppColors.plum700,
    ),
  );

  static ThemeData _base(ColorScheme scheme) {
    final text = _text(scheme.onSurface, scheme.onSurface);
    const pill = StadiumBorder();
    final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: text,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: AppColors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 20,
        titleTextStyle: AppType.serif(size: 22, weight: FontWeight.w600, color: scheme.onSurface),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: scheme.surfaceContainerHighest,
          disabledForegroundColor: scheme.onSurfaceVariant,
          minimumSize: const Size.fromHeight(56),
          shape: pill,
          textStyle: text.labelLarge,
          elevation: 0,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size(0, 48), shape: pill, textStyle: text.labelLarge),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          minimumSize: const Size(0, 48),
          side: BorderSide(color: scheme.outline),
          shape: pill,
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: scheme.primary, shape: pill, textStyle: text.labelLarge),
      ),
      iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: scheme.onSurface)),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: pill,
        elevation: 2,
        extendedTextStyle: text.labelLarge,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(radius), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: scheme.primary, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: scheme.error),
        ),
        floatingLabelStyle: text.labelMedium?.copyWith(color: scheme.primary),
        labelStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        hintStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLowest,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide(color: scheme.outlineVariant),
        backgroundColor: scheme.surfaceContainerLowest,
        selectedColor: scheme.primary,
        secondarySelectedColor: scheme.primary,
        labelStyle: text.labelMedium,
        secondaryLabelStyle: text.labelMedium?.copyWith(color: scheme.onPrimary),
        checkmarkColor: scheme.onPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? scheme.onPrimary : scheme.outline),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? scheme.secondary : scheme.surfaceContainerHighest,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(AppColors.transparent),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(color: scheme.onInverseSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 0.8, space: 0.8),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.onSurface,
        unselectedLabelColor: scheme.onSurfaceVariant,
        indicatorColor: scheme.secondary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: AppColors.transparent,
        labelStyle: text.titleSmall,
        unselectedLabelStyle: text.titleSmall,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: AppColors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        showDragHandle: true,
        dragHandleColor: scheme.outline,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: AppColors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        titleTextStyle: AppType.serif(size: 22, weight: FontWeight.w600, color: scheme.onSurface),
        contentTextStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.secondary, linearTrackColor: scheme.surfaceContainerHighest),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
        iconColor: scheme.onSurfaceVariant,
        titleTextStyle: text.titleSmall?.copyWith(color: scheme.onSurface),
        subtitleTextStyle: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        shape: rounded,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {TargetPlatform.android: FadeForwardsPageTransitionsBuilder(), TargetPlatform.iOS: CupertinoPageTransitionsBuilder()},
      ),
    );
  }
}
