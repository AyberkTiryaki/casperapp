import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Yazı tipleri: gövde Barlow, başlıklar Barlow Condensed (sportif, dar ve kalın).
class AppFonts {
  static const body = 'Barlow';
  static const display = 'BarlowCondensed';
}

class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final isDark = b == Brightness.dark;

    final bg = isDark ? AppColors.night : AppColors.mist;
    final card = isDark ? AppColors.nightCard : AppColors.surfaceLight;
    final raised = isDark ? AppColors.nightRaised : AppColors.raisedLight;
    final outline = isDark ? AppColors.nightOutline : AppColors.outlineLight;
    final text = isDark ? AppColors.nightText : AppColors.ink;
    final muted = isDark ? AppColors.nightMuted : AppColors.inkMuted;
    final primary = isDark ? AppColors.electricBlue : AppColors.brandBlue;
    final link = isDark ? AppColors.skyBlue : AppColors.brandBlue;

    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.brandBlue,
          brightness: b,
          dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
        ).copyWith(
          primary: primary,
          onPrimary: Colors.white,
          primaryContainer: isDark
              ? const Color(0xFF15307F)
              : const Color(0xFFDCE6FF),
          onPrimaryContainer: isDark ? Colors.white : AppColors.deepBlue,
          secondary: AppColors.cyan,
          onSecondary: AppColors.night,
          surface: bg,
          onSurface: text,
          onSurfaceVariant: muted,
          surfaceContainerLowest: bg,
          surfaceContainerLow: card,
          surfaceContainer: card,
          surfaceContainerHigh: raised,
          surfaceContainerHighest: raised,
          outline: outline,
          outlineVariant: outline,
          error: AppColors.danger,
        );

    final base = ThemeData(brightness: b, useMaterial3: true);
    TextStyle display(TextStyle? s, double size, {double spacing = 0.5}) =>
        (s ?? const TextStyle()).copyWith(
          fontFamily: AppFonts.display,
          fontWeight: FontWeight.w700,
          fontSize: size,
          letterSpacing: spacing,
          height: 1.1,
        );
    final bodyText = base.textTheme.apply(
      fontFamily: AppFonts.body,
      bodyColor: text,
      displayColor: text,
    );
    final textTheme = bodyText.copyWith(
      displaySmall: display(bodyText.displaySmall, 36),
      headlineLarge: display(bodyText.headlineLarge, 32),
      headlineMedium: display(bodyText.headlineMedium, 28),
      headlineSmall: display(bodyText.headlineSmall, 26),
      titleLarge: display(bodyText.titleLarge, 22, spacing: 0.3),
      titleMedium: bodyText.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: bodyText.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      bodyMedium: bodyText.bodyMedium?.copyWith(color: text),
      bodySmall: bodyText.bodySmall?.copyWith(color: muted),
    );

    final radius12 = BorderRadius.circular(12);
    final border = OutlineInputBorder(
      borderRadius: radius12,
      borderSide: BorderSide(color: outline),
    );
    const buttonText = TextStyle(
      fontFamily: AppFonts.display,
      fontSize: 18,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.2,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      fontFamily: AppFonts.body,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      textTheme: textTheme,
      iconTheme: IconThemeData(color: text),
      dividerTheme: DividerThemeData(color: outline, thickness: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: text),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: raised,
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: primary, width: 2),
        ),
        labelStyle: TextStyle(color: muted),
        floatingLabelStyle: TextStyle(color: link),
        prefixIconColor: muted,
        suffixIconColor: muted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: radius12),
          textStyle: buttonText,
          elevation: 0,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: radius12),
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: radius12),
          side: BorderSide(
            color: isDark ? AppColors.nightOutline : outline,
            width: 1.5,
          ),
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: link,
          textStyle: const TextStyle(
            fontFamily: AppFonts.body,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        extendedTextStyle: buttonText,
      ),
      cardTheme: CardThemeData(
        color: card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: outline),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: link,
        textColor: text,
        subtitleTextStyle: TextStyle(
          fontFamily: AppFonts.body,
          color: muted,
          fontSize: 14,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: raised,
        selectedColor: primary,
        side: BorderSide(color: outline),
        labelStyle: TextStyle(
          fontFamily: AppFonts.body,
          color: text,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: const TextStyle(
          fontFamily: AppFonts.body,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        checkmarkColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: link,
        unselectedLabelColor: muted,
        indicatorColor: primary,
        dividerColor: outline,
        labelStyle: buttonText.copyWith(fontSize: 16),
        unselectedLabelStyle: buttonText.copyWith(fontSize: 16),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: card,
        indicatorColor: primary.withValues(alpha: 0.25),
        surfaceTintColor: Colors.transparent,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? primary : raised,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? Colors.white : text,
          ),
          side: WidgetStatePropertyAll(BorderSide(color: outline)),
        ),
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? primary : raised,
        ),
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : muted,
        ),
        trackOutlineColor: WidgetStatePropertyAll(outline),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) =>
              s.contains(WidgetState.selected) ? primary : Colors.transparent,
        ),
        checkColor: const WidgetStatePropertyAll(Colors.white),
        side: BorderSide(color: muted, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: raised,
        circularTrackColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: outline),
        ),
        titleTextStyle: textTheme.titleLarge?.copyWith(color: text),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: muted,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? AppColors.nightRaised : AppColors.ink,
        contentTextStyle: const TextStyle(
          fontFamily: AppFonts.body,
          color: Colors.white,
          fontSize: 15,
        ),
        actionTextColor: AppColors.skyBlue,
        shape: RoundedRectangleBorder(borderRadius: radius12),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: primary,
        headerForegroundColor: Colors.white,
      ),
      timePickerTheme: TimePickerThemeData(backgroundColor: card),
      popupMenuTheme: PopupMenuThemeData(
        color: raised,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: radius12,
          side: BorderSide(color: outline),
        ),
      ),
    );
  }
}
