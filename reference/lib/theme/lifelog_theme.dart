import 'package:flutter/material.dart';

/// Lifelog Design System — inspired by Swiss-Italian notebook aesthetics.
///
/// Swiss (International Typographic Style): Grid-based layout, strong
/// typographic hierarchy, generous whitespace, precision spacing.
/// Italian (Moleskine/Fabriano): Warm paper tones, understated elegance,
/// material quality that invites daily use.
///
/// The design system is accessed through [LifelogTheme.light()] and
/// [LifelogTheme.dark()] which return fully configured [ThemeData].
/// Widget-level tokens are accessed via [LifelogTokens], an InheritedWidget
/// injected at the app root.
/// See: https://api.flutter.dev/flutter/material/ThemeData-class.html
class LifelogTheme {
  LifelogTheme._();

  // ══════════════════════════════════════════════════════════════════════
  // COLOR PALETTE
  // ══════════════════════════════════════════════════════════════════════

  // --- Light theme colors ---
  static const Color _paperWhite = Color(0xFFFAF8F5);
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _inkBlack = Color(0xFF1A1A1A);
  static const Color _inkMedium = Color(0xFF4A4A4A);
  static const Color _inkLight = Color(0xFF8A8A8A);
  static const Color _inkHint = Color(0xFFB0B0B0);
  static const Color _rule = Color(0xFFE8E4DF);

  static const Color _accentBlue = Color(0xFF2C5282);
  static const Color _accentBlueMuted = Color(0xFF5A7FA5);
  static const Color _warmAmber = Color(0xFFC05621);

  // --- Dark theme colors ---
  static const Color _darkBackground = Color(0xFF1A1A1A);
  static const Color _darkSurface = Color(0xFF242424);
  static const Color _darkInk = Color(0xFFE8E4DF);
  static const Color _darkInkMedium = Color(0xFFB0ADA8);
  static const Color _darkInkLight = Color(0xFF787572);
  static const Color _darkInkHint = Color(0xFF585552);
  static const Color _darkRule = Color(0xFF333333);

  static const Color _darkAccentBlue = Color(0xFF6B9BD2);
  static const Color _darkAccentBlueMuted = Color(0xFF4A7AAF);
  static const Color _darkWarmAmber = Color(0xFFE07A3A);

  // ══════════════════════════════════════════════════════════════════════
  // TYPOGRAPHY
  //
  // Swiss design: limited weights, clear hierarchy, tight headings,
  // comfortable body text. Letter-spacing controls rhythm.
  // ══════════════════════════════════════════════════════════════════════

  static TextTheme _buildTextTheme(Color ink, Color inkMedium, Color inkLight) {
    return TextTheme(
      // H1 — Day section headings, primary titles
      headlineMedium: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        height: 1.2,
        color: ink,
      ),
      // H2 — Sub-section headings
      headlineSmall: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        height: 1.25,
        color: ink,
      ),
      // H3 — Minor headings
      titleLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.0,
        height: 1.3,
        color: ink,
      ),
      // Date section labels — uppercase, letter-spaced
      titleMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.2,
        height: 1.4,
        color: inkMedium,
      ),
      // Body text — comfortable reading
      bodyLarge: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.0,
        height: 1.5,
        color: ink,
      ),
      // Default body
      bodyMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.0,
        height: 1.5,
        color: ink,
      ),
      // Metadata, streak info, secondary text
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.2,
        height: 1.4,
        color: inkLight,
      ),
      // Labels and captions
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        height: 1.3,
        color: inkLight,
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // THEME BUILDERS
  // ══════════════════════════════════════════════════════════════════════

  static ThemeData light() {
    final textTheme = _buildTextTheme(_inkBlack, _inkMedium, _inkLight);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: _paperWhite,
      colorScheme: const ColorScheme.light(
        primary: _accentBlue,
        secondary: _accentBlueMuted,
        tertiary: _warmAmber,
        surface: _surface,
        onSurface: _inkBlack,
        onSurfaceVariant: _inkMedium,
        outline: _inkLight,
        outlineVariant: _rule,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: _paperWhite,
        foregroundColor: _inkBlack,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.titleMedium?.copyWith(
          fontSize: 14,
          letterSpacing: 1.5,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: _rule,
        thickness: 0.5,
        space: 0,
      ),
      // inputDecorationTheme: default unfilled surface — search bar sets its own fill.
      // InheritedWidget theme merging: filled/fillColor here would bleed into all
      // TextFields including record rows. Each field that wants fill opts in explicitly.
      inputDecorationTheme: InputDecorationTheme(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _rule, width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _rule, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _accentBlueMuted, width: 1.0),
        ),
        hintStyle: TextStyle(
          color: _inkHint,
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(3),
        ),
        side: const BorderSide(color: _inkLight, width: 1.5),
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return _accentBlue;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(_surface),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _inkBlack,
        foregroundColor: _paperWhite,
        elevation: 1,
        highlightElevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      iconTheme: const IconThemeData(
        color: _inkMedium,
        size: 20,
      ),
    );
  }

  static ThemeData dark() {
    final textTheme =
        _buildTextTheme(_darkInk, _darkInkMedium, _darkInkLight);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: _darkAccentBlue,
        secondary: _darkAccentBlueMuted,
        tertiary: _darkWarmAmber,
        surface: _darkSurface,
        onSurface: _darkInk,
        onSurfaceVariant: _darkInkMedium,
        outline: _darkInkLight,
        outlineVariant: _darkRule,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: _darkBackground,
        foregroundColor: _darkInk,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.titleMedium?.copyWith(
          fontSize: 14,
          letterSpacing: 1.5,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: _darkRule,
        thickness: 0.5,
        space: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _darkRule, width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _darkRule, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:
              const BorderSide(color: _darkAccentBlueMuted, width: 1.0),
        ),
        hintStyle: TextStyle(
          color: _darkInkHint,
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(3),
        ),
        side: const BorderSide(color: _darkInkLight, width: 1.5),
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return _darkAccentBlue;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(_darkBackground),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _darkInk,
        foregroundColor: _darkBackground,
        elevation: 1,
        highlightElevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      iconTheme: const IconThemeData(
        color: _darkInkMedium,
        size: 20,
      ),
    );
  }
}

/// Design tokens accessible from any widget via [LifelogTokens.of(context)].
///
/// Flutter's InheritedWidget pattern makes these available anywhere in the tree
/// without passing them as constructor parameters.
/// See: https://api.flutter.dev/flutter/widgets/InheritedWidget-class.html
class LifelogTokens extends InheritedWidget {
  /// Spacing scale — all based on an 8px grid.
  final double spacing2 = 2;
  final double spacing4 = 4;
  final double spacing8 = 8;
  final double spacing12 = 12;
  final double spacing16 = 16;
  final double spacing20 = 20;
  final double spacing24 = 24;
  final double spacing32 = 32;
  final double spacing48 = 48;

  /// Record-specific sizing
  final double checkboxSize = 20;
  final double checkboxToTextGap = 10;
  final double bulletSize = 20;
  final double habitIconSize = 22;

  /// Border radii
  final double radiusSmall = 4;
  final double radiusMedium = 8;
  final double radiusLarge = 12;

  /// Rule (divider) thickness
  final double ruleThickness = 0.5;

  const LifelogTokens({super.key, required super.child});

  static LifelogTokens of(BuildContext context) {
    final result = context.dependOnInheritedWidgetOfExactType<LifelogTokens>();
    assert(result != null, 'No LifelogTokens found in context');
    return result!;
  }

  @override
  bool updateShouldNotify(LifelogTokens oldWidget) => false;
}
