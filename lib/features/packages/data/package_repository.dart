import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/supabase.dart';
import '../../../core/utils/formatters.dart';
import '../../schedule/domain/schedule_models.dart' show ClassType;
import '../domain/package_models.dart';

abstract class PackageRepository {
  Future<List<Category>> categories();
  Future<void> createCategory({
    required String name,
    required bool isActive,
    required ClassType classType,
  });
  Future<void> updateCategory({
    required String id,
    required String name,
    required bool isActive,
    required ClassType classType,
  });

  Future<List<PackageDefinition>> definitions();
  Future<void> createDefinition({
    required String categoryId,
    required String name,
    required int sessionCount,
    required int validityDays,
    required double price,
    required bool isActive,
  });
  Future<void> updateDefinition({
    required String id,
    required String categoryId,
    required String name,
    required int sessionCount,
    required int validityDays,
    required double price,
    required bool isActive,
  });

  Future<List<MemberSummary>> searchMembers(String query);
  Future<List<MemberPackage>> memberPackages(String memberId);
  Future<List<MemberPackage>> myPackages();
  Future<List<PackageFreeze>> freezes(String packageId);
  Future<List<CreditLedgerEntry>> ledger(String packageId);

  Future<void> assignPackage({
    required String memberId,
    required String definitionId,
    required String idempotencyKey,
    required bool replaceExisting,
    int discountPercent = 0,
  });
  Future<void> freezePackage({
    required String packageId,
    required DateTime startDate,
    required DateTime endDate,
    String? note,
  });

  /// [lastDay] null ise dondurma hemen biter (başlamamışsa tamamen kaldırılır).
  Future<void> endFreeze(String freezeId, {DateTime? lastDay});
  Future<void> adjustCredits(String packageId, int delta, String note);
}

const _pkgSelect =
    '*, package_definitions(name), categories(name), package_freezes(*)';

