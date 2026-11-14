import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/empty_view.dart';
import '../../../../core/widgets/home_button.dart';
import '../../../packages/data/package_repository.dart';
import '../../../packages/domain/package_models.dart';
import '../../data/schedule_repository.dart';
import '../../domain/schedule_models.dart';
import '../shared/schedule_flows.dart';
import '../shared/schedule_widgets.dart';

const _calendarDays = 14;
const _kMine = '__mine__';
const _kAll = '__all__';

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

  /// null: kullanıcı seçmedi (varsayılan); _kMine; _kAll; ya da kategori id.
  String? _filter;

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
    // Aktif (süresi dolmamış, dondurulmamış) paketlerin kategorileri.
    final now = DateTime.now();
    final myCats = <String>{
      for (final p
          in ref.watch(myPackagesProvider).value ?? const <MemberPackage>[])
        if (p.displayStatus(now) == PackageDisplayStatus.active) p.categoryId,
    };
    final hasActive = myCats.isNotEmpty;
    final filter = _filter ?? (hasActive ? _kMine : _kAll);
    final mineSelected = filter == _kMine && hasActive;
    final selectedCat = cats.containsKey(filter) ? filter : null;

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
          DayStrip(
            days: _calendarDays,
            selected: day,
            markedDays: {
              for (final d in days)
                if ((counts[d] ?? 0) > 0) d,
            },
            onSelected: (d) => setState(() => _pickedDay = d),
          ),
          if (cats.isNotEmpty)
            _CategoryChips(
              categories: cats,
              selected: selectedCat,
              showMine: hasActive,
              mineSelected: mineSelected,
              onSelected: (id) => setState(() => _filter = id ?? _kAll),
              onMine: () => setState(() => _filter = _kMine),
            ),
          Expanded(
            child: AsyncValueView<List<StudioClass>>(
              value: dayAsync,
              onRetry: () => ref.invalidate(classesProvider(_dayQuery(day))),
              data: (items) {
                final shown = mineSelected
                    ? items.where((c) => myCats.contains(c.categoryId)).toList()
                    : selectedCat == null
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
                              EmptyView(
                                title: mineSelected
                                    ? 'Paketine uygun ders yok'
                                    : 'Bu kategoride ders yok',
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
                          itemBuilder: (_, i) => ClassCard(
                            item: shown[i],
                            packageNotCovered:
                                hasActive &&
                                !myCats.contains(shown[i].categoryId),
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

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.categories,
    required this.selected,
    required this.showMine,
    required this.mineSelected,
    required this.onSelected,
    required this.onMine,
  });

  final Map<String, String> categories;
  final String? selected;
  final bool showMine;
  final bool mineSelected;
  final ValueChanged<String?> onSelected;
  final VoidCallback onMine;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          if (showMine) ...[
            ChoiceChip(
              label: const Text('Paketime uygun'),
              selected: mineSelected,
              onSelected: (_) => onMine(),
            ),
            const SizedBox(width: 8),
          ],
          ChoiceChip(
            label: const Text('Tümü'),
            selected: selected == null && !mineSelected,
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
