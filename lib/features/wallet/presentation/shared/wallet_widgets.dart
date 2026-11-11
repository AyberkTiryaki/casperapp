import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/error_messages.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/wallet_repository.dart';
import '../../domain/wallet_models.dart';

class BalanceCard extends StatelessWidget {
  const BalanceCard({super.key, required this.balance, this.title});
  final double balance;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 40,
              color: t.colorScheme.primary,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title ?? 'Güncel bakiye', style: t.textTheme.bodyMedium),
                  const SizedBox(height: 4),
                  Text(formatTl(balance), style: t.textTheme.headlineMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LedgerTile extends StatelessWidget {
  const LedgerTile({super.key, required this.entry, this.trailing});
  final WalletEntry entry;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final positive = entry.amount > 0;
    final color = positive ? Colors.green.shade700 : Colors.red.shade700;
    final note = (entry.note ?? '').trim();
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.type.label, style: t.textTheme.titleMedium),
                  if (note.isNotEmpty) Text(note),
                  const SizedBox(height: 2),
                  Text(
                    '${formatDate(entry.createdAt)} ${formatTime(entry.createdAt)}'
                    '  •  Bakiye: ${formatTl(entry.balanceAfter)}',
                    style: t.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Text(
              formatSignedTl(entry.amount),
              style: t.textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

Future<bool> confirmDialog(
  BuildContext context,
  String title,
  String message, {
  String ok = 'Onayla',
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(ok),
        ),
      ],
    ),
  );
  return r == true;
}

/// Para hareketi yapan bir RPC'yi işlem anahtarıyla çalıştırır. [opId] işlemin
/// parametrelerini içermeli: ağ hatasında tekrar deneme aynı anahtarı kullanır.
/// Başarıda true döner; hatada kullanıcıya Türkçe mesaj gösterilir.
Future<bool> runMoneyAction(
  BuildContext context,
  WidgetRef ref, {
  required String opId,
  required Future<void> Function(String key) action,
  required String successMessage,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref.read(walletKeyHolderProvider).run(opId, action);
    messenger.showSnackBar(SnackBar(content: Text(successMessage)));
    return true;
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    return false;
  }
}
