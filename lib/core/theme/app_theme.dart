import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens del rediseño: una sola marca en dos modos.
/// Oscuro = "Hextech" (azul-noche + dorado), claro = marketplace diurno
/// con los mismos acentos.
abstract final class AppColors {
  // Base oscura
  static const inkNight = Color(0xFF0E1524);
  static const surfaceNight = Color(0xFF182030);
  static const surfaceNightHigh = Color(0xFF212B3E);

  // Base clara
  static const mistLight = Color(0xFFF4F6F8);
  static const outlineLight = Color(0xFFE1E5EA);

  // Acentos de marca
  static const deepTeal = Color(0xFF0F4C5C);
  static const brightTeal = Color(0xFF4FB3C6);
  static const goldDark = Color(0xFFE3B341); // precios/foil sobre oscuro
  static const bronzeLight = Color(0xFF8A6410); // precios/foil sobre claro

  /// Color de precio según brillo del tema.
  static Color price(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? goldDark : bronzeLight;
}

abstract final class AppTheme {
  static const mobileBreakpoint = 700.0;

  static ThemeData get light => _build(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.deepTeal,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.deepTeal,
          secondary: AppColors.bronzeLight,
          surface: Colors.white,
          surfaceContainerLowest: AppColors.mistLight,
          outlineVariant: AppColors.outlineLight,
        ),
        scaffoldBackground: AppColors.mistLight,
        cardBorder: const BorderSide(color: AppColors.outlineLight),
      );

  static ThemeData get dark => _build(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.deepTeal,
          brightness: Brightness.dark,
        ).copyWith(
          primary: AppColors.brightTeal,
          onPrimary: AppColors.inkNight,
          secondary: AppColors.goldDark,
          onSecondary: AppColors.inkNight,
          surface: AppColors.surfaceNight,
          surfaceContainerLowest: AppColors.inkNight,
          surfaceContainerHighest: AppColors.surfaceNightHigh,
          outlineVariant: AppColors.surfaceNightHigh,
        ),
        scaffoldBackground: AppColors.inkNight,
        cardBorder: const BorderSide(color: AppColors.surfaceNightHigh),
      );

  static ThemeData _build({
    required ColorScheme colorScheme,
    required Color scaffoldBackground,
    required BorderSide cardBorder,
  }) {
    final baseText = GoogleFonts.interTextTheme(
      colorScheme.brightness == Brightness.dark
          ? ThemeData.dark().textTheme
          : ThemeData.light().textTheme,
    );
    final display = GoogleFonts.spaceGrotesk();

    final textTheme = baseText.copyWith(
      displayLarge: baseText.displayLarge?.merge(display),
      displayMedium: baseText.displayMedium?.merge(display),
      displaySmall: baseText.displaySmall?.merge(display),
      headlineLarge: baseText.headlineLarge
          ?.merge(display)
          .copyWith(fontWeight: FontWeight.w700),
      headlineMedium: baseText.headlineMedium
          ?.merge(display)
          .copyWith(fontWeight: FontWeight.w700),
      headlineSmall: baseText.headlineSmall
          ?.merge(display)
          .copyWith(fontWeight: FontWeight.w700),
      titleLarge: baseText.titleLarge
          ?.merge(display)
          .copyWith(fontWeight: FontWeight.w700),
      titleMedium:
          baseText.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    );

    const radius10 = BorderRadius.all(Radius.circular(10));

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackground,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: cardBorder,
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: radius10,
          borderSide: cardBorder,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius10,
          borderSide: cardBorder,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius10,
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: const RoundedRectangleBorder(borderRadius: radius10),
          textStyle: textTheme.titleMedium,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: const RoundedRectangleBorder(borderRadius: radius10),
          textStyle: textTheme.titleMedium,
          side: BorderSide(color: colorScheme.outline),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: colorScheme.primary),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: cardBorder,
        ),
        backgroundColor: colorScheme.surface,
        selectedColor: colorScheme.primary.withValues(alpha: 0.18),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primary.withValues(alpha: 0.18),
        elevation: 0,
      ),
      searchBarTheme: SearchBarThemeData(
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: WidgetStatePropertyAll(colorScheme.surface),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: radius10,
            side: cardBorder,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(color: colorScheme.outlineVariant),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: radius10),
        backgroundColor:
            colorScheme.brightness == Brightness.dark
                ? AppColors.surfaceNightHigh
                : const Color(0xFF22303C),
      ),
    );
  }
}

/// Estilo de precio: Space Grotesk bold, cifras tabulares, color dorado/bronce.
TextStyle priceStyle(BuildContext context, {double fontSize = 16}) =>
    GoogleFonts.spaceGrotesk(
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      color: AppColors.price(context),
      fontFeatures: const [FontFeature.tabularFigures()],
    );
