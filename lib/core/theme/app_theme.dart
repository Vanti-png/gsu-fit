import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Apple-style look (see github.com/ceorkm/macos-design-skill): system
/// colors, Inter as a stand-in for SF Pro, hairline borders instead of
/// heavy outlines, rounded surfaces, and light and dark palettes designed
/// separately rather than inverted.
///
/// The theme reports [TargetPlatform.iOS] so adaptive widgets render as
/// Cupertino controls and pages use iOS transitions and bouncing scroll on
/// every platform.
class AppTheme {
  static const String fontFamily = 'Inter';

  static ThemeData light() => _build(AppPalette.light);

  static ThemeData dark() => _build(AppPalette.dark);

  static TextTheme _textTheme(AppPalette p) {
    TextStyle style(double size, FontWeight weight, double tracking, {Color? color, double? height}) =>
        TextStyle(
          fontFamily: fontFamily,
          fontSize: size,
          fontWeight: weight,
          letterSpacing: tracking,
          height: height,
          color: color ?? p.textPrimary,
        );
    return TextTheme(
      displayLarge: style(40, FontWeight.w700, -1.0),
      displayMedium: style(36, FontWeight.w700, -0.9),
      displaySmall: style(32, FontWeight.w700, -0.8),
      headlineLarge: style(30, FontWeight.w700, -0.7),
      headlineMedium: style(26, FontWeight.w700, -0.6),
      headlineSmall: style(22, FontWeight.w600, -0.4),
      titleLarge: style(19, FontWeight.w600, -0.3),
      titleMedium: style(16, FontWeight.w600, -0.2),
      titleSmall: style(14, FontWeight.w600, -0.1),
      bodyLarge: style(16, FontWeight.w400, -0.2, height: 1.35),
      bodyMedium: style(14, FontWeight.w400, -0.1, height: 1.35),
      bodySmall: style(12.5, FontWeight.w400, 0, color: p.textSecondary, height: 1.3),
      labelLarge: style(15, FontWeight.w600, -0.1),
      labelMedium: style(13, FontWeight.w500, 0),
      labelSmall: style(11, FontWeight.w500, 0.1, color: p.textSecondary),
    );
  }

