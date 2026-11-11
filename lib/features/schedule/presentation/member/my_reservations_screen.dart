import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/empty_view.dart';
import '../../data/schedule_repository.dart';
import '../../domain/schedule_models.dart';
import '../shared/schedule_flows.dart';

class MyReservationsScreen extends ConsumerWidget {
  const MyReservationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myReservationsProvider);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Rezervasyonlarım'),
          bottom: const TabBar(
              tabs: [Tab(text: 'Yaklaşan'), Tab(text: 'Geçmiş')]),
        ),
        body: AsyncValueView<List<MyReservation>>(
          value: async,
          onRetry: () => ref.invalidate(myReservationsProvider),
          data: (all) {
            final now = DateTime.now();
            final upcoming = all.where((r) => r.isUpcoming(now)).toList()
              ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
            final past = all.where((r) => !r.isUpcoming(now)).toList()
              ..sort((a, b) => b.startsAt.compareTo(a.startsAt));
            return TabBarView(children: [
              _List(items: upcoming, empty: 'Yaklaşan rezervasyonunuz yok'),
              _List(items: past, empty: 'Geçmiş rezervasyonunuz yok'),
            ]);
          },
        ),
      ),
    );
  }
}

class _List extends ConsumerWidget {
  const _List({required this.items, required this.empty});
  final List<MyReservation> items;
  final String empty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(myReservationsProvider);
        await ref
            .read(myReservationsProvider.future)
            .catchError((_) => <MyReservation>[]);
      },
      child: items.isEmpty
          ? ListView(children: [
              const SizedBox(height: 80),
              EmptyView(title: empty, icon: Icons.event_available_outlined),
            ])
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final r = items[i];
                final upcoming = r.isUpcoming(now);
                final canCancel = canMemberCancel(r.startsAt, now);
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            (r.title == null || r.title!.trim().isEmpty)
                                ? r.categoryName
                                : '${r.categoryName} - ${r.title}',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(
                            '${formatDate(r.startsAt)}  ${formatTime(r.startsAt)} - ${formatTime(r.endsAt)}'),
                        Text('${r.trainerName} • ${r.classType.label}'),
                        const SizedBox(height: 4),
                        Text(r.statusLabel(now)),
                        if (upcoming) ...[
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: canCancel
                                ? () => runMemberCancelFlow(context, ref,
                                    reservationId: r.reservationId,
                                    startsAt: r.startsAt)
                                : null,
                            child: const Text('İptal et'),
                          ),
                          if (!canCancel)
                            Text(
                              'Dersin başlamasına 2 saatten az kaldığı için iptal edilemez.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
