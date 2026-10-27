import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// BookIt design system — professional light-blue & white palette.
///
/// Every screen pulls its colors/shape from here so the whole app stays
/// consistent. Light blue = primary actions & accents, white = surfaces.
abstract final class AppColors {
  // Primary light-blue ramp.
  static const Color primary = Color(0xFF0288D1);
  static const Color primaryLight = Color(0xFF4FC3F7);
  static const Color primaryDark = Color(0xFF01579B);
  static const Color primarySoft = Color(0xFFE1F5FE);
  static const Color primaryFaint = Color(0xFFF3FBFE);

  // Neutrals / surfaces.
  static const Color white = Colors.white;
  static const Color background = primaryFaint;
  static const Color textDark = Color(0xFF102A43);
  static const Color textMuted = Color(0xFF7B8CA3);

  // Feedback.
  static const Color success = Color(0xFF26C281);
  static const Color danger = Color(0xFFFF5252);

  /// Signature gradient used by banners, buttons and the splash logo.
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryDark, primary, primaryLight],
  );
}

/// Shared radii / paddings.
abstract final class AppSpacing {
  static const double cardRadius = 20;
  static const double chipRadius = 14;
  static const double buttonRadius = 16;
  static const double screenPadding = 24;
}

/// Material theme for the whole app (light only — the brand is light & airy).
class AppTheme {
  const AppTheme._();

  static ThemeData get theme => themeFor('white');

  static ThemeData themeFor(String mode) {
    final isDark = mode == 'dark';
    final isGreen = mode == 'green';
    final primary = isGreen ? const Color(0xFF2E7D32) : AppColors.primary;
    final primaryLight = isGreen ? const Color(0xFF81C784) : AppColors.primaryLight;
    final surface = isDark ? const Color(0xFF151A20) : AppColors.white;
    final background = isDark ? const Color(0xFF0D1117) : (isGreen ? const Color(0xFFF1F8E9) : AppColors.background);
    final foreground = isDark ? const Color(0xFFF1F5F9) : AppColors.textDark;
    final muted = isDark ? const Color(0xFFB0BEC5) : AppColors.textMuted;
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: isDark ? Brightness.dark : Brightness.light,
      surface: surface,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme.copyWith(
        primary: primary,
        secondary: primaryLight,
        surface: surface,
      ),
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: surface,
        foregroundColor: foreground,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        ),
      ),
      textTheme: _textTheme,
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: background,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          borderSide: const BorderSide(color: isDark ? const Color(0xFF34404D) : (isGreen ? const Color(0xFFC5E1A5) : const Color(0xFFDCEEFB))),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          borderSide: const BorderSide(
            color: primary,
            width: 1.6,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        labelStyle: TextStyle(color: muted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size.fromHeight(54),
          side: BorderSide(color: primaryLight, width: 1.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: surface,
        selectedColor: primary,
        secondaryLabelStyle: TextStyle(color: AppColors.white),
        labelStyle: TextStyle(color: AppColors.textDark),
        side: BorderSide(color: Color(0xFFE1F5FE)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(AppSpacing.chipRadius),
          ),
        ),
        elevation: 0,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? const Color(0xFF263238) : AppColors.textDark,
        contentTextStyle: TextStyle(color: AppColors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(AppSpacing.chipRadius),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: isDark ? const Color(0xFF263238) : (isGreen ? const Color(0xFFC8E6C9) : AppColors.primarySoft),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: primary,
          ),
        ),
        iconTheme: const WidgetStatePropertyAll(
          IconThemeData(color: primary),
        ),
      ),
    );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      textTheme: base.textTheme.apply(bodyColor: foreground, displayColor: foreground),
      dividerColor: isDark ? const Color(0xFF303943) : null,
      cardTheme: base.cardTheme.copyWith(color: surface),
      appBarTheme: base.appBarTheme.copyWith(backgroundColor: surface, foregroundColor: foreground),
    );
  }

  static const TextTheme _textTheme = TextTheme(
    displaySmall: TextStyle(
      color: AppColors.textDark,
      fontSize: 32,
      fontWeight: FontWeight.w700,
      height: 1.15,
      letterSpacing: -0.5,
    ),
    headlineMedium: TextStyle(
      color: AppColors.textDark,
      fontSize: 24,
      fontWeight: FontWeight.w700,
    ),
    titleLarge: TextStyle(
      color: AppColors.textDark,
      fontSize: 18,
      fontWeight: FontWeight.w700,
    ),
    bodyMedium: TextStyle(
      color: AppColors.textDark,
      fontSize: 14,
      height: 1.5,
    ),
    bodySmall: TextStyle(
      color: AppColors.textMuted,
      fontSize: 12,
      height: 1.4,
    ),
  );
}

/// Reusable light-blue hero header/banner used on the splash & home screens so
/// every top-level surface shares one look.
class GradientBanner extends StatelessWidget {
  const GradientBanner({
    super.key,
    required this.child,
    this.height = 220,
    this.borderRadius = const BorderRadius.vertical(
      bottom: Radius.circular(40),
    ),
  });

  final Widget child;
  final double height;
  final BorderRadiusGeometry borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: borderRadius,
      ),
      child: child,
    );
  }
}