  static ThemeData _build(AppPalette p) {
    final scheme = ColorScheme(
      brightness: p.brightness,
      primary: p.accent,
      onPrimary: Colors.white,
      primaryContainer: p.accentTint,
      onPrimaryContainer: p.accentText,
      secondary: p.textSecondary,
      onSecondary: Colors.white,
      secondaryContainer: p.fill,
      onSecondaryContainer: p.accentText,
      tertiary: p.orange,
      onTertiary: Colors.white,
      tertiaryContainer: p.orangeTint,
      onTertiaryContainer: p.orangeText,
      error: p.red,
      onError: Colors.white,
      errorContainer: p.redTint,
      onErrorContainer: p.redText,
      surface: p.window,
      onSurface: p.textPrimary,
      onSurfaceVariant: p.textSecondary,
      surfaceContainerLowest: p.card,
      surfaceContainerLow: p.card,
      surfaceContainer: p.card,
      surfaceContainerHigh: p.fill,
      surfaceContainerHighest: p.fill,
      outline: p.borderStrong,
      outlineVariant: p.border,
      inverseSurface: p.toast,
      onInverseSurface: p.toastText,
      inversePrimary: p.accent,
      shadow: Colors.black,
      scrim: Colors.black,
      surfaceTint: Colors.transparent,
    );
    final text = _textTheme(p);
    const radius12 = BorderRadius.all(Radius.circular(12));
    const radius10 = BorderRadius.all(Radius.circular(10));

    return ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      platform: TargetPlatform.iOS,
      colorScheme: scheme,
      fontFamily: fontFamily,
      textTheme: text,
      scaffoldBackgroundColor: p.window,
      canvasColor: p.window,
      dividerColor: p.border,
      visualDensity: VisualDensity.standard,
      // Apple controls highlight on press instead of drawing ripples.
      splashFactory: NoSplash.splashFactory,
      extensions: [p],
      cupertinoOverrideTheme: CupertinoThemeData(
        brightness: p.brightness,
        primaryColor: p.accent,
        scaffoldBackgroundColor: p.window,
        barBackgroundColor: p.bar,
        textTheme: CupertinoTextThemeData(
          primaryColor: p.accent,
          textStyle: text.bodyLarge,
          tabLabelTextStyle: TextStyle(
            fontFamily: fontFamily,
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
            letterSpacing: 0,
            color: p.textSecondary,
          ),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
          TargetPlatform.fuchsia: CupertinoPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarThemeData(
        backgroundColor: p.window,
        foregroundColor: p.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        titleTextStyle: text.titleMedium?.copyWith(fontSize: 17),
        shape: Border(bottom: BorderSide(color: p.border, width: 0.5)),
      ),
      cardTheme: CardThemeData(
        color: p.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: radius12,
          side: BorderSide(color: p.border, width: 0.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: const RoundedRectangleBorder(borderRadius: radius12),
          textStyle: text.labelLarge,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          foregroundColor: p.accent,
          shape: const RoundedRectangleBorder(borderRadius: radius12),
          side: BorderSide(color: p.borderStrong, width: 0.5),
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 44),
          foregroundColor: p.accent,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
          textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w500),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.accent,
        foregroundColor: Colors.white,
        elevation: 3,
        focusElevation: 3,
        hoverElevation: 4,
        highlightElevation: 2,
        shape: const StadiumBorder(),
        extendedTextStyle: text.labelLarge,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.fill,
        selectedColor: p.accentTint,
        side: const BorderSide(color: Colors.transparent),
        shape: const StadiumBorder(),
        showCheckmark: false,
        labelStyle: text.labelMedium,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      ),
      listTileTheme: ListTileThemeData(
        minVerticalPadding: 10,
        iconColor: p.textSecondary,
        titleTextStyle: text.bodyLarge,
        subtitleTextStyle: text.bodySmall,
      ),
      dividerTheme: DividerThemeData(color: p.border, thickness: 0.5, space: 1),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.window,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: p.borderStrong,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.card,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
        titleTextStyle: text.titleMedium?.copyWith(fontSize: 17),
        contentTextStyle: text.bodyMedium,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: p.card,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: radius10,
          side: BorderSide(color: p.border, width: 0.5),
        ),
        textStyle: text.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.toast,
        contentTextStyle: text.bodyMedium?.copyWith(color: p.toastText),
        actionTextColor: p.accentOnToast,
        elevation: 4,
        shape: const RoundedRectangleBorder(borderRadius: radius12),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.accent,
        linearTrackColor: p.fill,
        circularTrackColor: p.fill,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: p.accent,
        unselectedLabelColor: p.textSecondary,
        indicatorColor: p.accent,
        dividerColor: p.border,
        labelStyle: text.labelMedium?.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: text.labelMedium,
      ),
      iconTheme: IconThemeData(color: p.textSecondary),
    );
  }
}

