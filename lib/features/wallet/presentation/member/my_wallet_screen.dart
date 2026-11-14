import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/empty_view.dart';
import '../../../auth/auth_providers.dart';
import '../../data/wallet_repository.dart';
import '../../domain/wallet_models.dart';
import '../shared/wallet_widgets.dart';
import '../../../../core/widgets/home_button.dart';

class MyWalletScreen extends ConsumerWidget {
  const MyWalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUserIdProvider);
    if (uid == null) return const Scaffold();
    final balance = ref.watch(walletBalanceProvider(uid));
    final ledger = ref.watch(walletLedgerProvider(uid));

    Future<void> refresh() async {
      ref.invalidate(walletBalanceProvider(uid));
      ref.invalidate(walletLedgerProvider(uid));
    }

    return Scaffold(
      appBar: AppBar(
        actions: const [HomeButton()],
        title: const Text('Cüzdanım'),
      ),
      body: AsyncValueView<double>(
        value: balance,
        onRetry: refresh,
        data: (bal) => AsyncValueView<List<WalletEntry>>(
          value: ledger,
          onRetry: refresh,
          data: (items) => RefreshIndicator(
            onRefresh: refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                BalanceCard(balance: bal),
                const SizedBox(height: 16),
                if (items.isEmpty)
                  const EmptyView(
                    title: 'Henüz hareket yok',
                    icon: Icons.receipt_long_outlined,
                  )
                else
                  for (final e in items) LedgerTile(entry: e),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
