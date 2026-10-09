import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFFE77D63);
  static const ink = Color(0xFF343D34);
  static const canvas = Color(0xFFFAF8F3);
  static const muted = Color(0xFF899083);
  static const photoPlaceholder = Color(0xFFE9E8DA);
  static const success = Color(0xFF6D8161);
  static const sidebar = Color(0xFFF5F2E9);
  static const sidebarBorder = Color(0xFFE7E5DB);
  static const selected = Color(0xFFF7E3D9);
  static const accentSurface = Color(0xFFEAECDD);
  static const accent = Color(0xFF7C8A65);
  static const avatar = Color(0xFFE7C6AD);
  static const divider = Color(0xFFE9E7DE);
  static const quietSurface = Color(0xFFF4F2EB);
  static const cardBorder = Color(0xFFE5E3DA);
  static const daySurface = Color(0xFFF1F3E9);
  static const photoSurface = Color(0xFFF1F0EB);
  static const noticeSurface = Color(0xFFFFF0DE);
  static const noticeInk = Color(0xFF946B36);
  static const ownMessage = Color(0xFFF6DFD5);
  static const photoViewer = Color(0xFF161916);
  static const anniversary = Color(0xFFFFE59B);
  static const today = Color(0xFFFFF0EB);
  static const scrimLight = Color(0x14000000);
  static const transparent = Color(0x00000000);
  static const scrimDark = Color(0xCC000000);
  static const surface = Color(0xFFFFFFFF);
  static const onPhotoMuted = Color(0xB3FFFFFF);
}

const coral = AppColors.primary,
    ink = AppColors.ink,
    cream = AppColors.canvas,
    muted = AppColors.muted;

class AppText {
  static const minimumSize = 13.0;
  static const captionStrong = TextStyle(
    fontSize: minimumSize,
    fontWeight: FontWeight.w600,
  );
  static const caption = TextStyle(fontSize: minimumSize);
  static const captionMuted = TextStyle(
    fontSize: minimumSize,
    color: AppColors.muted,
  );
  static const captionPrimary = TextStyle(
    fontSize: minimumSize,
    color: AppColors.primary,
  );
  static const captionComfortable = TextStyle(
    fontSize: minimumSize,
    height: 1.6,
  );
  static const captionOnPhoto = TextStyle(
    fontSize: minimumSize,
    color: AppColors.surface,
  );
  static const captionBold = TextStyle(
    fontSize: minimumSize,
    fontWeight: FontWeight.bold,
  );
  static const captionMutedComfortable = TextStyle(
    fontSize: minimumSize,
    color: muted,
    height: 1.7,
  );
  static const captionNoticeComfortable = TextStyle(
    fontSize: minimumSize,
    height: 1.7,
    color: AppColors.noticeInk,
  );
  static const captionSuccessBold = TextStyle(
    fontSize: minimumSize,
    color: AppColors.success,
    fontWeight: FontWeight.w700,
  );
}

final petTheme = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: cream,
  colorScheme: ColorScheme.fromSeed(
    seedColor: coral,
    primary: coral,
    surface: AppColors.surface,
  ),
  fontFamily: 'Pretendard',
  textTheme: const TextTheme(
    displayLarge: TextStyle(fontSize: 57),
    displayMedium: TextStyle(fontSize: 45),
    displaySmall: TextStyle(fontSize: 36),
    headlineLarge: TextStyle(fontSize: 32),
    headlineSmall: TextStyle(fontSize: 24),
    titleLarge: TextStyle(fontSize: 22),
    titleMedium: TextStyle(fontSize: 16),
    titleSmall: TextStyle(fontSize: 14),
    bodyLarge: TextStyle(fontSize: 16, color: ink),
    labelLarge: TextStyle(fontSize: 14),
    bodySmall: AppText.caption,
    labelSmall: AppText.caption,
    labelMedium: AppText.caption,
    bodyMedium: TextStyle(fontSize: 14, color: ink),
    headlineMedium: TextStyle(
      fontSize: 28,
      color: ink,
      fontWeight: FontWeight.w800,
    ),
  ),
  navigationBarTheme: const NavigationBarThemeData(
    labelTextStyle: WidgetStatePropertyAll(AppText.captionStrong),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: cream,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  ),
);
