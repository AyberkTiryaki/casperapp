import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/empty_view.dart';
import '../../data/package_repository.dart';
import '../../domain/package_models.dart';

class PackageStatusChip extends StatelessWidget {
  const PackageStatusChip(this.status, {super.key});
  final PackageDisplayStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      PackageDisplayStatus.active => AppColors.success,
      PackageDisplayStatus.frozen => Colors.blue,
      PackageDisplayStatus.expired => Colors.grey,
      PackageDisplayStatus.terminated => AppColors.danger,
    };
    return Chip(
      label: Text(status.label, style: TextStyle(color: color, fontSize: 12)),
      side: BorderSide(color: color),
      backgroundColor: color.withValues(alpha: 0.1),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
    );
  }
}

/// Üye paketi kartı; admin ekranında [actions] ile düğmeler eklenir.
class PackageCard extends StatelessWidget {
  const PackageCard({
    super.key,
    required this.package,
    this.onTap,
    this.actions = const [],
    this.showPrice = false,
    this.now,
  });

  final MemberPackage package;
  final VoidCallback? onTap;
  final List<Widget> actions;
  final bool showPrice;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final now = this.now ?? DateTime.now();
    final status = package.displayStatus(now);
    final active = package.isCurrentlyActive(now);
    final total = package.totalCredits;
    final remaining = package.remainingCredits;
    final upcomingFreezes =
        package.freezes.where((f) => f.endsAt.isAfter(now)).toList();
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(package.categoryName ?? 'Kategori',
                        style: t.textTheme.labelMedium),
                  ),
                  PackageStatusChip(status),
                ],
              ),
              Text(package.definitionName ?? 'Paket',
                  style: t.textTheme.titleMedium),
              const SizedBox(height: 12),
              Text('Kalan hak: $remaining / $total'),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: total == 0 ? 0 : remaining / total,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 8),
              Text(active
                  ? 'Bitiş: ${formatDate(package.endsAt)} (${package.daysLeft(now)} gün kaldı)'
                  : 'Bitiş: ${formatDate(package.endsAt)}'),
              if (showPrice && package.discountPercent > 0) ...[
                Text('Liste fiyatı: ${formatTl(package.listPrice)}'),
                Text('İndirim: %${package.discountPercent}'),
              ],
              if (showPrice) Text('Ödenen: ${formatTl(package.pricePaid)}'),
              for (final f in upcomingFreezes)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.ac_unit, size: 16),
                      const SizedBox(width: 6),
                      Expanded(child: Text(freezeRangeText(f))),
                    ],
                  ),
                ),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: actions),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Dondurma aralığı metni (bitiş dışlayıcı olduğu için son gün 1 gün geri alınır).
String freezeRangeText(PackageFreeze f) {
  final lastDay = f.endsAt.subtract(const Duration(days: 1));
  return 'Donduruldu: ${formatDate(f.startsAt)} - ${formatDate(lastDay)} (${f.days} gün)';
}

class LedgerList extends ConsumerWidget {
  const LedgerList({super.key, required this.packageId});
  final String packageId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ledgerProvider(packageId));
    return AsyncValueView<List<CreditLedgerEntry>>(
      value: async,
      onRetry: () => ref.invalidate(ledgerProvider(packageId)),
      data: (items) {
        if (items.isEmpty) {
          return const EmptyView(
              title: 'Hak hareketi yok', icon: Icons.receipt_long_outlined);
        }
        return ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: items.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final e = items[i];
            final sign = e.delta > 0 ? '+${e.delta}' : '${e.delta}';
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(e.label),
              subtitle: Text(
                  '${formatDate(e.createdAt)}${e.note == null ? '' : ' - ${e.note}'}'),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(sign,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: e.delta >= 0
                              ? AppColors.success
                              : AppColors.danger)),
                  Text('Bakiye: ${e.balanceAfter}',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Üye/yönetici için "Hak hareketleri" ekranı.
class LedgerScreen extends StatelessWidget {
  const LedgerScreen({super.key, required this.package});
  final MemberPackage package;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hak hareketleri')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [LedgerList(packageId: package.id)],
      ),
    );
  }
}
