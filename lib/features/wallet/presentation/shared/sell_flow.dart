import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/error_messages.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/wallet_repository.dart';
import '../../domain/wallet_models.dart';
import 'wallet_widgets.dart';

/// Ürün satışı akışı: ürün + adet seç, onayla, sell_product çağır.
/// Başarıda true döner. Fiyat sunucuda belirlenir; gösterilen toplam bilgilendiricidir.
Future<bool> runSellFlow(
  BuildContext context,
  WidgetRef ref, {
  required String memberId,
  required String memberName,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  List<Product> products;
  try {
    products = (await ref.read(productsProvider.future))
        .where((p) => p.isActive)
        .toList();
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    return false;
  }
  if (!context.mounted) return false;
  if (products.isEmpty) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Satışa açık ürün yok.')),
    );
    return false;
  }
  final choice = await showDialog<({Product product, int qty})>(
    context: context,
    builder: (_) => _SellDialog(memberName: memberName, products: products),
  );
  if (choice == null || !context.mounted) return false;

  final ok = await runMoneyAction(
    context,
    ref,
    opId: 'sell:$memberId:${choice.product.id}:${choice.qty}',
    action: (key) => ref
        .read(walletRepositoryProvider)
        .sell(
          memberId: memberId,
          productId: choice.product.id,
          quantity: choice.qty,
          key: key,
        ),
    successMessage: 'Satış tamamlandı.',
  );
  if (ok) {
    ref.invalidate(walletBalanceProvider(memberId));
    ref.invalidate(walletLedgerProvider(memberId));
    ref.invalidate(salesBySellerProvider);
  }
  return ok;
}

class _SellDialog extends StatefulWidget {
  const _SellDialog({required this.memberName, required this.products});
  final String memberName;
  final List<Product> products;

  @override
  State<_SellDialog> createState() => _SellDialogState();
}

class _SellDialogState extends State<_SellDialog> {
  late Product _product = widget.products.first;
  int _qty = 1;

  @override
  Widget build(BuildContext context) {
    final total = _product.price * _qty;
    return AlertDialog(
      title: Text('Ürün sat: ${widget.memberName}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<Product>(
              initialValue: _product,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Ürün'),
              items: [
                for (final p in widget.products)
                  DropdownMenuItem(
                    value: p,
                    child: Text('${p.name} - ${formatTl(p.price)}'),
                  ),
              ],
              onChanged: (p) => setState(() => _product = p ?? _product),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Adet'),
                const Spacer(),
                IconButton(
                  tooltip: 'Azalt',
                  onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text('$_qty', style: Theme.of(context).textTheme.titleMedium),
                IconButton(
                  tooltip: 'Artır',
                  onPressed: _qty < 100 ? () => setState(() => _qty++) : null,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Toplam: ${formatTl(total)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Tutar üyenin cüzdanından düşülür. Kesin fiyat işlem anında sunucuda belirlenir.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop((product: _product, qty: _qty)),
          child: const Text('Satışı onayla'),
        ),
      ],
    );
  }
}
