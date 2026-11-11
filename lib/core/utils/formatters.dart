/// 31.12.2026 biçimi.
String formatDate(DateTime d) {
  final l = d.toLocal();
  return '${l.day.toString().padLeft(2, '0')}.${l.month.toString().padLeft(2, '0')}.${l.year}';
}

/// 'YYYY-MM-DD' (RPC parametreleri için; yerel gün).
String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// 1.250 ₺ / 1.250,50 ₺
String formatTl(num value) {
  final cents = (value * 100).round();
  final neg = cents < 0;
  final abs = cents.abs();
  final whole = (abs ~/ 100).toString();
  final frac = abs % 100;
  final buf = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) buf.write('.');
    buf.write(whole[i]);
  }
  final fracStr = frac == 0 ? '' : ',${frac.toString().padLeft(2, '0')}';
  return '${neg ? '-' : ''}$buf$fracStr ₺';
}

/// Virgül veya nokta ile girilen ondalık sayı.
double? parseDecimal(String? v) =>
    double.tryParse((v ?? '').trim().replaceAll(',', '.'));

/// 09:30 biçimi.
String formatTime(DateTime d) {
  final l = d.toLocal();
  return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
}
