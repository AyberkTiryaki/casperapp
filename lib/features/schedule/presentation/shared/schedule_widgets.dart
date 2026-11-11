import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/empty_view.dart';
import '../../data/schedule_repository.dart';
import '../../domain/schedule_models.dart';

const _weekdays = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

String weekdayShort(DateTime d) => _weekdays[d.weekday - 1];

String classTimeRange(StudioClass c) =>
    '${formatTime(c.startsAt)} - ${formatTime(c.endsAt)}';

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

/// Yatay gün şeridi (bugünden itibaren [days] gün; [startOffset] ile geriye de açılabilir).
class DayStrip extends StatelessWidget {
  const DayStrip({
    super.key,
    required this.selected,
    required this.onSelected,
    this.days = 14,
    this.startOffset = 0,
  });

  final DateTime selected;
  final ValueChanged<DateTime> onSelected;
  final int days;
  final int startOffset;

  @override
  Widget build(BuildContext context) {
    final today = dayStart(DateTime.now());
    final sel = dayStart(selected);
    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: days,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final d = DateTime(
            today.year,
            today.month,
            today.day + startOffset + i,
          );
          final isSel = d == sel;
          final scheme = Theme.of(context).colorScheme;
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onSelected(d),
            child: Container(
              width: 56,
              decoration: BoxDecoration(
                color: isSel ? scheme.primary : null,
                border: Border.all(
                  color: isSel ? scheme.primary : scheme.outlineVariant,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    weekdayShort(d),
                    style: TextStyle(
                      fontSize: 12,
                      color: isSel ? scheme.onPrimary : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${d.day}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isSel ? scheme.onPrimary : null,
                    ),
                  ),
                  if (d == today)
                    Text(
                      'Bugün',
                      style: TextStyle(
                        fontSize: 9,
                        color: isSel ? scheme.onPrimary : null,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class ClassTile extends StatelessWidget {
  const ClassTile({
    super.key,
    required this.item,
    required this.onTap,
    this.showTrainer = true,
  });

  final StudioClass item;
  final VoidCallback onTap;
  final bool showTrainer;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final name = (item.title == null || item.title!.trim().isEmpty)
        ? item.categoryName
        : '${item.categoryName} - ${item.title}';
    final String spots;
    Color? spotColor;
    if (item.isCancelled) {
      spots = 'İptal';
      spotColor = AppColors.danger;
    } else if (item.isFull) {
      spots = 'Dolu';
      spotColor = AppColors.danger;
    } else {
      spots = '${item.remainingSpots} yer kaldı';
    }
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: Text(
          formatTime(item.startsAt),
          style: t.textTheme.titleMedium,
        ),
        title: Text(name),
        subtitle: Text(
          [
            if (showTrainer && item.trainerName.isNotEmpty) item.trainerName,
            item.classType.label,
            classTimeRange(item),
          ].join(' • '),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              spots,
              style: TextStyle(color: spotColor, fontWeight: FontWeight.w600),
            ),
            if (item.isBookedByMe)
              const Text(
                'Rezervasyonunuz var',
                style: TextStyle(fontSize: 11, color: AppColors.success),
              ),
          ],
        ),
      ),
    );
  }
}

/// Bir güne ait ders listesi (çekerek yenilenir).
class ClassListView extends ConsumerWidget {
  const ClassListView({
    super.key,
    required this.query,
    required this.onTap,
    this.showTrainer = true,
    this.emptyMessage = 'Bu gün için ders yok',
  });

  final ClassQuery query;
  final void Function(StudioClass) onTap;
  final bool showTrainer;
  final String emptyMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(classesProvider(query));
    return AsyncValueView<List<StudioClass>>(
      value: async,
      onRetry: () => ref.invalidate(classesProvider(query)),
      data: (items) => RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(classesProvider(query));
          await ref
              .read(classesProvider(query).future)
              .catchError((_) => <StudioClass>[]);
        },
        child: items.isEmpty
            ? ListView(
                children: [
                  const SizedBox(height: 80),
                  EmptyView(
                    title: emptyMessage,
                    icon: Icons.event_busy_outlined,
                  ),
                ],
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) => ClassTile(
                  item: items[i],
                  showTrainer: showTrainer,
                  onTap: () => onTap(items[i]),
                ),
              ),
      ),
    );
  }
}

/// Ders bilgi satırları (detay ekranları için).
class ClassInfo extends StatelessWidget {
  const ClassInfo(this.item, {super.key});
  final StudioClass item;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final title = (item.title == null || item.title!.trim().isEmpty)
        ? item.categoryName
        : '${item.categoryName} - ${item.title}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: t.titleLarge),
        const SizedBox(height: 8),
        Text('${formatDate(item.startsAt)}  ${classTimeRange(item)}'),
        if (item.trainerName.isNotEmpty) Text('Antrenör: ${item.trainerName}'),
        Text(
          '${item.classType.label} - ${item.bookedCount}/${item.capacity} dolu',
        ),
        if (item.isCancelled)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'Bu ders iptal edildi.',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
      ],
    );
  }
}
