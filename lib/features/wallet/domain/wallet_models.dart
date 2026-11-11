/// numeric sütunları num veya String gelebilir; güvenle double'a çevirir.
double parseMoney(Object? v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString().replaceAll(',', '.')) ?? 0;
}

/// Kullanıcı girdisi için tutar ayrıştırma: en çok 2 ondalık, aksi halde null.
double? parseMoneyInput(String? text) {
  final t = (text ?? '').trim().replaceAll(',', '.');
  if (!RegExp(r'^-?\d+(\.\d{1,2})?$').hasMatch(t)) return null;
  return double.tryParse(t);
}

enum WalletEntryType {
  topup,
  purchase,
  reversal,
  adjustment;

  static WalletEntryType fromString(String? v) => switch (v) {
    'topup' => topup,
    'purchase' => purchase,
    'reversal' => reversal,
    _ => adjustment,
  };

  String get label => switch (this) {
    topup => 'Yükleme',
    purchase => 'Harcama',
    reversal => 'Ters kayıt',
    adjustment => 'Düzeltme',
  };
}

class WalletEntry {
  const WalletEntry({
    required this.id,
    required this.memberId,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    required this.createdAt,
    this.note,
    this.reversesEntryId,
  });

  final int id;
  final String memberId;
  final WalletEntryType type;
  final double amount;
  final double balanceAfter;
  final DateTime createdAt;
  final String? note;
  final int? reversesEntryId;

  factory WalletEntry.fromJson(Map<String, dynamic> j) => WalletEntry(
    id: (j['id'] as num).toInt(),
    memberId: j['member_id'] as String,
    type: WalletEntryType.fromString(j['entry_type'] as String?),
    amount: parseMoney(j['amount']),
    balanceAfter: parseMoney(j['balance_after']),
    createdAt: DateTime.parse(j['created_at'] as String),
    note: j['note'] as String?,
    reversesEntryId: (j['reverses_entry_id'] as num?)?.toInt(),
  );
}

/// Ters kayıt yapılabilir mi? Ters kayıtlar ve zaten ters çevrilmiş hareketler hariç.
bool canReverseEntry(WalletEntry e, Iterable<WalletEntry> all) {
  if (e.type == WalletEntryType.reversal || e.reversesEntryId != null) {
    return false;
  }
  return !all.any((o) => o.reversesEntryId == e.id);
}

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.price,
    required this.isActive,
  });

  final String id;
  final String name;
  final double price;
  final bool isActive;

  factory Product.fromJson(Map<String, dynamic> j) => Product(
    id: j['id'] as String,
    name: j['name'] as String,
    price: parseMoney(j['price']),
    isActive: (j['is_active'] as bool?) ?? true,
  );
}

class Sale {
  const Sale({
    required this.id,
    required this.memberId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.total,
    required this.createdAt,
    this.reversedAt,
  });

  final String id;
  final String memberId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double total;
  final DateTime createdAt;
  final DateTime? reversedAt;

  factory Sale.fromJson(Map<String, dynamic> j) {
    final p = j['products'];
    return Sale(
      id: j['id'] as String,
      memberId: j['member_id'] as String,
      productName: p is Map ? (p['name'] as String? ?? '-') : '-',
      quantity: (j['quantity'] as num).toInt(),
      unitPrice: parseMoney(j['unit_price']),
      total: parseMoney(j['total']),
      createdAt: DateTime.parse(j['created_at'] as String),
      reversedAt: j['reversed_at'] == null
          ? null
          : DateTime.parse(j['reversed_at'] as String),
    );
  }
}
