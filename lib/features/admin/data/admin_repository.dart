import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/supabase.dart';
import '../../profile/profile.dart';
import '../domain/admin_models.dart';

List<Map<String, dynamic>> _rows(dynamic r) =>
    (r as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

abstract class AdminRepository {
  Future<List<ManagedUser>> searchUsers(String query);
  Future<void> setRole(String userId, UserRole role);
  Future<void> setActive(String userId, bool isActive);
  Future<List<AuditEntry>> auditLog({
    required int offset,
    required int limit,
    String? action,
  });
  Future<Map<String, String>> names(Iterable<String> ids);
}

class SupabaseAdminRepository implements AdminRepository {
  /// Yönetici profiles tablosunu RLS ile okuyabilir; pasif kullanıcılar da listelenir
  /// (admin_search_users yalnızca aktifleri döndürdüğü için yeniden aktif etme için kullanılamaz).
  @override
  Future<List<ManagedUser>> searchUsers(String query) async {
    final q = query.trim().replaceAll(RegExp(r'[%_,()\\]'), ' ').trim();
    var req = supabase
        .from('profiles')
        .select('id, full_name, role, is_active');
    if (q.isNotEmpty) req = req.ilike('full_name', '%$q%');
    final r = await req.order('full_name').limit(50);
    return _rows(r).map(ManagedUser.fromJson).toList();
  }

  @override
  Future<void> setRole(String userId, UserRole role) => supabase.rpc(
    'admin_set_role',
    params: {'p_user_id': userId, 'p_role': role.name},
  );

  @override
  Future<void> setActive(String userId, bool isActive) => supabase.rpc(
    'admin_set_active',
    params: {'p_user_id': userId, 'p_is_active': isActive},
  );

  @override
  Future<List<AuditEntry>> auditLog({
    required int offset,
    required int limit,
    String? action,
  }) async {
    var req = supabase.from('audit_log').select();
    if (action != null) req = req.eq('action', action);
    final r = await req
        .order('id', ascending: false)
        .range(offset, offset + limit - 1);
    return _rows(r).map(AuditEntry.fromJson).toList();
  }

  @override
  Future<Map<String, String>> names(Iterable<String> ids) async {
    final list = ids.toSet().toList();
    if (list.isEmpty) return {};
    final r = await supabase
        .from('profiles')
        .select('id, full_name')
        .inFilter('id', list);
    return {
      for (final m in _rows(r))
        m['id'] as String: (m['full_name'] as String?) ?? '',
    };
  }
}

final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => SupabaseAdminRepository(),
);
