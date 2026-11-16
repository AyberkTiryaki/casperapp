import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_view.dart';
import '../../schedule/domain/schedule_models.dart' show ClassType;
import '../data/protocol_repository.dart';
import '../domain/protocol_models.dart';

/// Herkese açık fiyat listesi: giriş yapmadan da açılır.
class PriceListScreen extends ConsumerWidget {
  const PriceListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(publicPriceListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Paketler ve Fiyatlar')),
      body: AsyncValueView<PublicPriceList>(
        value: async,
        onRetry: () => ref.invalidate(publicPriceListProvider),
        data: (list) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(publicPriceListProvider),
          child: list.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 120),
                    EmptyView(
                      title: 'Fiyat listesi henüz hazır değil',
                      message:
                          'Güncel fiyatlar için stüdyoyla iletişime geçin.',
                      icon: Icons.sell_outlined,
                    ),
                  ],
                )
              : _PriceListBody(list: list),
        ),
      ),
    );
  }
}

class _PriceListBody extends StatelessWidget {
  const _PriceListBody({required this.list});
  final PublicPriceList list;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: t.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: t.colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Tüm fiyatlara KDV dahildir.',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: t.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            for (final c in list.categories) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(c.name, style: t.textTheme.titleLarge),
                    ),
                    Chip(
                      label: Text(
                        c.classType == ClassType.individual
                            ? 'Özel ders'
                            : 'Grup dersi',
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
              Card(
                child: Column(
                  children: [
                    for (var i = 0; i < c.packages.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      ListTile(
                        title: Text(c.packages[i].name),
                        subtitle: Text(
                          '${c.packages[i].sessionCount} ders · ${c.packages[i].validityDays} gün geçerli',
                        ),
                        trailing: Text(
                          formatTl(c.packages[i].price),
                          style: t.textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (list.protocols.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
                child: Text('Kurum indirimleri', style: t.textTheme.titleLarge),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                child: Text(
                  'Anlaşmalı kurum üyeleri, belgelerini stüdyoya gösterdiğinde paket fiyatlarında indirim alır.',
                  style: t.textTheme.bodyMedium?.copyWith(
                    color: t.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Card(
                child: Column(
                  children: [
                    for (var i = 0; i < list.protocols.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.handshake_outlined),
                        title: Text(list.protocols[i].name),
                        subtitle: list.protocols[i].validUntil == null
                            ? null
                            : Text(
                                '${formatDate(list.protocols[i].validUntil!)} tarihine kadar',
                              ),
                        trailing: Text(
                          '%${list.protocols[i].discountPercent} indirim',
                          style: t.textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Fiyatlar değişebilir; satın alınmış paketler bundan etkilenmez.',
              style: t.textTheme.bodySmall?.copyWith(
                color: t.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
