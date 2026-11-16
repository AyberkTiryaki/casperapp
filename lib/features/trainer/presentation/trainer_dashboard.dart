import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/brand.dart';
import '../../home/dashboard_widgets.dart';
import '../../home/home_tab.dart';
import '../../schedule/data/schedule_repository.dart';

/// Eğitmen ana sayfası: bugünkü dersler.
class TrainerDashboard extends ConsumerWidget {
  const TrainerDashboard({super.key, required this.trainerId});
  final String trainerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = (
      day: dayStart(DateTime.now()),
      categoryId: null,
      trainerId: trainerId,
      includeCancelled: false,
    );
    final async = ref.watch(classesProvider(query));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Bugün'),
        const SizedBox(height: 12),
        async.when(
          loading: () => const DashLoading(),
          error: (e, _) => DashError(
            error: e,
            onRetry: () => ref.invalidate(classesProvider(query)),
          ),
          data: (all) {
            final items = all.where((c) => !c.isCancelled).toList()
              ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
            if (items.isEmpty) {
              return DashCard(
                child: Row(
                  children: [
                    const GradientIconBadge(Icons.free_breakfast_outlined),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text('Bugün dersin yok', style: dashTitleStyle()),
                    ),
                  ],
                ),
              );
            }
            return DashCard(
              onTap: () =>
                  ref.read(homeTabProvider.notifier).set(HomeTabs.second),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Bugünkü derslerin', style: dashTitleStyle()),
                  const SizedBox(height: 8),
                  for (final c in items)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Text(
                            formatTime(c.startsAt),
                            style: dashNumberStyle(size: 20),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              c.categoryName.isEmpty ? 'Ders' : c.categoryName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${c.bookedCount}/${c.capacity}',
                            style: TextStyle(
                              color: context.palette.muted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
