import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../packages/data/package_repository.dart';
import '../../data/schedule_repository.dart';
import '../../domain/schedule_models.dart';
import '../shared/schedule_flows.dart';
import '../shared/schedule_widgets.dart';

class ClassCalendarScreen extends ConsumerStatefulWidget {
  const ClassCalendarScreen({super.key});

  @override
  ConsumerState<ClassCalendarScreen> createState() =>
      _ClassCalendarScreenState();
}

class _ClassCalendarScreenState extends ConsumerState<ClassCalendarScreen> {
  DateTime _day = dayStart(DateTime.now());
  String? _categoryId;

  @override
  Widget build(BuildContext context) {
    final cats = ref.watch(categoriesProvider).value
            ?.where((c) => c.isActive)
            .toList() ??
        const [];
    final query = (
      day: _day,
      categoryId: _categoryId,
      trainerId: null,
      includeCancelled: false,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Ders Takvimi')),
      body: Column(
        children: [
          const SizedBox(height: 8),
          DayStrip(
              selected: _day, onSelected: (d) => setState(() => _day = d)),
          if (cats.isNotEmpty)
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  ChoiceChip(
                    label: const Text('Tümü'),
                    selected: _categoryId == null,
                    onSelected: (_) => setState(() => _categoryId = null),
                  ),
                  for (final c in cats) ...[
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text(c.name),
                      selected: _categoryId == c.id,
                      onSelected: (_) => setState(() => _categoryId = c.id),
                    ),
                  ],
                ],
              ),
            ),
          Expanded(
            child: ClassListView(
              query: query,
              onTap: (c) => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (_) => ClassDetailSheet(item: c),
              ),
            ),
          ),
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
                    final done = await runMemberCancelFlow(context, ref,
                        reservationId: item.myReservationId!,
                        startsAt: item.startsAt);
                    if (done) nav.pop();
                  }
                : null,
            child: const Text('İptal et'),
          ),
          if (!canCancel)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                started
                    ? 'Ders başladığı için iptal edilemez.'
                    : 'Dersin başlamasına 2 saatten az kaldığı için iptal edilemez.',
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
          children: [
            ClassInfo(item),
            const SizedBox(height: 16),
            action,
          ],
        ),
      ),
    );
  }
}
