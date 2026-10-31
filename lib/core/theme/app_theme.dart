import 'package:campus_core/campus_core.dart';
import 'package:material_ui/material_ui.dart';

/// Token màu theo DESIGN.md. Một accent duy nhất (Cobalt); đỏ chỉ dành cho khẩn cấp và lỗi.
abstract final class AppColors {
  static const Color seed = Color(0xFF1F4FA3);
  static const Color emergency = Color(0xFFC4231C);
  static const Color onEmergency = Color(0xFFFFFBFA);
}

/// Màu trạng thái và mức độ cho light/dark. Đọc bằng `Theme.of(context).extension<StatusPalette>()!`.
@immutable
class StatusPalette extends ThemeExtension<StatusPalette> {
  const StatusPalette({
    required this.statusBackground,
    required this.statusForeground,
    required this.severityBackground,
    required this.severityForeground,
    required this.emergency,
    required this.onEmergency,
    required this.emergencyText,
    required this.emergencyContainer,
    required this.onEmergencyContainer,
    required this.viewerBackground,
  });

  final Map<ReportStatus, Color> statusBackground;
  final Map<ReportStatus, Color> statusForeground;
  final Map<Severity, Color> severityBackground;
  final Map<Severity, Color> severityForeground;
  final Color emergency;
  final Color onEmergency;

  /// Chữ/icon đỏ trên nền thường (đạt 4.5:1 ở cả sáng và tối).
  final Color emergencyText;

  /// Nền tô nhẹ cho khối liên quan khẩn cấp (không phải nút hành động).
  final Color emergencyContainer;
  final Color onEmergencyContainer;

  /// Nền xem ảnh toàn màn (gần đen, không đen tuyệt đối).
  final Color viewerBackground;

  static const light = StatusPalette(
    statusBackground: {
      ReportStatus.submitted: Color(0xFFE6E9EF),
      ReportStatus.received: Color(0xFFDCE6F8),
      ReportStatus.inProgress: Color(0xFFFBEBC8),
      ReportStatus.resolved: Color(0xFFD6EFDF),
      ReportStatus.rejected: Color(0xFFECEAEA),
    },
    statusForeground: {
      ReportStatus.submitted: Color(0xFF353E4D),
      ReportStatus.received: Color(0xFF173E86),
      ReportStatus.inProgress: Color(0xFF6E4400),
      ReportStatus.resolved: Color(0xFF145530),
      ReportStatus.rejected: Color(0xFF4A4545),
    },
    severityBackground: {
      Severity.low: Color(0xFFE6E9EF),
      Severity.medium: Color(0xFFFBEBC8),
      Severity.high: Color(0xFFFDE3D3),
      Severity.critical: AppColors.emergency,
    },
    severityForeground: {
      Severity.low: Color(0xFF353E4D),
      Severity.medium: Color(0xFF6E4400),
      Severity.high: Color(0xFF8A3500),
      Severity.critical: AppColors.onEmergency,
    },
    emergency: AppColors.emergency,
    onEmergency: AppColors.onEmergency,
    emergencyText: Color(0xFFB3211A),
    emergencyContainer: Color(0xFFFCE8E5),
    onEmergencyContainer: Color(0xFF7A1712),
    viewerBackground: Color(0xFF0E1013),
  );

  static const dark = StatusPalette(
    statusBackground: {
      ReportStatus.submitted: Color(0xFF2A313C),
      ReportStatus.received: Color(0xFF1B3260),
      ReportStatus.inProgress: Color(0xFF4A3510),
      ReportStatus.resolved: Color(0xFF173D27),
      ReportStatus.rejected: Color(0xFF343131),
    },
    statusForeground: {
      ReportStatus.submitted: Color(0xFFD3DAE6),
      ReportStatus.received: Color(0xFFC9D9FA),
      ReportStatus.inProgress: Color(0xFFF5D9A0),
      ReportStatus.resolved: Color(0xFFB9E5C9),
      ReportStatus.rejected: Color(0xFFDAD5D5),
    },
    severityBackground: {
      Severity.low: Color(0xFF2A313C),
      Severity.medium: Color(0xFF4A3510),
      Severity.high: Color(0xFF4F2A12),
      Severity.critical: AppColors.emergency,
    },
    severityForeground: {
      Severity.low: Color(0xFFD3DAE6),
      Severity.medium: Color(0xFFF5D9A0),
      Severity.high: Color(0xFFF8C9A8),
      Severity.critical: AppColors.onEmergency,
    },
    emergency: AppColors.emergency,
    onEmergency: AppColors.onEmergency,
    emergencyText: Color(0xFFFFB4A9),
    emergencyContainer: Color(0xFF41110D),
    onEmergencyContainer: Color(0xFFFFDAD5),
    viewerBackground: Color(0xFF0E1013),
  );

