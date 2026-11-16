import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/supabase.dart';
import '../../../core/utils/formatters.dart';
import '../domain/protocol_models.dart';

abstract class ProtocolRepository {
  /// Yönetici: tüm protokoller.
  Future<List<Protocol>> list();
  Future<void> save({
    String? id,
    required String name,
    required int discountPercent,
    required bool isActive,
    DateTime? validUntil,
    String? note,
  });

  /// Üyenin bağlı olduğu protokol (yoksa null).
  Future<Protocol?> memberProtocol(String memberId);

  /// [protocolId] null ise bağlantı kaldırılır.
  Future<void> setMemberProtocol(String memberId, String? protocolId);

  /// Giriş yapmadan da çağrılabilir.
  Future<PublicPriceList> publicPriceList();
}

class SupabaseProtocolRepository implements ProtocolRepository {
  @override
  Future<List<Protocol>> list() async {
    final r = await supabase
        .from('protocols')
        .select()
        .order('is_active', ascending: false)
        .order('name');
    return (r as List)
        .map((e) => Protocol.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  @override
  Future<void> save({
    String? id,
    required String name,
    required int discountPercent,
    required bool isActive,
    DateTime? validUntil,
    String? note,
  }) async {
    final body = {
      'name': name.trim(),
      'discount_percent': discountPercent,
      'is_active': isActive,
      'valid_until': validUntil == null ? null : isoDate(validUntil),
      'note': (note == null || note.trim().isEmpty) ? null : note.trim(),
    };
    if (id == null) {
      await supabase.from('protocols').insert(body);
    } else {
      await supabase.from('protocols').update(body).eq('id', id);
    }
  }

  @override
  Future<Protocol?> memberProtocol(String memberId) async {
    final r = await supabase
        .from('profiles')
        .select('protocols(*)')
        .eq('id', memberId)
        .maybeSingle();
    final p = r?['protocols'];
    return p is Map ? Protocol.fromJson(Map<String, dynamic>.from(p)) : null;
  }

  @override
  Future<void> setMemberProtocol(String memberId, String? protocolId) async {
    await supabase.rpc(
      'admin_set_member_protocol',
      params: {'p_member_id': memberId, 'p_protocol_id': protocolId},
    );
  }

  @override
  Future<PublicPriceList> publicPriceList() async {
    final r = await supabase.rpc('public_price_list');
    return PublicPriceList.fromJson(Map<String, dynamic>.from(r as Map));
  }
}

final protocolRepositoryProvider = Provider<ProtocolRepository>(
  (ref) => SupabaseProtocolRepository(),
);

final protocolsProvider = FutureProvider<List<Protocol>>(
  (ref) => ref.watch(protocolRepositoryProvider).list(),
  retry: (_, _) => null,
);

final memberProtocolProvider = FutureProvider.family<Protocol?, String>(
  (ref, memberId) =>
      ref.watch(protocolRepositoryProvider).memberProtocol(memberId),
  retry: (_, _) => null,
);

final publicPriceListProvider = FutureProvider<PublicPriceList>(
  (ref) => ref.watch(protocolRepositoryProvider).publicPriceList(),
);
