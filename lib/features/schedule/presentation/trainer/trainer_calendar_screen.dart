import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/empty_view.dart';
import '../../data/schedule_repository.dart';
import '../../domain/schedule_models.dart';
import '../shared/create_class_screen.dart';
import '../shared/schedule_widgets.dart';
import '../../../../core/widgets/home_button.dart';

class TrainerCalendarScreen extends ConsumerStatefulWidget {
  const TrainerCalendarScreen({super.key, required this.trainerId});
  final String trainerId;

  @override
  ConsumerState<TrainerCalendarScreen> createState() =>
      _TrainerCalendarScreenState();
}

class _TrainerCalendarScreenState extends ConsumerState<TrainerCalendarScreen> {
  DateTime _day = dayStart(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final query = (
      day: _day,
      categoryId: null,
      trainerId: widget.trainerId,
      includeCancelled: false,
    );
    return Scaffold(
      appBar: AppBar(
        actions: const [HomeButton()],
        title: const Text('Takvimim'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CreateClassScreen(initialDay: _day),
          ),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Ders aç'),
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          DayStrip(
            selected: _day,
            onSelected: (d) => setState(() => _day = d),
            markedDays: ref
                .watch(
                  classDaysProvider((
                    from: dayStart(DateTime.now()),
                    days: 14,
                    trainerId: widget.trainerId,
                  )),
                )
                .value,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ClassListView(
              query: query,
              showTrainer: false,
              onTap: (c) => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ClassParticipantsScreen(item: c),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ClassParticipantsScreen extends ConsumerWidget {
  const ClassParticipantsScreen({super.key, required this.item});
  final StudioClass item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(participantsProvider(item.id));
    return Scaffold(
      appBar: AppBar(
        actions: const [HomeButton()],
        title: const Text('Katılımcılar'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.all(16), child: ClassInfo(item)),
          const Divider(height: 1),
          Expanded(
            child: AsyncValueView<List<ClassParticipant>>(
              value: async,
              onRetry: () => ref.invalidate(participantsProvider(item.id)),
              data: (items) => items.isEmpty
                  ? const EmptyView(
                      title: 'Henüz katılımcı yok',
                      icon: Icons.group_outlined,
                    )
                  : ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, i) => ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: Text(items[i].fullName),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
