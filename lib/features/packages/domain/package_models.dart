/// Ders sayısına göre geçerlilik günü. YALNIZCA tanım formunda ön doldurma/gönderme için.
int validityDaysFor(int sessionCount) => sessionCount <= 12 ? 30 : 40;

const allowedSessionCounts = [8, 12, 16, 20];

DateTime _dt(dynamic v) => DateTime.parse(v as String).toLocal();

class Category {
  const Category({required this.id, required this.name, required this.isActive});
  final String id;
  final String name;
  final bool isActive;

  factory Category.fromJson(Map<String, dynamic> j) => Category(
        id: j['id'] as String,
        name: (j['name'] as String?) ?? '',
        isActive: (j['is_active'] as bool?) ?? true,
      );
}

class PackageDefinition {
  const PackageDefinition({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.sessionCount,
    required this.validityDays,
    required this.price,
    required this.isActive,
    this.categoryName,
  });
  final String id;
  final String categoryId;
  final String? categoryName;
  final String name;
  final int sessionCount;
  final int validityDays;
  final double price;
  final bool isActive;

  factory PackageDefinition.fromJson(Map<String, dynamic> j) {
    final cat = j['categories'];
    return PackageDefinition(
      id: j['id'] as String,
      categoryId: j['category_id'] as String,
      categoryName: cat is Map ? cat['name'] as String? : null,
      name: (j['name'] as String?) ?? '',
      sessionCount: (j['session_count'] as num).toInt(),
      validityDays: (j['validity_days'] as num).toInt(),
      price: (j['price'] as num).toDouble(),
      isActive: (j['is_active'] as bool?) ?? true,
    );
  }
}

class MemberSummary {
  const MemberSummary({required this.id, required this.fullName});
  final String id;
  final String fullName;

  factory MemberSummary.fromJson(Map<String, dynamic> j) => MemberSummary(
        id: j['id'] as String,
        fullName: (j['full_name'] as String?) ?? '',
      );
}

class PackageFreeze {
  const PackageFreeze({
    required this.id,
    required this.memberPackageId,
    required this.startsAt,
    required this.endsAt,
    required this.days,
    this.note,
  });
  final String id;
  final String memberPackageId;
  final DateTime startsAt;

  /// Dışlayıcı bitiş.
  final DateTime endsAt;
  final int days;
  final String? note;

  bool coversNow(DateTime now) => !startsAt.isAfter(now) && now.isBefore(endsAt);

  factory PackageFreeze.fromJson(Map<String, dynamic> j) => PackageFreeze(
        id: j['id'].toString(),
        memberPackageId: (j['member_package_id'] as String?) ?? '',
        startsAt: _dt(j['starts_at']),
        endsAt: _dt(j['ends_at']),
        days: (j['days'] as num?)?.toInt() ?? 0,
        note: j['note'] as String?,
      );
}

enum PackageDisplayStatus {
  active('Aktif'),
  frozen('Donduruldu'),
  expired('Süresi doldu'),
  terminated('Erken sonlandırıldı');

  const PackageDisplayStatus(this.label);
  final String label;
}

class MemberPackage {
  const MemberPackage({
    required this.id,
    required this.memberId,
    required this.definitionId,
    required this.categoryId,
    required this.totalCredits,
    required this.remainingCredits,
    required this.pricePaid,
    required this.activatedAt,
    required this.endsAt,
    required this.status,
    this.definitionName,
    this.categoryName,
    this.freezes = const [],
  });
  final String id;
  final String memberId;
  final String definitionId;
  final String categoryId;
  final String? definitionName;
  final String? categoryName;
  final int totalCredits;
  final int remainingCredits;
  final double pricePaid;
  final DateTime activatedAt;
  final DateTime endsAt;

  /// 'active' | 'expired' | 'terminated'
  final String status;
  final List<PackageFreeze> freezes;

  factory MemberPackage.fromJson(Map<String, dynamic> j) {
    final def = j['package_definitions'];
    final cat = j['categories'];
    final fr = j['package_freezes'];
    return MemberPackage(
      id: j['id'] as String,
      memberId: j['member_id'] as String,
      definitionId: j['definition_id'] as String,
      categoryId: j['category_id'] as String,
      definitionName: def is Map ? def['name'] as String? : null,
      categoryName: cat is Map ? cat['name'] as String? : null,
      totalCredits: (j['total_credits'] as num).toInt(),
      remainingCredits: (j['remaining_credits'] as num).toInt(),
      pricePaid: (j['price_paid'] as num).toDouble(),
      activatedAt: _dt(j['activated_at']),
      endsAt: _dt(j['ends_at']),
      status: (j['status'] as String?) ?? 'active',
      freezes: fr is List
          ? fr
              .map((e) =>
                  PackageFreeze.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList()
          : const [],
    );
  }

  /// Sunucuda durum tembel güncellenir; süresi geçen aktif paket "süresi doldu" sayılır.
  bool isCurrentlyActive(DateTime now) =>
      status == 'active' && endsAt.isAfter(now);

  PackageDisplayStatus displayStatus(DateTime now,
      {List<PackageFreeze>? freezes}) {
    if (status == 'terminated') return PackageDisplayStatus.terminated;
    if (status == 'expired' || !endsAt.isAfter(now)) {
      return PackageDisplayStatus.expired;
    }
    if ((freezes ?? this.freezes).any((f) => f.coversNow(now))) {
      return PackageDisplayStatus.frozen;
    }
    return PackageDisplayStatus.active;
  }

  int daysLeft(DateTime now) {
    final d = (endsAt.difference(now).inMinutes / (60 * 24)).ceil();
    return d < 0 ? 0 : d;
  }
}

class CreditLedgerEntry {
  const CreditLedgerEntry({
    required this.id,
    required this.entryType,
    required this.delta,
    required this.balanceAfter,
    required this.createdAt,
    this.note,
  });
  final String id;
  final String entryType;
  final int delta;
  final int balanceAfter;
  final DateTime createdAt;
  final String? note;

  String get label => switch (entryType) {
        'grant' => 'Paket tanımlandı',
        'booking' => 'Rezervasyon',
        'refund' => 'İade',
        'transfer_out' => 'Aktarım (eski paketten çıkış)',
        'transfer_in' => 'Aktarım (yeni pakete giriş)',
        'adjustment' => 'Düzeltme',
        _ => entryType,
      };

  factory CreditLedgerEntry.fromJson(Map<String, dynamic> j) =>
      CreditLedgerEntry(
        id: j['id'].toString(),
        entryType: (j['entry_type'] as String?) ?? '',
        delta: (j['delta'] as num).toInt(),
        balanceAfter: (j['balance_after'] as num).toInt(),
        createdAt: _dt(j['created_at']),
        note: j['note'] as String?,
      );
}