/// Apple system colors for both appearances, available anywhere through
/// `context.palette`.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.brightness,
    required this.window,
    required this.card,
    required this.sidebar,
    required this.bar,
    required this.fill,
    required this.selection,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.border,
    required this.borderStrong,
    required this.accent,
    required this.accentTint,
    required this.accentText,
    required this.accentOnToast,
    required this.green,
    required this.greenTint,
    required this.red,
    required this.redTint,
    required this.redText,
    required this.orange,
    required this.orangeTint,
    required this.orangeText,
    required this.yellow,
    required this.purple,
    required this.pink,
    required this.teal,
    required this.toast,
    required this.toastText,
  });

  final Brightness brightness;

  /// Window background (grouped lists sit on it).
  final Color window;

  /// Cards and grouped sections.
  final Color card;

  /// Sidebar on wide screens.
  final Color sidebar;

  /// Top/bottom bars.
  final Color bar;

  /// Inputs, chips, tracks, secondary buttons.
  final Color fill;

  /// Selected sidebar row (subtle, not a loud color block).
  final Color selection;

  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  /// 0.5 px hairlines.
  final Color border;
  final Color borderStrong;

  final Color accent;
  final Color accentTint;
  final Color accentText;
  final Color accentOnToast;

  final Color green;
  final Color greenTint;
  final Color red;
  final Color redTint;
  final Color redText;
  final Color orange;
  final Color orangeTint;
  final Color orangeText;
  final Color yellow;
  final Color purple;
  final Color pink;
  final Color teal;

  final Color toast;
  final Color toastText;

  static const AppPalette light = AppPalette(
    brightness: Brightness.light,
    window: Color(0xFFF5F5F7),
    card: Color(0xFFFFFFFF),
    sidebar: Color(0xFFECECEF),
    bar: Color(0xF0F9F9FB),
    fill: Color(0xFFE9E9EE),
    selection: Color(0x14000000),
    textPrimary: Color(0xFF1D1D1F),
    textSecondary: Color(0xFF6E6E73),
    textTertiary: Color(0xFFAEAEB2),
    border: Color(0x1A000000),
    borderStrong: Color(0x2E000000),
    accent: Color(0xFF007AFF),
    accentTint: Color(0xFFE3EEFF),
    accentText: Color(0xFF0062CC),
    accentOnToast: Color(0xFF64A8FF),
    green: Color(0xFF34C759),
    greenTint: Color(0xFFE2F6E7),
    red: Color(0xFFFF3B30),
    redTint: Color(0xFFFFE4E2),
    redText: Color(0xFFB4231A),
    orange: Color(0xFFFF9500),
    orangeTint: Color(0xFFFFF0DC),
    orangeText: Color(0xFF8A5100),
    yellow: Color(0xFFFFCC00),
    purple: Color(0xFFAF52DE),
    pink: Color(0xFFFF2D55),
    teal: Color(0xFF5AC8FA),
    toast: Color(0xF21D1D1F),
    toastText: Color(0xFFF5F5F7),
  );

  static const AppPalette dark = AppPalette(
    brightness: Brightness.dark,
    window: Color(0xFF1C1C1E),
    card: Color(0xFF2C2C2E),
    sidebar: Color(0xFF242426),
    bar: Color(0xF0232325),
    fill: Color(0xFF3A3A3C),
    selection: Color(0x1FFFFFFF),
    textPrimary: Color(0xFFF5F5F7),
    textSecondary: Color(0xFF98989D),
    textTertiary: Color(0xFF636366),
    border: Color(0x1FFFFFFF),
    borderStrong: Color(0x33FFFFFF),
    accent: Color(0xFF0A84FF),
    accentTint: Color(0xFF173A63),
    accentText: Color(0xFF8CC2FF),
    accentOnToast: Color(0xFF0A84FF),
    green: Color(0xFF30D158),
    greenTint: Color(0xFF1B3D25),
    red: Color(0xFFFF453A),
    redTint: Color(0xFF4A1F1C),
    redText: Color(0xFFFFB0AA),
    orange: Color(0xFFFF9F0A),
    orangeTint: Color(0xFF47331A),
    orangeText: Color(0xFFFFCF8A),
    yellow: Color(0xFFFFD60A),
    purple: Color(0xFFBF5AF2),
    pink: Color(0xFFFF375F),
    teal: Color(0xFF64D2FF),
    toast: Color(0xF23A3A3C),
    toastText: Color(0xFFF5F5F7),
  );

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(covariant AppPalette? other, double t) =>
      other == null || t < 0.5 ? this : other;
}

extension PaletteContext on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>() ?? AppPalette.light;
}
