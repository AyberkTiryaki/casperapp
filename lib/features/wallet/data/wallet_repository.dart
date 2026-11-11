import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/supabase.dart';
import '../../../core/utils/uuid.dart';
import '../../schedule/domain/schedule_models.dart' show BookingKeyHolder;
import '../domain/wallet_models.dart';

List<Map<String, dynamic>> _rows(dynamic r) =>
    (r as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

abstract class WalletRepository {
  Future<double> balance(String memberId);
  Future<List<WalletEntry>> ledger(String memberId);
  Future<List<Product>> products();
  Future<void> createProduct({required String name, required double price});
  Future<void> updateProduct({
    required String id,
    required String name,
    required double price,
    required bool isActive,
  });
  Future<List<Sale>> salesByMember(String memberId);
  Future<List<Sale>> salesBySeller(String sellerId);

  Future<void> topup({
    required String memberId,
    required double amount,
    required String key,
    String? note,
  });
  Future<void> adjust({
    required String memberId,
    required double amount,
    required String note,
    required String key,
  });
  Future<void> sell({
    required String memberId,
    required String productId,
    required int quantity,
    required String key,
  });
  Future<void> reverse({
    required int entryId,
    required String key,
    String? note,
  });
}

class SupabaseWalletRepository implements WalletRepository {
  @override
  Future<double> balance(String memberId) async {
    final r = await supabase
        .from('wallets')
        .select('balance')
        .eq('member_id', memberId)
        .maybeSingle();
    return r == null ? 0 : parseMoney(r['balance']);
  }

  @override
  Future<List<WalletEntry>> ledger(String memberId) async {
    final r = await supabase
        .from('wallet_ledger')
        .select()
        .eq('member_id', memberId)
        .order('id', ascending: false)
        .limit(300);
    return _rows(r).map(WalletEntry.fromJson).toList();
  }

  @override
  Future<List<Product>> products() async {
    final r = await supabase.from('products').select().order('name');
    return _rows(r).map(Product.fromJson).toList();
  }

  @override
  Future<void> createProduct({required String name, required double price}) =>
      supabase.from('products').insert({'name': name, 'price': price});

  @override
  Future<void> updateProduct({
    required String id,
    required String name,
    required double price,
    required bool isActive,
  }) => supabase
      .from('products')
      .update({'name': name, 'price': price, 'is_active': isActive})
      .eq('id', id);

  Future<List<Sale>> _sales(String column, String id) async {
    final r = await supabase
        .from('sales')
        .select('*, products(name)')
        .eq(column, id)
        .order('created_at', ascending: false)
        .limit(200);
    return _rows(r).map(Sale.fromJson).toList();
  }

  @override
  Future<List<Sale>> salesByMember(String memberId) =>
      _sales('member_id', memberId);

  @override
  Future<List<Sale>> salesBySeller(String sellerId) =>
      _sales('seller_id', sellerId);

  @override
  Future<void> topup({
    required String memberId,
    required double amount,
    required String key,
    String? note,
  }) => supabase.rpc(
    'admin_wallet_topup',
    params: {
      'p_member_id': memberId,
      'p_amount': amount,
      'p_idempotency_key': key,
      'p_note': note,
    },
  );

  @override
  Future<void> adjust({
    required String memberId,
    required double amount,
    required String note,
    required String key,
  }) => supabase.rpc(
    'admin_wallet_adjust',
    params: {
      'p_member_id': memberId,
      'p_amount': amount,
      'p_note': note,
      'p_idempotency_key': key,
    },
  );

  @override
  Future<void> sell({
    required String memberId,
    required String productId,
    required int quantity,
    required String key,
  }) => supabase.rpc(
    'sell_product',
    params: {
      'p_member_id': memberId,
      'p_product_id': productId,
      'p_quantity': quantity,
      'p_idempotency_key': key,
    },
  );

  @override
  Future<void> reverse({
    required int entryId,
    required String key,
    String? note,
  }) => supabase.rpc(
    'admin_reverse_wallet_entry',
    params: {'p_entry_id': entryId, 'p_idempotency_key': key, 'p_note': note},
  );
}

final walletRepositoryProvider = Provider<WalletRepository>(
  (ref) => SupabaseWalletRepository(),
);

/// Para hareketi işlem anahtarları: ağ hatasında aynı anahtar, aksi halde yenisi.
/// Anahtar kimliği işlemin parametrelerinden türetilir (farklı parametre = farklı anahtar).
final walletKeyHolderProvider = Provider<BookingKeyHolder>(
  (ref) => BookingKeyHolder(generateUuidV4),
);

final walletBalanceProvider = FutureProvider.family<double, String>(
  (ref, memberId) => ref.watch(walletRepositoryProvider).balance(memberId),
);

final walletLedgerProvider = FutureProvider.family<List<WalletEntry>, String>(
  (ref, memberId) => ref.watch(walletRepositoryProvider).ledger(memberId),
);

final productsProvider = FutureProvider<List<Product>>(
  (ref) => ref.watch(walletRepositoryProvider).products(),
);

final salesBySellerProvider = FutureProvider.family<List<Sale>, String>(
  (ref, id) => ref.watch(walletRepositoryProvider).salesBySeller(id),
);

final salesByMemberProvider = FutureProvider.family<List<Sale>, String>(
  (ref, id) => ref.watch(walletRepositoryProvider).salesByMember(id),
);
