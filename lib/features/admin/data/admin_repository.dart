import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  /// Yönetici, e-postası doğrulanmış yeni bir hesap açar (geçici şifreyle).
  /// Sunucu tarafı: supabase/functions/admin-create-user. Yeni kullanıcının id'sini döndürür.
  Future<String> createUser({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
  });
}

class SupabaseAdminRepository implements AdminRepository {
  /// admin_list_users: pasifler dahil; ad veya e-posta ile arar; e-posta, boy, kilo ve
  /// doğum tarihini de döndürür (yalnızca yönetici çağırabilir).
  @override
  Future<List<ManagedUser>> searchUsers(String query) async {
    final r = await supabase.rpc(
      'admin_list_users',
      params: {'p_query': query.trim()},
    );
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

  @override
  Future<String> createUser({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
  }) async {
    try {
      final res = await supabase.functions.invoke(
        'admin-create-user',
        body: {
          'email': email.trim(),
          'password': password,
          'full_name': fullName.trim(),
          'role': role.name,
        },
      );
      final data = res.data;
      if (data is Map && data['user_id'] is String) {
        return data['user_id'] as String;
      }
      throw const PostgrestException(message: 'CREATE_USER_FAILED');
    } on FunctionException catch (e) {
      // Sunucunun hata kodunu friendlyError'ın tanıdığı biçime çevir
      final d = e.details;
      final code = d is Map && d['error'] is String
          ? d['error'] as String
          : null;
      throw PostgrestException(
        message: code ?? 'CREATE_USER_FAILED',
        code: e.status == 403 ? '42501' : null,
      );
    }
  }
}

final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => SupabaseAdminRepository(),
);