  @override
  StatusPalette copyWith() => this;

  @override
  StatusPalette lerp(ThemeExtension<StatusPalette>? other, double t) =>
      (other is StatusPalette && t >= 0.5) ? other : this;
}

extension StatusPaletteX on BuildContext {
  StatusPalette get palette => Theme.of(this).extension<StatusPalette>() ?? StatusPalette.light;
}

abstract final class AppTheme {
  static const fontFamily = 'BeVietnamPro';

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.seed,
      brightness: brightness,
    ).copyWith(
      primary: isDark ? null : AppColors.seed,
      error: isDark ? const Color(0xFFFFB4AB) : AppColors.emergency,
    );

    const tabular = [FontFeature.tabularFigures()];
    final text = TextTheme(
      headlineSmall: const TextStyle(fontSize: 24, height: 32 / 24, fontWeight: FontWeight.w600),
      titleLarge: const TextStyle(fontSize: 20, height: 28 / 20, fontWeight: FontWeight.w600),
      titleMedium: const TextStyle(fontSize: 16, height: 24 / 16, fontWeight: FontWeight.w600),
      titleSmall: const TextStyle(fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w600),
      bodyLarge: const TextStyle(fontSize: 16, height: 24 / 16, fontWeight: FontWeight.w400),
      bodyMedium: const TextStyle(fontSize: 15, height: 22 / 15, fontWeight: FontWeight.w400),
      bodySmall: const TextStyle(fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w400),
      labelLarge: const TextStyle(fontSize: 15, height: 20 / 15, fontWeight: FontWeight.w600),
      labelMedium: const TextStyle(fontSize: 13, height: 18 / 13, fontWeight: FontWeight.w500),
      labelSmall: const TextStyle(fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w500),
      displaySmall: const TextStyle(fontSize: 32, height: 40 / 32, fontWeight: FontWeight.w600, fontFeatures: tabular),
    ).apply(
      fontFamily: fontFamily,
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );

    // Nền màn hơi tô màu, thẻ và ô nhập sáng hơn nền để các khối tách bạch, dễ nhìn.
    final background = isDark ? scheme.surface : scheme.surfaceContainerLow;
    final cardColor = isDark ? scheme.surfaceContainer : scheme.surfaceContainerLowest;
    final fieldFill = isDark ? scheme.surfaceContainerHigh : scheme.surfaceContainerLowest;

    const stadium = StadiumBorder();
    const buttonSize = Size(64, 52);
    final inputRadius = BorderRadius.circular(12);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: fontFamily,
      textTheme: text,
      scaffoldBackgroundColor: background,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      extensions: [isDark ? StatusPalette.dark : StatusPalette.light],
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: background,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 1,
        titleTextStyle: text.titleLarge,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: buttonSize, shape: stadium, textStyle: text.labelLarge),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: buttonSize,
          shape: stadium,
          textStyle: text.labelLarge,
          side: BorderSide(color: scheme.outline),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(48, 48), shape: stadium, textStyle: text.labelLarge),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(minimumSize: const Size(48, 48), textStyle: text.labelMedium),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fieldFill,
        prefixIconColor: scheme.onSurfaceVariant,
        border: OutlineInputBorder(borderRadius: inputRadius),
        enabledBorder: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        errorMaxLines: 3,
        helperMaxLines: 3,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        labelStyle: text.labelLarge,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        showDragHandle: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: isDark ? scheme.surfaceContainer : scheme.surfaceContainerLowest,
        indicatorColor: scheme.primaryContainer,
        elevation: 2,
        shadowColor: Colors.black26,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStatePropertyAll(text.labelMedium),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      listTileTheme: ListTileThemeData(
        minVerticalPadding: 12,
        titleTextStyle: text.titleSmall,
        subtitleTextStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
    );
  }
}
