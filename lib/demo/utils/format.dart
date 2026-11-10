/// Türkçe tarih/saat biçimlendirme yardımcıları.
library;

const _gunlerKisa = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
const _gunlerUzun = [
  'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'
];
const _aylar = [
  'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
  'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
];

String _two(int n) => n.toString().padLeft(2, '0');

String gunKisa(DateTime d) => _gunlerKisa[d.weekday - 1];
String gunUzun(DateTime d) => _gunlerUzun[d.weekday - 1];

/// 10 Kasım 2026
String tarih(DateTime d) => '${d.day} ${_aylar[d.month - 1]} ${d.year}';

/// 10 Kasım Salı
String tarihGun(DateTime d) => '${d.day} ${_aylar[d.month - 1]} ${gunUzun(d)}';

/// 18:30
String saat(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

String saatAraligi(DateTime start, DateTime end) =>
    '${saat(start)} – ${saat(end)}';

DateTime gunBasi(DateTime d) => DateTime(d.year, d.month, d.day);

bool ayniGun(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Üyelik durumunu kısa metin olarak verir.
String kalanGunMetni(int daysLeft) {
  if (daysLeft < 0) return 'Süresi doldu';
  if (daysLeft == 0) return 'Bugün bitiyor';
  return '$daysLeft gün kaldı';
}
