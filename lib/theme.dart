import 'dart:ui' show FontVariation;

import 'package:flutter/material.dart';

/// Roll 의 색. 크림색 바탕에 잉크색 글씨, 포인트는 금색 마름모 하나.
class RollColors {
  static const ground = Color(0xFFEBE9E4);
  static const ink = Color(0xFF1C1B19);
  static const muted = Color(0xFF8A867E);
  static const hair = Color(0xFFCFCBC3);
  static const gold = Color(0xFFA8884E);
  static const mat = Color(0xFFFBFAF7);
  static const photoBg = Color(0xFFDDD9D1);
}

/// 영문 숫자 · 라벨용 이탤릭 세리프 (Cormorant Garamond Italic).
TextStyle serif(double size, {Color color = RollColors.ink, double weight = 400, double spacing = 0, double height = 1}) {
  return TextStyle(
    fontFamily: 'Cormorant',
    fontStyle: FontStyle.italic,
    fontSize: size,
    color: color,
    letterSpacing: spacing,
    height: height,
    fontVariations: [FontVariation('wght', weight)],
  );
}

/// 한글 본문용 명조 (고운바탕).
TextStyle body(double size, {Color color = RollColors.ink, double spacing = -0.2, double height = 1.3}) {
  return TextStyle(
    fontFamily: 'GowunBatang',
    fontSize: size,
    color: color,
    letterSpacing: spacing,
    height: height,
  );
}

ThemeData rollTheme() {
  return ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: RollColors.ground,
    fontFamily: 'GowunBatang',
    colorScheme: ColorScheme.fromSeed(
      seedColor: RollColors.gold,
      brightness: Brightness.light,
      surface: RollColors.ground,
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    dialogTheme: const DialogThemeData(
      backgroundColor: RollColors.mat,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: RollColors.ink,
      behavior: SnackBarBehavior.floating,
      contentTextStyle: body(14, color: RollColors.mat),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    ),
  );
}
