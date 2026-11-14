import 'package:flutter/material.dart';

/// Tüm marka renkleri burada; tek yerden değiştirilebilir.
///
/// Kimlik: logodaki gibi gece mavisi zemin üzerinde elektrik mavisi.
/// Uygulama varsayılan olarak koyu temada açılır (bkz. main.dart).
class AppColors {
  // --- Marka mavileri ---------------------------------------------------
  /// Logodaki kraliyet mavisi. Açık temada ana renk.
  static const brandBlue = Color(0xFF1447C8);

  /// Koyu temada ana renk: dolgulu buton, seçili öğe (beyaz yazı 4.5:1).
  static const electricBlue = Color(0xFF2F6BFF);

  /// Koyu zeminde mavi yazı ve bağlantılar (okunur açık ton).
  static const skyBlue = Color(0xFF8AB0FF);

  /// Vurgu: rozet, ilerleme, küçük ışıltılar.
  static const cyan = Color(0xFF3CC8FF);

  /// Kahraman başlığının en koyu ucu.
  static const deepBlue = Color(0xFF0B2370);

  // --- Koyu tema zeminleri (gece mavisi) -------------------------------
  static const night = Color(0xFF070B16); // sayfa zemini
  static const nightCard = Color(0xFF0E1530); // kart
  static const nightRaised = Color(
    0xFF16204A,
  ); // giriş alanı, yükseltilmiş yüzey
  static const nightOutline = Color(0xFF243266);
  static const nightText = Color(0xFFEEF2FF);
  static const nightMuted = Color(0xFF9AA8D0);

  // --- Açık tema zeminleri ---------------------------------------------
  static const mist = Color(0xFFF2F5FD);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const outlineLight = Color(0xFFD5DDF2);
  static const ink = Color(0xFF0D1430);

  /// Logonun koyu zemini; açılış ekranı ve simge arka planıyla aynı.
  static const logoBackground = Color(0xFF1A1B1E);

  // --- Durum renkleri ---------------------------------------------------
  static const success = Color(0xFF2E9E6B);
  static const warning = Color(0xFFE0A100);
  static const danger = Color(0xFFE5484D);

  // --- Eski adlar (mevcut ekranlar kullanıyor) --------------------------
  static const charcoal = night;
  static const ghostWhite = nightText;
  static const surfaceDark = nightCard;
  static const outlineDark = nightOutline;
  static const accent = brandBlue;
  static const brandBlueLight = skyBlue;
  static const onBrandBlueLight = Color(0xFF0A1A40);
}

/// Marka degradeleri.
class AppGradients {
  /// Buton, rozet ve ikon kutuları.
  static const brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.brandBlue, AppColors.electricBlue],
  );

  /// Ana sayfa kahraman başlığı.
  static const hero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.deepBlue, AppColors.brandBlue, AppColors.electricBlue],
    stops: [0, 0.55, 1],
  );
}
