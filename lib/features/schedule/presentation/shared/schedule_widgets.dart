import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
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
      actionsOverflowDirection: VerticalDirection.up,
      actionsOverflowButtonSpacing: 12,
      title: Text(title),
      content: Text(message),
      actions: [
        OutlinedButton(
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

/// Yatay gün şeridi (bugünden itibaren [days] gün; [startOffset] ile geriye de
/// açılabilir). Seçili gün ilk açılışta ve değiştiğinde görünür alana kaydırılır.
/// [markedDays] içindeki günlerin altında nokta gösterilir.
class DayStrip extends StatefulWidget {
  const DayStrip({
    super.key,
    required this.selected,
    required this.onSelected,
    this.days = 14,
    this.startOffset = 0,
    this.markedDays,
  });

  final DateTime selected;
  final ValueChanged<DateTime> onSelected;
  final int days;
  final int startOffset;
  final Set<DateTime>? markedDays;

  @override
  State<DayStrip> createState() => _DayStripState();
}

class _DayStripState extends State<DayStrip> {
  static const _chipWidth = 58.0;
  static const _gap = 8.0;
  static const _pad = 16.0;

  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _scheduleScroll(animate: false);
  }

  @override
  void didUpdateWidget(DayStrip old) {
    super.didUpdateWidget(old);
    if (dayStart(old.selected) != dayStart(widget.selected)) {
      _scheduleScroll(animate: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _selectedIndex {
    final today = dayStart(DateTime.now());
    final sel = dayStart(widget.selected);
    final diff = DateTime.utc(
      sel.year,
      sel.month,
      sel.day,
    ).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
    return diff - widget.startOffset;
  }

  void _scheduleScroll({required bool animate}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      final i = _selectedIndex;
      if (i < 0 || i >= widget.days) return;
      final pos = _controller.position;
      final center = _pad + i * (_chipWidth + _gap) + _chipWidth / 2;
      final target = (center - pos.viewportDimension / 2).clamp(
        pos.minScrollExtent,
        pos.maxScrollExtent,
      );
      if (animate) {
        _controller.animateTo(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        _controller.jumpTo(target);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final today = dayStart(DateTime.now());
    final sel = dayStart(widget.selected);
    return SizedBox(
      height: 88,
      child: ListView.separated(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: _pad),
        itemCount: widget.days,
        separatorBuilder: (_, _) => const SizedBox(width: _gap),
        itemBuilder: (_, i) {
          final d = DateTime(
            today.year,
            today.month,
            today.day + widget.startOffset + i,
          );
          return DayChip(
            day: d,
            isToday: d == today,
            selected: d == sel,
            marked: widget.markedDays?.contains(d) ?? false,
            onTap: () => widget.onSelected(d),
          );
        },
      ),
    );
  }
}

/// Gün şeridindeki tek gün (seçili: mavi gradyan; dolu gün: camgöbeği nokta).
class DayChip extends StatelessWidget {
  const DayChip({
    super.key,
    required this.day,
    required this.isToday,
    required this.selected,
    required this.marked,
    required this.onTap,
  });

  final DateTime day;
  final bool isToday;
  final bool selected;
  final bool marked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : AppColors.nightText;
    final muted = selected ? Colors.white : AppColors.nightMuted;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: 58,
          decoration: BoxDecoration(
            gradient: selected ? AppGradients.brand : null,
            color: selected ? null : AppColors.nightRaised,
            border: Border.all(
              color: selected ? AppColors.electricBlue : AppColors.nightOutline,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                weekdayShort(day),
                style: TextStyle(fontSize: 12, color: muted),
              ),
              Text(
                '${day.day}',
                style: TextStyle(
                  fontFamily: AppFonts.display,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: fg,
                  height: 1.1,
                ),
              ),
              SizedBox(
                height: 12,
                child: isToday
                    ? Text(
                        'Bugün',
                        style: TextStyle(fontSize: 10, color: muted),
                      )
                    : null,
              ),
              const SizedBox(height: 2),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: marked
                      ? (selected ? Colors.white : AppColors.cyan)
                      : Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ders kartı. [staff] true ise (antrenör/yönetici) "dolu/kapasite" ve ders
/// türü gösterilir; iptal edilen dersler "İptal" rozetiyle işaretlenir.
class ClassCard extends StatelessWidget {
  const ClassCard({
    super.key,
    required this.item,
    required this.onTap,
    this.showTrainer = true,
    this.showBookedBadge = true,
    this.staff = false,
  });

  final StudioClass item;
  final VoidCallback onTap;
  final bool showTrainer;
  final bool showBookedBadge;
  final bool staff;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final name = (item.title == null || item.title!.trim().isEmpty)
        ? item.categoryName
        : '${item.categoryName} - ${item.title}';
    final minutes = item.endsAt.difference(item.startsAt).inMinutes;
    final info = [
      if (showTrainer && item.trainerName.isNotEmpty) item.trainerName,
      if (staff) item.classType.label,
    ].join(' • ');
    return Material(
      color: AppColors.nightCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.nightOutline),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatTime(item.startsAt),
                    style: const TextStyle(
                      fontFamily: AppFonts.display,
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$minutes dk',
                    style: t.bodySmall?.copyWith(color: AppColors.nightMuted),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: t.titleMedium,
                    ),
                    if (info.isNotEmpty)
                      Text(
                        info,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodySmall?.copyWith(
                          color: AppColors.nightMuted,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        CapacityBadge(item: item),
                        if (staff)
                          Text(
                            '${item.bookedCount}/${item.capacity}',
                            style: t.bodySmall?.copyWith(
                              color: AppColors.nightMuted,
                            ),
                          ),
                        if (showBookedBadge && item.isBookedByMe)
                          const Text(
                            'Kayıtlısın',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.success,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CapacityBadge extends StatelessWidget {
  const CapacityBadge({super.key, required this.item});
  final StudioClass item;

  @override
  Widget build(BuildContext context) {
    final String text;
    final Color color;
    if (item.isCancelled) {
      text = 'İptal';
      color = AppColors.danger;
    } else if (item.isFull) {
      text = 'Dolu';
      color = AppColors.nightMuted;
    } else if (item.remainingSpots <= 2) {
      text = '${item.remainingSpots} yer kaldı';
      color = AppColors.warning;
    } else {
      text = '${item.remainingSpots} yer';
      color = AppColors.cyan;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
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
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) => ClassCard(
                  item: items[i],
                  showTrainer: showTrainer,
                  showBookedBadge: false,
                  staff: true,
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
