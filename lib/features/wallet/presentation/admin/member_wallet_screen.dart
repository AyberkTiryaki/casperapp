import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/empty_view.dart';
import '../../data/wallet_repository.dart';
import '../../domain/wallet_models.dart';
import '../shared/sell_flow.dart';
import '../shared/wallet_widgets.dart';
import '../../../../core/widgets/home_button.dart';

/// Yönetici: bir üyenin cüzdanı (bakiye, hareketler, yükleme, düzeltme, ters kayıt, satış).
class AdminMemberWalletScreen extends ConsumerWidget {
  const AdminMemberWalletScreen({
    super.key,
    required this.memberId,
    required this.memberName,
  });
  final String memberId;
  final String memberName;

  void _refresh(WidgetRef ref) {
    ref.invalidate(walletBalanceProvider(memberId));
    ref.invalidate(walletLedgerProvider(memberId));
  }

  Future<void> _topup(BuildContext context, WidgetRef ref) async {
    final r = await showDialog<({double amount, String? note})>(
      context: context,
      builder: (_) => const _AmountDialog(
        title: 'Bakiye yükle',
        signed: false,
        noteRequired: false,
      ),
    );
    if (r == null || !context.mounted) return;
    final ok = await runMoneyAction(
      context,
      ref,
      opId: 'topup:$memberId:${r.amount}:${r.note ?? ''}',
      action: (key) => ref
          .read(walletRepositoryProvider)
          .topup(memberId: memberId, amount: r.amount, key: key, note: r.note),
      successMessage: 'Bakiye yüklendi.',
    );
    if (ok) _refresh(ref);
  }

  Future<void> _adjust(BuildContext context, WidgetRef ref) async {
    final r = await showDialog<({double amount, String? note})>(
      context: context,
      builder: (_) => const _AmountDialog(
        title: 'Bakiye düzeltme',
        signed: true,
        noteRequired: true,
      ),
    );
    if (r == null || !context.mounted) return;
    final ok = await runMoneyAction(
      context,
      ref,
      opId: 'adjust:$memberId:${r.amount}:${r.note}',
      action: (key) => ref
          .read(walletRepositoryProvider)
          .adjust(
            memberId: memberId,
            amount: r.amount,
            note: r.note!,
            key: key,
          ),
      successMessage: 'Düzeltme kaydedildi.',
    );
    if (ok) _refresh(ref);
  }

  Future<void> _reverse(
    BuildContext context,
    WidgetRef ref,
    WalletEntry e,
  ) async {
    final go = await confirmDialog(
      context,
      'Ters kayıt',
      '${e.type.label} (${formatSignedTl(e.amount)}) hareketi ters çevrilecek. Bu işlem geri alınamaz.',
      ok: 'Ters çevir',
    );
    if (!go || !context.mounted) return;
    final ok = await runMoneyAction(
      context,
      ref,
      opId: 'reverse:${e.id}',
      action: (key) =>
          ref.read(walletRepositoryProvider).reverse(entryId: e.id, key: key),
      successMessage: 'Ters kayıt oluşturuldu.',
    );
    if (ok) _refresh(ref);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(walletBalanceProvider(memberId));
    final ledger = ref.watch(walletLedgerProvider(memberId));
    return Scaffold(
      appBar: AppBar(
        actions: const [HomeButton()],
        title: Text('Cüzdan: $memberName'),
      ),
      body: AsyncValueView<double>(
        value: balance,
        onRetry: () => _refresh(ref),
        data: (bal) => AsyncValueView<List<WalletEntry>>(
          value: ledger,
          onRetry: () => _refresh(ref),
          data: (items) => RefreshIndicator(
            onRefresh: () async => _refresh(ref),
            child: ListView(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                BalanceCard(balance: bal),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: () => _topup(context, ref),
                      icon: const Icon(Icons.add_card_outlined),
                      label: const Text('Bakiye yükle'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _adjust(context, ref),
                      icon: const Icon(Icons.tune),
                      label: const Text('Düzeltme'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final ok = await runSellFlow(
                          context,
                          ref,
                          memberId: memberId,
                          memberName: memberName,
                        );
                        if (ok) _refresh(ref);
                      },
                      icon: const Icon(Icons.shopping_cart_outlined),
                      label: const Text('Ürün sat'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (items.isEmpty)
                  const EmptyView(
                    title: 'Henüz hareket yok',
                    icon: Icons.receipt_long_outlined,
                  )
                else
                  for (final e in items)
                    LedgerTile(
                      entry: e,
                      trailing: canReverseEntry(e, items)
                          ? IconButton(
                              tooltip: 'Ters kayıt',
                              icon: const Icon(Icons.undo),
                              onPressed: () => _reverse(context, ref, e),
                            )
                          : null,
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AmountDialog extends StatefulWidget {
  const _AmountDialog({
    required this.title,
    required this.signed,
    required this.noteRequired,
  });
  final String title;
  final bool signed;
  final bool noteRequired;

  @override
  State<_AmountDialog> createState() => _AmountDialogState();
}

class _AmountDialogState extends State<_AmountDialog> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      actionsOverflowDirection: VerticalDirection.up,
      actionsOverflowButtonSpacing: 12,
      title: Text(widget.title),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _amount,
              keyboardType: TextInputType.numberWithOptions(
                decimal: true,
                signed: widget.signed,
              ),
              decoration: InputDecoration(
                labelText: widget.signed
                    ? 'Tutar (₺, artı veya eksi)'
                    : 'Tutar (₺)',
              ),
              validator: (v) {
                final d = parseMoneyInput(v);
                if (d == null) {
                  return 'Geçerli bir tutar girin (en fazla 2 ondalık)';
                }
                if (widget.signed ? d == 0 : d <= 0) {
                  return widget.signed
                      ? 'Tutar sıfır olamaz'
                      : 'Tutar sıfırdan büyük olmalı';
                }
                if (d.abs() > 1000000) {
                  return 'Tutar en fazla 1.000.000 olabilir';
                }
                return null;
              },
            ),
            TextFormField(
              controller: _note,
              decoration: InputDecoration(
                labelText: widget.noteRequired
                    ? 'Açıklama'
                    : 'Açıklama (isteğe bağlı)',
              ),
              validator: (v) => widget.noteRequired && (v ?? '').trim().isEmpty
                  ? 'Açıklama zorunlu'
                  : null,
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
            final n = _note.text.trim();
            Navigator.of(context).pop((
              amount: parseMoneyInput(_amount.text)!,
              note: n.isEmpty ? null : n,
            ));
          },
          child: const Text('Kaydet'),
        ),
      ],
    );
  }
}
