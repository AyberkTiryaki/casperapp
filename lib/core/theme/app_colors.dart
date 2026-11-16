import 'package:flutter/material.dart';

/// Tüm marka renkleri burada; tek yerden değiştirilebilir.
///
/// Kimlik: logodaki kraliyet ve elektrik mavisi.
/// Varsayılan açık tema (ferah, mavi-beyaz); kullanıcı profilden koyu temayı seçebilir.
/// Ekranlarda sabit renk yerine `context.palette` kullanın; tema değişince doğru tonu verir.
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
  // Eskisine göre bir tık aydınlatıldı: simsiyah yerine lacivert gece.
  static const night = Color(0xFF0C1222); // sayfa zemini
  static const nightCard = Color(0xFF141D38); // kart
  static const nightRaised = Color(
    0xFF1D2852,
  ); // giriş alanı, yükseltilmiş yüzey
  static const nightOutline = Color(0xFF2A3870);
  static const nightText = Color(0xFFEEF2FF);
  static const nightMuted = Color(0xFF9AA8D0);

  // --- Açık tema zeminleri ---------------------------------------------
  static const mist = Color(0xFFF3F6FD); // sayfa zemini: çok hafif mavi
  static const surfaceLight = Color(0xFFFFFFFF); // kart
  static const raisedLight = Color(
    0xFFEAF0FC,
  ); // giriş alanı, ilerleme izi, gün kutusu
  static const outlineLight = Color(0xFFDCE3F4);
  static const ink = Color(0xFF0D1430);
  static const inkMuted = Color(0xFF5A6585);

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

/// Temaya duyarlı yüzey ve yazı renkleri.
class AppPalette {
  const AppPalette._(this.isDark);
  final bool isDark;

  Color get background => isDark ? AppColors.night : AppColors.mist;
  Color get card => isDark ? AppColors.nightCard : AppColors.surfaceLight;
  Color get raised => isDark ? AppColors.nightRaised : AppColors.raisedLight;
  Color get outline => isDark ? AppColors.nightOutline : AppColors.outlineLight;
  Color get text => isDark ? AppColors.nightText : AppColors.ink;
  Color get muted => isDark ? AppColors.nightMuted : AppColors.inkMuted;

  /// Mavi yazı, seçili ikon, bağlantı.
  Color get link => isDark ? AppColors.skyBlue : AppColors.brandBlue;

  /// Kahraman başlığı altındaki vurgu yazısı vb.
  Color get accent => isDark ? AppColors.cyan : AppColors.brandBlue;

  /// Açık temada kartlara hafif derinlik; koyu temada gölge yok.
  List<BoxShadow>? get cardShadow => isDark
      ? null
      : const [
          BoxShadow(
            color: Color(0x0F1447C8),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ];
}

extension AppPaletteX on BuildContext {
  AppPalette get palette =>
      AppPalette._(Theme.of(this).brightness == Brightness.dark);
}
