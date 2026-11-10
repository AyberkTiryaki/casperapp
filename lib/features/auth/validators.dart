// Saf doğrulama fonksiyonları; hata varsa Türkçe mesaj, yoksa null döner.

final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

String? validateEmail(String? v) {
  final s = (v ?? '').trim();
  if (s.isEmpty) return 'E-posta gerekli.';
  if (!_emailRe.hasMatch(s)) return 'Geçerli bir e-posta girin.';
  return null;
}

String? validateFullName(String? v) {
  final s = (v ?? '').trim();
  if (s.isEmpty) return 'Ad soyad gerekli.';
  if (s.length < 3) return 'Ad soyad çok kısa.';
  return null;
}

String? validatePassword(String? v) {
  final s = v ?? '';
  if (s.isEmpty) return 'Şifre gerekli.';
  if (s.length < 8) return 'Şifre en az 8 karakter olmalı.';
  return null;
}

String? validatePasswordConfirm(String? v, String password) {
  if ((v ?? '').isEmpty) return 'Şifre tekrarı gerekli.';
  if (v != password) return 'Şifreler eşleşmiyor.';
  return null;
}

String? validateBirthDate(DateTime? d, {DateTime? now}) {
  if (d == null) return 'Doğum tarihi gerekli.';
  final today = now ?? DateTime.now();
  if (!d.isBefore(DateTime(today.year, today.month, today.day))) {
    return 'Doğum tarihi geçmişte olmalı.';
  }
  return null;
}

int? parseHeight(String? v) => int.tryParse((v ?? '').trim());

String? validateHeight(String? v) {
  if ((v ?? '').trim().isEmpty) return 'Boy gerekli.';
  final h = parseHeight(v);
  if (h == null) return 'Boy tam sayı olmalı.';
  if (h < 100 || h > 250) return 'Boy 100-250 cm arasında olmalı.';
  return null;
}

/// Virgül veya nokta ile girilen ondalık sayıyı çözer.
double? parseWeight(String? v) =>
    double.tryParse((v ?? '').trim().replaceAll(',', '.'));

String? validateWeight(String? v) {
  if ((v ?? '').trim().isEmpty) return 'Kilo gerekli.';
  final w = parseWeight(v);
  if (w == null) return 'Geçerli bir sayı girin.';
  if (w < 30 || w > 300) return 'Kilo 30-300 kg arasında olmalı.';
  return null;
}
