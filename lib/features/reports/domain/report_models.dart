import '../../wallet/domain/wallet_models.dart' show parseMoney;

/// Rapor tarih aralığı (iki uç dahil, yalnızca gün).
class DateRange {
  const DateRange(this.from, this.to);

  final DateTime from;
  final DateTime to;

  @override
  bool operator ==(Object other) =>
      other is DateRange && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);
}

/// Bu ayın ilk ve son günü.
DateRange currentMonthRange(DateTime now) => DateRange(
  DateTime(now.year, now.month, 1),
  DateTime(now.year, now.month + 1, 0),
);

/// Geçen ayın ilk ve son günü.
DateRange previousMonthRange(DateTime now) => DateRange(
  DateTime(now.year, now.month - 1, 1),
  DateTime(now.year, now.month, 0),
);

/// Bugün dahil son [n] gün.
DateRange lastNDaysRange(DateTime now, int n) => DateRange(
  DateTime(now.year, now.month, now.day - (n - 1)),
  DateTime(now.year, now.month, now.day),
);

/// 35 -> "35 %", 35.5 -> "35,5 %".
String formatPercent(num value) {
  final rounded = (value * 10).round() / 10;
  final text = rounded == rounded.roundToDouble()
      ? rounded.round().toString()
      : rounded.toString().replaceAll('.', ',');
  return '$text %';
}

/// katıldı / (katıldı + gelmedi) yüzde olarak; payda 0 ise null.
double? attendanceRateOf(int attended, int noShow) {
  final d = attended + noShow;
  return d == 0 ? null : attended * 100 / d;
}

int _int(Object? v) {
  if (v == null) return 0;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ??
      double.tryParse(v.toString())?.toInt() ??
      0;
}

Map<String, dynamic> _map(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

List<Map<String, dynamic>> _list(Object? v) => v is List
    ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : <Map<String, dynamic>>[];

class PackageSalesStats {
  const PackageSalesStats({
    this.count = 0,
    this.total = 0,
    this.listTotal = 0,
    this.discountTotal = 0,
    this.discountedCount = 0,
  });

  final int count;
  final double total;
  final double listTotal;
  final double discountTotal;
  final int discountedCount;

  factory PackageSalesStats.fromJson(Map<String, dynamic> j) =>
      PackageSalesStats(
        count: _int(j['count']),
        total: parseMoney(j['total']),
        listTotal: parseMoney(j['list_total']),
        discountTotal: parseMoney(j['discount_total']),
        discountedCount: _int(j['discounted_count']),
      );
}

class ProductSalesStats {
  const ProductSalesStats({
    this.count = 0,
    this.quantity = 0,
    this.total = 0,
    this.reversedCount = 0,
  });

  final int count;
  final int quantity;
  final double total;
  final int reversedCount;

  factory ProductSalesStats.fromJson(Map<String, dynamic> j) =>
      ProductSalesStats(
        count: _int(j['count']),
        quantity: _int(j['quantity']),
        total: parseMoney(j['total']),
        reversedCount: _int(j['reversed_count']),
      );
}

class TopupStats {
  const TopupStats({this.count = 0, this.total = 0});

  final int count;
  final double total;

  factory TopupStats.fromJson(Map<String, dynamic> j) =>
      TopupStats(count: _int(j['count']), total: parseMoney(j['total']));
}

class MemberStats {
  const MemberStats({this.newCount = 0, this.activeWithPackage = 0});

  final int newCount;
  final int activeWithPackage;

  factory MemberStats.fromJson(Map<String, dynamic> j) => MemberStats(
    newCount: _int(j['new']),
    activeWithPackage: _int(j['active_with_package']),
  );
}

class ClassStats {
  const ClassStats({
    this.held = 0,
    this.upcoming = 0,
    this.cancelled = 0,
    this.capacity = 0,
    this.booked = 0,
    this.occupancyPct = 0,
  });

  final int held;
  final int upcoming;
  final int cancelled;
  final int capacity;
  final int booked;
  final double occupancyPct;

  factory ClassStats.fromJson(Map<String, dynamic> j) => ClassStats(
    held: _int(j['held']),
    upcoming: _int(j['upcoming']),
    cancelled: _int(j['cancelled']),
    capacity: _int(j['capacity']),
    booked: _int(j['booked']),
    occupancyPct: parseMoney(j['occupancy_pct']),
  );
}

class AttendanceStats {
  const AttendanceStats({this.attended = 0, this.noShow = 0});

  final int attended;
  final int noShow;

  /// Katılım oranı (yüzde); veri yoksa null.
  double? get attendanceRate => attendanceRateOf(attended, noShow);

  factory AttendanceStats.fromJson(Map<String, dynamic> j) => AttendanceStats(
    attended: _int(j['attended']),
    noShow: _int(j['no_show']),
  );
}

class TrainerStats {
  const TrainerStats({
    required this.trainerId,
    required this.fullName,
    this.classCount = 0,
    this.capacity = 0,
    this.booked = 0,
    this.attended = 0,
    this.noShow = 0,
  });

  final String trainerId;
  final String fullName;
  final int classCount;
  final int capacity;
  final int booked;
  final int attended;
  final int noShow;

  factory TrainerStats.fromJson(Map<String, dynamic> j) => TrainerStats(
    trainerId: (j['trainer_id'] ?? '').toString(),
    fullName: (j['full_name'] as String?) ?? '-',
    classCount: _int(j['class_count']),
    capacity: _int(j['capacity']),
    booked: _int(j['booked']),
    attended: _int(j['attended']),
    noShow: _int(j['no_show']),
  );
}

class TopProduct {
  const TopProduct({
    required this.productId,
    required this.name,
    this.quantity = 0,
    this.total = 0,
  });

  final String productId;
  final String name;
  final int quantity;
  final double total;

  factory TopProduct.fromJson(Map<String, dynamic> j) => TopProduct(
    productId: (j['product_id'] ?? '').toString(),
    name: (j['name'] as String?) ?? '-',
    quantity: _int(j['quantity']),
    total: parseMoney(j['total']),
  );
}

class AdminReport {
  const AdminReport({
    this.packageSales = const PackageSalesStats(),
    this.productSales = const ProductSalesStats(),
    this.walletTopups = const TopupStats(),
    this.members = const MemberStats(),
    this.classes = const ClassStats(),
    this.attendance = const AttendanceStats(),
    this.trainers = const [],
    this.topProducts = const [],
    this.from,
    this.to,
  });

  final String? from;
  final String? to;
  final PackageSalesStats packageSales;
  final ProductSalesStats productSales;
  final TopupStats walletTopups;
  final MemberStats members;
  final ClassStats classes;
  final AttendanceStats attendance;
  final List<TrainerStats> trainers;
  final List<TopProduct> topProducts;

  factory AdminReport.fromJson(Map<String, dynamic> j) => AdminReport(
    from: j['from'] as String?,
    to: j['to'] as String?,
    packageSales: PackageSalesStats.fromJson(_map(j['package_sales'])),
    productSales: ProductSalesStats.fromJson(_map(j['product_sales'])),
    walletTopups: TopupStats.fromJson(_map(j['wallet_topups'])),
    members: MemberStats.fromJson(_map(j['members'])),
    classes: ClassStats.fromJson(_map(j['classes'])),
    attendance: AttendanceStats.fromJson(_map(j['attendance'])),
    trainers: _list(j['trainers']).map(TrainerStats.fromJson).toList(),
    topProducts: _list(j['top_products']).map(TopProduct.fromJson).toList(),
  );
}
