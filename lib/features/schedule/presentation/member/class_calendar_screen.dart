import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/empty_view.dart';
import '../../../../core/widgets/home_button.dart';
import '../../data/schedule_repository.dart';
import '../../domain/schedule_models.dart';
import '../shared/schedule_flows.dart';
import '../shared/schedule_widgets.dart';

const _calendarDays = 14;

ClassQuery _dayQuery(DateTime d) =>
    (day: d, categoryId: null, trainerId: null, includeCancelled: false);

class ClassCalendarScreen extends ConsumerStatefulWidget {
  const ClassCalendarScreen({super.key});

  @override
  ConsumerState<ClassCalendarScreen> createState() =>
      _ClassCalendarScreenState();
}

class _ClassCalendarScreenState extends ConsumerState<ClassCalendarScreen> {
  DateTime? _pickedDay;
  String? _categoryId;

  @override
  Widget build(BuildContext context) {
    final today = dayStart(DateTime.now());
    final days = [
      for (var i = 0; i < _calendarDays; i++)
        DateTime(today.year, today.month, today.day + i),
    ];
    final asyncs = {
      for (final d in days) d: ref.watch(classesProvider(_dayQuery(d))),
    };
    final counts = {for (final d in days) d: asyncs[d]!.value?.length ?? 0};
    final allLoaded = asyncs.values.every((a) => a.hasValue);

    // Varsayılan gün: bugün; bugün boşsa ilk dolu gün (tümü yüklenince).
    var day = _pickedDay ?? today;
    if (_pickedDay == null && allLoaded && counts[today] == 0) {
      day = days.firstWhere((d) => counts[d]! > 0, orElse: () => today);
    }

    // Yüklenen derslerdeki kategoriler.
    final cats = <String, String>{};
    for (final a in asyncs.values) {
      for (final c in a.value ?? const <StudioClass>[]) {
        if (c.categoryId.isNotEmpty) cats[c.categoryId] = c.categoryName;
      }
    }
    final selectedCat = cats.containsKey(_categoryId) ? _categoryId : null;

    final dayAsync = asyncs[day]!;
    DateTime? nextDay;
    for (final d in days) {
      if (d.isAfter(day) && counts[d]! > 0) {
        nextDay = d;
        break;
      }
    }

    return Scaffold(
      appBar: AppBar(
        actions: const [HomeButton()],
        title: const Text('Ders Takvimi'),
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          _DayChips(
            days: days,
            today: today,
            selected: day,
            counts: counts,
            onSelected: (d) => setState(() => _pickedDay = d),
          ),
          if (cats.isNotEmpty)
            _CategoryChips(
              categories: cats,
              selected: selectedCat,
              onSelected: (id) => setState(() => _categoryId = id),
            ),
          Expanded(
            child: AsyncValueView<List<StudioClass>>(
              value: dayAsync,
              onRetry: () => ref.invalidate(classesProvider(_dayQuery(day))),
              data: (items) {
                final shown = selectedCat == null
                    ? items
                    : items.where((c) => c.categoryId == selectedCat).toList();
                final jump = nextDay;
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(classesProvider);
                    await ref
                        .read(classesProvider(_dayQuery(day)).future)
                        .catchError((_) => <StudioClass>[]);
                  },
                  child: shown.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            const SizedBox(height: 48),
                            if (items.isEmpty)
                              EmptyView(
                                title: 'Bu gün için ders yok',
                                icon: Icons.event_busy_outlined,
                                action: jump == null
                                    ? null
                                    : OutlinedButton(
                                        onPressed: () =>
                                            setState(() => _pickedDay = jump),
                                        child: Text(
                                          'Sonraki ders günü: ${weekdayShort(jump)} ${jump.day}',
                                        ),
                                      ),
                              )
                            else
                              const EmptyView(
                                title: 'Bu kategoride ders yok',
                                icon: Icons.filter_alt_off_outlined,
                              ),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                          itemCount: shown.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) => _ClassCard(
                            item: shown[i],
                            onTap: () => showModalBottomSheet<void>(
                              context: context,
                              isScrollControlled: true,
                              showDragHandle: true,
                              builder: (_) => ClassDetailSheet(item: shown[i]),
                            ),
                          ),
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DayChips extends StatelessWidget {
  const _DayChips({
    required this.days,
    required this.today,
    required this.selected,
    required this.counts,
    required this.onSelected,
  });

  final List<DateTime> days;
  final DateTime today;
  final DateTime selected;
  final Map<DateTime, int> counts;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: days.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final d = days[i];
          final isSel = d == selected;
          final fg = isSel ? Colors.white : AppColors.nightText;
          final muted = isSel ? Colors.white : AppColors.nightMuted;
          return Semantics(
            button: true,
            selected: isSel,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => onSelected(d),
              child: Container(
                width: 58,
                decoration: BoxDecoration(
                  gradient: isSel ? AppGradients.brand : null,
                  color: isSel ? null : AppColors.nightRaised,
                  border: Border.all(
                    color: isSel
                        ? AppColors.electricBlue
                        : AppColors.nightOutline,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      weekdayShort(d),
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                    Text(
                      '${d.day}',
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
                      child: d == today
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
                        color: (counts[d] ?? 0) > 0
                            ? (isSel ? Colors.white : AppColors.cyan)
                            : Colors.transparent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  final Map<String, String> categories;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          ChoiceChip(
            label: const Text('Tümü'),
            selected: selected == null,
            onSelected: (_) => onSelected(null),
          ),
          for (final e in categories.entries) ...[
            const SizedBox(width: 8),
            ChoiceChip(
              label: Text(e.value),
              selected: selected == e.key,
              onSelected: (_) => onSelected(e.key),
            ),
          ],
        ],
      ),
    );
  }
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({required this.item, required this.onTap});
  final StudioClass item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final name = (item.title == null || item.title!.trim().isEmpty)
        ? item.categoryName
        : '${item.categoryName} - ${item.title}';
    final minutes = item.endsAt.difference(item.startsAt).inMinutes;
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
                    if (item.trainerName.isNotEmpty)
                      Text(
                        item.trainerName,
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
                        _CapacityBadge(item: item),
                        if (item.isBookedByMe)
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

class _CapacityBadge extends StatelessWidget {
  const _CapacityBadge({required this.item});
  final StudioClass item;

  @override
  Widget build(BuildContext context) {
    final String text;
    final Color color;
    if (item.isFull) {
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

class ClassDetailSheet extends ConsumerWidget {
  const ClassDetailSheet({super.key, required this.item});
  final StudioClass item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final started = item.hasStarted(now);
    Widget action;
    if (item.isCancelled) {
      action = const Text('Bu ders iptal edildi.');
    } else if (item.isBookedByMe) {
      final canCancel = !started && canMemberCancel(item.startsAt, now);
      action = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Bu derse rezervasyonunuz var.'),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: canCancel
                ? () async {
                    final nav = Navigator.of(context);
                    final done = await runMemberCancelFlow(
                      context,
                      ref,
                      reservationId: item.myReservationId!,
                      startsAt: item.startsAt,
                    );
                    if (done) nav.pop();
                  }
                : null,
            child: const Text('İptal et'),
          ),
          if (!canCancel)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                started ? 'Ders başladığı için iptal edilemez.' : 'Dersin başlamasına 2 saatten az kaldığı için iptal edilemez.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      );
    } else if (started) {
      action = const Text('Ders başladığı için rezervasyon yapılamaz.');
    } else if (item.isFull) {
      action = const FilledButton(onPressed: null, child: Text('Dolu'));
    } else {
      action = FilledButton(
        onPressed: () async {
          final nav = Navigator.of(context);
          final done = await runBookFlow(context, ref, item);
          if (done) nav.pop();
        },
        child: const Text('Rezervasyon yap'),
      );
    }
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [ClassInfo(item), const SizedBox(height: 16), action],
        ),
      ),
    );
  }
}