List<Map<String, dynamic>> _rows(dynamic r) =>
    (r as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

class SupabasePackageRepository implements PackageRepository {
  @override
  Future<List<Category>> categories() async {
    final r = await supabase.from('categories').select().order('name');
    return _rows(r).map(Category.fromJson).toList();
  }

  @override
  Future<void> createCategory({
    required String name,
    required bool isActive,
    required ClassType classType,
  }) => supabase.from('categories').insert({
    'name': name,
    'is_active': isActive,
    'class_type': classType.apiValue,
  });

  @override
  Future<void> updateCategory({
    required String id,
    required String name,
    required bool isActive,
    required ClassType classType,
  }) => supabase
      .from('categories')
      .update({
        'name': name,
        'is_active': isActive,
        'class_type': classType.apiValue,
      })
      .eq('id', id);

  @override
  Future<List<PackageDefinition>> definitions() async {
    final r = await supabase
        .from('package_definitions')
        .select('*, categories(name)')
        .order('session_count');
    return _rows(r).map(PackageDefinition.fromJson).toList();
  }

  Map<String, dynamic> _defBody(
    String categoryId,
    String name,
    int sessionCount,
    int validityDays,
    double price,
    bool isActive,
  ) => {
    'category_id': categoryId,
    'name': name,
    'session_count': sessionCount,
    'validity_days': validityDays,
    'price': price,
    'is_active': isActive,
  };

  @override
  Future<void> createDefinition({
    required String categoryId,
    required String name,
    required int sessionCount,
    required int validityDays,
    required double price,
    required bool isActive,
  }) => supabase
      .from('package_definitions')
      .insert(
        _defBody(categoryId, name, sessionCount, validityDays, price, isActive),
      );

  @override
  Future<void> updateDefinition({
    required String id,
    required String categoryId,
    required String name,
    required int sessionCount,
    required int validityDays,
    required double price,
    required bool isActive,
  }) => supabase
      .from('package_definitions')
      .update(
        _defBody(categoryId, name, sessionCount, validityDays, price, isActive),
      )
      .eq('id', id);

  @override
  Future<List<MemberSummary>> searchMembers(String query) async {
    final r = await supabase.rpc('search_members', params: {'p_query': query});
    return _rows(r).map(MemberSummary.fromJson).toList();
  }

  @override
  Future<List<MemberPackage>> memberPackages(String memberId) async {
    final r = await supabase
        .from('member_packages')
        .select(_pkgSelect)
        .eq('member_id', memberId)
        .order('activated_at', ascending: false);
    return _rows(r).map(MemberPackage.fromJson).toList();
  }

  @override
  Future<List<MemberPackage>> myPackages() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return const [];
    return memberPackages(uid);
  }

  @override
  Future<List<PackageFreeze>> freezes(String packageId) async {
    final r = await supabase
        .from('package_freezes')
        .select()
        .eq('member_package_id', packageId)
        .order('starts_at');
    return _rows(r).map(PackageFreeze.fromJson).toList();
  }

  @override
  Future<List<CreditLedgerEntry>> ledger(String packageId) async {
    final r = await supabase
        .from('credit_ledger')
        .select()
        .eq('member_package_id', packageId)
        .order('created_at', ascending: false)
        .order('id', ascending: false);
    return _rows(r).map(CreditLedgerEntry.fromJson).toList();
  }

  @override
  Future<void> assignPackage({
    required String memberId,
    required String definitionId,
    required String idempotencyKey,
    required bool replaceExisting,
    int discountPercent = 0,
  }) async {
    await supabase.rpc(
      'assign_package',
      params: {
        'p_member_id': memberId,
        'p_definition_id': definitionId,
        'p_idempotency_key': idempotencyKey,
        'p_replace_existing': replaceExisting,
        'p_discount_percent': discountPercent,
      },
    );
  }

  @override
  Future<void> freezePackage({
    required String packageId,
    required DateTime startDate,
    required DateTime endDate,
    String? note,
  }) async {
    await supabase.rpc(
      'freeze_package',
      params: {
        'p_package_id': packageId,
        'p_start_date': isoDate(startDate),
        'p_end_date': isoDate(endDate),
        'p_note': (note == null || note.trim().isEmpty) ? null : note.trim(),
      },
    );
  }

  @override
  Future<void> endFreeze(String freezeId, {DateTime? lastDay}) async {
    await supabase.rpc(
      'admin_end_freeze',
      params: {
        'p_freeze_id': freezeId,
        'p_last_day': lastDay == null ? null : isoDate(lastDay),
      },
    );
  }

  @override
  Future<void> adjustCredits(String packageId, int delta, String note) async {
    await supabase.rpc(
      'admin_adjust_credits',
      params: {
        'p_package_id': packageId,
        'p_delta': delta,
        'p_note': note.trim(),
      },
    );
  }
}

final packageRepositoryProvider = Provider<PackageRepository>(
  (ref) => SupabasePackageRepository(),
);

final categoriesProvider = FutureProvider<List<Category>>(
  (ref) => ref.watch(packageRepositoryProvider).categories(),
  retry: (_, _) => null,
);

final definitionsProvider = FutureProvider<List<PackageDefinition>>(
  (ref) => ref.watch(packageRepositoryProvider).definitions(),
  retry: (_, _) => null,
);

final myPackagesProvider = FutureProvider<List<MemberPackage>>(
  (ref) => ref.watch(packageRepositoryProvider).myPackages(),
  retry: (_, _) => null,
);

final memberPackagesProvider =
    FutureProvider.family<List<MemberPackage>, String>(
      (ref, memberId) =>
          ref.watch(packageRepositoryProvider).memberPackages(memberId),
      retry: (_, _) => null,
    );

final freezesProvider = FutureProvider.family<List<PackageFreeze>, String>(
  (ref, id) => ref.watch(packageRepositoryProvider).freezes(id),
  retry: (_, _) => null,
);

final ledgerProvider = FutureProvider.family<List<CreditLedgerEntry>, String>(
  (ref, id) => ref.watch(packageRepositoryProvider).ledger(id),
  retry: (_, _) => null,
);
