import 'package:caspertrainingstudio/features/packages/data/package_repository.dart';
import 'package:caspertrainingstudio/features/packages/domain/package_models.dart';

class AssignCall {
  AssignCall(
    this.memberId,
    this.definitionId,
    this.key,
    this.replace, [
    this.discount = 0,
  ]);
  final String memberId, definitionId, key;
  final bool replace;
  final int discount;
}

class FakePackageRepository implements PackageRepository {
  List<Category> cats = [];
  List<PackageDefinition> defs = [];
  List<MemberPackage> pkgs = [];
  final assignCalls = <AssignCall>[];
  final createdDefs = <Map<String, Object?>>[];
  final createdCats = <String>[];
  Object? assignErrorOnFirst;

  @override
  Future<List<Category>> categories() async => cats;
  @override
  Future<void> createCategory({
    required String name,
    required bool isActive,
  }) async => createdCats.add(name);
  @override
  Future<void> updateCategory({
    required String id,
    required String name,
    required bool isActive,
  }) async {}
  @override
  Future<List<PackageDefinition>> definitions() async => defs;
  @override
  Future<void> createDefinition({
    required String categoryId,
    required String name,
    required int sessionCount,
    required int validityDays,
    required double price,
    required bool isActive,
  }) async {
    createdDefs.add({
      'categoryId': categoryId,
      'name': name,
      'sessionCount': sessionCount,
      'validityDays': validityDays,
      'price': price,
    });
  }

  @override
  Future<void> updateDefinition({
    required String id,
    required String categoryId,
    required String name,
    required int sessionCount,
    required int validityDays,
    required double price,
    required bool isActive,
  }) async {}
  @override
  Future<List<MemberSummary>> searchMembers(String query) async => [];
  @override
  Future<List<MemberPackage>> memberPackages(String memberId) async => pkgs;
  @override
  Future<List<MemberPackage>> myPackages() async => pkgs;
  @override
  Future<List<PackageFreeze>> freezes(String packageId) async => [];
  @override
  Future<List<CreditLedgerEntry>> ledger(String packageId) async => [];
  @override
  Future<void> assignPackage({
    required String memberId,
    required String definitionId,
    required String idempotencyKey,
    required bool replaceExisting,
    int discountPercent = 0,
  }) async {
    assignCalls.add(
      AssignCall(
        memberId,
        definitionId,
        idempotencyKey,
        replaceExisting,
        discountPercent,
      ),
    );
    if (assignCalls.length == 1 && assignErrorOnFirst != null) {
      throw assignErrorOnFirst!;
    }
  }

  @override
  Future<void> freezePackage({
    required String packageId,
    required DateTime startDate,
    required DateTime endDate,
    String? note,
  }) async {}

  @override
  Future<void> endFreeze(String freezeId, {DateTime? lastDay}) async {}
  @override
  Future<void> adjustCredits(String packageId, int delta, String note) async {}
}

MemberPackage samplePackage({
  String status = 'active',
  Duration endsIn = const Duration(days: 20),
  int remaining = 5,
  List<PackageFreeze> freezes = const [],
}) {
  final now = DateTime.now();
  return MemberPackage(
    id: 'p1',
    memberId: 'm1',
    definitionId: 'd1',
    categoryId: 'c1',
    definitionName: '8 Derslik Paket',
    categoryName: 'Reformer',
    totalCredits: 8,
    remainingCredits: remaining,
    pricePaid: 4000,
    activatedAt: now.subtract(const Duration(days: 10)),
    endsAt: now.add(endsIn),
    status: status,
    freezes: freezes,
  );
}
