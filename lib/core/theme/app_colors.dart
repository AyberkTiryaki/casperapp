import 'package:flutter/material.dart';

/// Tüm marka renkleri burada; tek yerden değiştirilebilir.
class AppColors {
  static const charcoal = Color(0xFF14161A);
  static const ghostWhite = Color(0xFFF5F6F8);

  /// Kurumsal mavi (logodaki kraliyet mavisi). Açık temada ana renk.
  static const brandBlue = Color(0xFF1447C8);

  /// Koyu temada okunurluk için aynı mavinin açık tonu.
  static const brandBlueLight = Color(0xFF6A97FF);
  static const onBrandBlueLight = Color(0xFF0A1A40);

  /// Logonun koyu zemini; açılış ekranı ve simge arka planıyla aynı.
  static const logoBackground = Color(0xFF1A1B1E);

  static const accent = brandBlue;

  static const surfaceLight = Color(0xFFFFFFFF);
  static const surfaceDark = Color(0xFF1D2025);
  static const outlineLight = Color(0xFFD9DCE2);
  static const outlineDark = Color(0xFF343840);
  static const success = Color(0xFF2E9E6B);
  static const warning = Color(0xFFE0A100);
  static const danger = Color(0xFFD64545);
}
