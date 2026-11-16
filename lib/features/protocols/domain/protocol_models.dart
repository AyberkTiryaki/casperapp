import '../../schedule/domain/schedule_models.dart' show ClassType;

/// Toplam indirim tavanı (referans + protokol), BUSINESS_RULES PR-06.
const maxTotalDiscount = 50;

/// Referans ve protokol indirimini toplar, tavanı uygular (sunucudaki hesapla aynı).
int combinedDiscount(int referralPercent, int protocolPercent) {
  final sum = referralPercent + protocolPercent;
  return sum > maxTotalDiscount ? maxTotalDiscount : sum;
}

/// İndirimli fiyat, 2 ondalık (sunucu: round(price * (100 - oran) / 100, 2)).
double discountedPrice(double listPrice, int percent) =>
    double.parse((listPrice * (100 - percent) / 100).toStringAsFixed(2));

DateTime? _date(dynamic v) => v == null ? null : DateTime.parse(v as String);

/// Kurum protokolü (sendika, dernek vb.).
class Protocol {
  const Protocol({
    required this.id,
    required this.name,
    required this.discountPercent,
    required this.isActive,
    this.validUntil,
    this.note,
  });

  final String id;
  final String name;
  final int discountPercent;
  final bool isActive;

  /// Son geçerli gün (dahil). null = süresiz.
  final DateTime? validUntil;
  final String? note;

  /// Aktif ve son günü geçmemiş mi (yerel güne göre).
  bool isValidOn(DateTime now) {
    if (!isActive) return false;
    final u = validUntil;
    if (u == null) return true;
    final today = DateTime(now.year, now.month, now.day);
    return !DateTime(u.year, u.month, u.day).isBefore(today);
  }

  factory Protocol.fromJson(Map<String, dynamic> j) => Protocol(
    id: j['id'] as String,
    name: (j['name'] as String?) ?? '',
    discountPercent: (j['discount_percent'] as num).toInt(),
    isActive: (j['is_active'] as bool?) ?? true,
    validUntil: _date(j['valid_until']),
    note: j['note'] as String?,
  );
}

class PublicPackage {
  const PublicPackage({
    required this.name,
    required this.sessionCount,
    required this.validityDays,
    required this.price,
  });
  final String name;
  final int sessionCount;
  final int validityDays;
  final double price;

  factory PublicPackage.fromJson(Map<String, dynamic> j) => PublicPackage(
    name: (j['name'] as String?) ?? '',
    sessionCount: (j['session_count'] as num).toInt(),
    validityDays: (j['validity_days'] as num).toInt(),
    price: (j['price'] as num).toDouble(),
  );
}

class PublicCategory {
  const PublicCategory({
    required this.name,
    required this.classType,
    required this.packages,
  });
  final String name;
  final ClassType classType;
  final List<PublicPackage> packages;

  factory PublicCategory.fromJson(Map<String, dynamic> j) => PublicCategory(
    name: (j['name'] as String?) ?? '',
    classType: ClassType.fromString(j['class_type'] as String?),
    packages: ((j['packages'] as List?) ?? const [])
        .map((e) => PublicPackage.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
  );
}

class PublicProtocol {
  const PublicProtocol({
    required this.name,
    required this.discountPercent,
    this.validUntil,
  });
  final String name;
  final int discountPercent;
  final DateTime? validUntil;

  factory PublicProtocol.fromJson(Map<String, dynamic> j) => PublicProtocol(
    name: (j['name'] as String?) ?? '',
    discountPercent: (j['discount_percent'] as num).toInt(),
    validUntil: _date(j['valid_until']),
  );
}

/// Giriş yapmadan görülebilen fiyat listesi (public_price_list).
class PublicPriceList {
  const PublicPriceList({required this.categories, required this.protocols});
  final List<PublicCategory> categories;
  final List<PublicProtocol> protocols;

  bool get isEmpty => categories.isEmpty && protocols.isEmpty;

  factory PublicPriceList.fromJson(Map<String, dynamic> j) => PublicPriceList(
    categories: ((j['categories'] as List?) ?? const [])
        .map(
          (e) => PublicCategory.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList(),
    protocols: ((j['protocols'] as List?) ?? const [])
        .map(
          (e) => PublicProtocol.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList(),
  );
}
