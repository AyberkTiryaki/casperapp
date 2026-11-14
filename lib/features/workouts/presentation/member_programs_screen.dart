import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/error_messages.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_view.dart';
import '../data/workout_repository.dart';
import '../domain/workout_models.dart';
import 'program_editor_screen.dart';
import 'program_widgets.dart';
import '../../../core/widgets/home_button.dart';

/// Eğitmen/yönetici: bir üyenin antrenman programları.
class MemberProgramsScreen extends ConsumerWidget {
  const MemberProgramsScreen({
    super.key,
    required this.memberId,
    required this.memberName,
  });

  final String memberId;
  final String memberName;

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    WorkoutProgram? existing,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ProgramEditorScreen(
          memberId: memberId,
          memberName: memberName,
          existing: existing,
        ),
      ),
    );
    if (saved == true) {
      ref.invalidate(workoutProgramsProvider(memberId));
      messenger.showSnackBar(
        const SnackBar(content: Text('Program kaydedildi.')),
      );
    }
  }

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    WorkoutProgram p,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final makeActive = !p.isActive;
    if (!makeActive) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Programı pasife al'),
          content: Text('"${p.title}" programı pasife alınsın mı?'),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Pasife al'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    try {
      await ref.read(workoutRepositoryProvider).setActive(p.id, makeActive);
      ref.invalidate(workoutProgramsProvider(memberId));
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            makeActive ? 'Program aktif yapıldı.' : 'Program pasife alındı.',
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(workoutProgramsProvider(memberId));
    return Scaffold(
      appBar: AppBar(
        actions: const [HomeButton()],
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(memberName, overflow: TextOverflow.ellipsis),
            Text(
              'Antrenman programları',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, ref, null),
        icon: const Icon(Icons.add),
        label: const Text('Yeni program'),
      ),
      body: AsyncValueView<List<WorkoutProgram>>(
        value: async,
        onRetry: () => ref.invalidate(workoutProgramsProvider(memberId)),
        data: (all) {
          final programs = sortPrograms(all);
          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(workoutProgramsProvider(memberId)),
            child: programs.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 120),
                      EmptyView(
                        title: 'Henüz program yok',
                        message: 'Yeni program ile başlayın.',
                        icon: Icons.fitness_center_outlined,
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: programs.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final p = programs[i];
                      return ProgramCard(
                        program: p,
                        footer: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _edit(context, ref, p),
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('Düzenle'),
                            ),
                            OutlinedButton(
                              onPressed: () => _toggle(context, ref, p),
                              child: Text(
                                p.isActive ? 'Pasife al' : 'Aktif yap',
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          );
        },
      ),
    );
  }
}
