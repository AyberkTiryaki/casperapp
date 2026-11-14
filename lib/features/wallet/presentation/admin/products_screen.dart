import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/error_messages.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/empty_view.dart';
import '../../data/wallet_repository.dart';
import '../../domain/wallet_models.dart';
import '../../../../core/widgets/home_button.dart';

class ProductsScreen extends ConsumerWidget {
  const ProductsScreen({super.key});

  Future<void> _edit(BuildContext context, WidgetRef ref, Product? p) async {
    final messenger = ScaffoldMessenger.of(context);
    final r = await showDialog<({String name, double price, bool active})>(
      context: context,
      builder: (_) => _ProductDialog(product: p),
    );
    if (r == null) return;
    try {
      final repo = ref.read(walletRepositoryProvider);
      if (p == null) {
        await repo.createProduct(name: r.name, price: r.price);
      } else {
        await repo.updateProduct(
          id: p.id,
          name: r.name,
          price: r.price,
          isActive: r.active,
        );
      }
      ref.invalidate(productsProvider);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  Future<void> _toggle(WidgetRef ref, BuildContext context, Product p) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(walletRepositoryProvider)
          .updateProduct(
            id: p.id,
            name: p.name,
            price: p.price,
            isActive: !p.isActive,
          );
      ref.invalidate(productsProvider);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(productsProvider);
    return Scaffold(
      appBar: AppBar(
        actions: const [HomeButton()],
        title: const Text('Ürünler ve fiyatlar'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, ref, null),
        icon: const Icon(Icons.add),
        label: const Text('Ürün ekle'),
      ),
      body: AsyncValueView<List<Product>>(
        value: async,
        onRetry: () => ref.invalidate(productsProvider),
        data: (items) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(productsProvider),
          child: items.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 120),
                    EmptyView(
                      title: 'Henüz ürün yok',
                      icon: Icons.sell_outlined,
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final p = items[i];
                    return Card(
                      child: ListTile(
                        title: Text(p.name),
                        subtitle: Text(
                          '${formatTl(p.price)}  •  ${p.isActive ? 'Aktif' : 'Pasif'}',
                        ),
                        onTap: () => _edit(context, ref, p),
                        trailing: Switch(
                          value: p.isActive,
                          onChanged: (_) => _toggle(ref, context, p),
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

class _ProductDialog extends StatefulWidget {
  const _ProductDialog({this.product});
  final Product? product;

  @override
  State<_ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<_ProductDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.product?.name ?? '');
  late final _price = TextEditingController(
    text: widget.product == null
        ? ''
        : widget.product!.price.toStringAsFixed(2).replaceAll('.', ','),
  );
  late bool _active = widget.product?.isActive ?? true;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      actionsOverflowDirection: VerticalDirection.up,
      actionsOverflowButtonSpacing: 12,
      title: Text(widget.product == null ? 'Ürün ekle' : 'Ürünü düzenle'),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _name,
              maxLength: 80,
              decoration: const InputDecoration(labelText: 'Ürün adı'),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Ürün adı gerekli' : null,
            ),
            TextFormField(
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Fiyat (₺)'),
              validator: (v) {
                final d = parseMoneyInput(v);
                if (d == null || d < 0 || d > 1000000) {
                  return 'Geçerli bir fiyat girin (en fazla 2 ondalık)';
                }
                return null;
              },
            ),
            if (widget.product != null)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Aktif'),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
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
          onPressed: () {
            if (!_form.currentState!.validate()) return;
            Navigator.of(context).pop((
              name: _name.text.trim(),
              price: parseMoneyInput(_price.text)!,
              active: _active,
            ));
          },
          child: const Text('Kaydet'),
        ),
      ],
    );
  }
}
