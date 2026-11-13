import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_view.dart';
import '../data/workout_repository.dart';
import '../domain/workout_models.dart';
import 'program_widgets.dart';

class MyProgramsScreen extends ConsumerWidget {
  const MyProgramsScreen({super.key, required this.memberId});

  final String memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(workoutProgramsProvider(memberId));
    return Scaffold(
      appBar: AppBar(title: const Text('Antrenman programım')),
      body: AsyncValueView<List<WorkoutProgram>>(
        value: async,
        onRetry: () => ref.invalidate(workoutProgramsProvider(memberId)),
        data: (all) {
          final programs = sortPrograms(all);
          final active = programs.where((p) => p.isActive).toList();
          final older = programs.where((p) => !p.isActive).toList();
          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(workoutProgramsProvider(memberId)),
            child: programs.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 120),
                      EmptyView(
                        title: 'Henüz programınız yok',
                        message: 'Eğitmeniniz size bir program hazırladığında burada görünür.',
                        icon: Icons.fitness_center_outlined,
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      for (final p in active) ProgramCard(program: p),
                      if (older.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Önceki programlar',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        for (final p in older)
                          Card(
                            child: ExpansionTile(
                              title: Text(p.title),
                              subtitle: Text(formatDate(p.createdAt)),
                              childrenPadding: const EdgeInsets.fromLTRB(
                                16,
                                0,
                                16,
                                16,
                              ),
                              expandedCrossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                ProgramView(program: p, showHeader: false),
                              ],
                            ),
                          ),
                      ],
                    ],
                  ),
          );
        },
      ),
    );
  }
}
