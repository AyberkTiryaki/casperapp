import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/empty_view.dart';
import '../../../packages/data/package_repository.dart';
import '../../../packages/domain/package_models.dart';
import '../../data/wallet_repository.dart';
import '../../domain/wallet_models.dart';
import '../shared/sell_flow.dart';
import '../../../../core/widgets/home_button.dart';

/// Eğitmen: üye ara, ürün sat.
class SellProductScreen extends ConsumerStatefulWidget {
  const SellProductScreen({super.key});

  @override
  ConsumerState<SellProductScreen> createState() => _SellProductScreenState();
}

class _SellProductScreenState extends ConsumerState<SellProductScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  AsyncValue<List<MemberSummary>> _result = const AsyncLoading();
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    final seq = ++_seq;
    setState(() => _result = const AsyncLoading());
    try {
      final r = await ref
          .read(packageRepositoryProvider)
          .searchMembers(q.trim());
      if (mounted && seq == _seq) setState(() => _result = AsyncData(r));
    } catch (e, st) {
      if (mounted && seq == _seq) setState(() => _result = AsyncError(e, st));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: const [HomeButton()],
        title: const Text('Ürün satışı'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              onChanged: (v) {
                _debounce?.cancel();
                _debounce = Timer(
                  const Duration(milliseconds: 400),
                  () => _search(v),
                );
              },
              decoration: const InputDecoration(
                labelText: 'Üye ara',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: AsyncValueView<List<MemberSummary>>(
              value: _result,
              onRetry: () => _search(_controller.text),
              data: (items) => items.isEmpty
                  ? const EmptyView(
                      title: 'Üye bulunamadı',
                      icon: Icons.person_search,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final m = items[i];
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.person_outline),
                            title: Text(m.fullName),
                            trailing: const Icon(Icons.shopping_cart_outlined),
                            onTap: () => runSellFlow(
                              context,
                              ref,
                              memberId: m.id,
                              memberName: m.fullName,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Eğitmen: kendi yaptığı satışlar.
class MySalesScreen extends ConsumerWidget {
  const MySalesScreen({super.key, required this.sellerId});
  final String sellerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(salesBySellerProvider(sellerId));
    return Scaffold(
      appBar: AppBar(
        actions: const [HomeButton()],
        title: const Text('Satışlarım'),
      ),
      body: AsyncValueView<List<Sale>>(
        value: async,
        onRetry: () => ref.invalidate(salesBySellerProvider(sellerId)),
        data: (items) => RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(salesBySellerProvider(sellerId)),
          child: items.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 120),
                    EmptyView(
                      title: 'Henüz satış yok',
                      icon: Icons.shopping_bag_outlined,
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final s = items[i];
                    return Card(
                      child: ListTile(
                        isThreeLine: s.memberName != null,
                        title: Text('${s.productName} x${s.quantity}'),
                        subtitle: Text(
                          [
                            if (s.memberName != null) 'Alıcı: ${s.memberName}',
                            '${formatDate(s.createdAt)} ${formatTime(s.createdAt)}'
                                '${s.reversedAt != null ? '  •  İptal edildi' : ''}',
                          ].join('\n'),
                        ),
                        trailing: Text(
                          formatTl(s.total),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
