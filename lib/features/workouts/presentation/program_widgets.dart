import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../schedule/data/schedule_repository.dart';
import '../domain/workout_models.dart';

/// Bir antrenman programını gösterir: başlık, durum, hedef, notlar, güne göre egzersizler.
class ProgramView extends ConsumerWidget {
  const ProgramView({
    super.key,
    required this.program,
    this.showHeader = true,
    this.footer,
  });

  final WorkoutProgram program;

  /// false ise başlık ve durum çipi gösterilmez (ExpansionTile başlığında zaten var).
  final bool showHeader;
  final Widget? footer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final trainers = ref.watch(trainersProvider).asData?.value;
    String? author;
    if (program.createdBy != null && trainers != null) {
      for (final tr in trainers) {
        if (tr.id == program.createdBy && tr.fullName.isNotEmpty) {
          author = tr.fullName;
        }
      }
    }
    final days = groupItemsByDay(program.items);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeader) ...[
          Row(
            children: [
              Expanded(
                child: Text(program.title, style: t.textTheme.titleMedium),
              ),
              const SizedBox(width: 8),
              ProgramStatusChip(isActive: program.isActive),
            ],
          ),
          const SizedBox(height: 4),
        ],
        Text(
          'Oluşturulma: ${formatDate(program.createdAt)}'
          '${author == null ? '' : '  •  Hazırlayan: $author'}',
          style: t.textTheme.bodySmall,
        ),
        if (program.goal != null) ...[
          const SizedBox(height: 8),
          Text('Hedef: ${program.goal}', style: t.textTheme.bodyMedium),
        ],
        if (program.notes != null) ...[
          const SizedBox(height: 4),
          Text(program.notes!, style: t.textTheme.bodyMedium),
        ],
        for (final d in days) ...[
          const SizedBox(height: 12),
          Text(
            d.key,
            style: t.textTheme.titleSmall?.copyWith(
              color: t.colorScheme.primary,
            ),
          ),
          const Divider(height: 8),
          for (final i in d.value) _ItemRow(item: i),
        ],
        if (footer != null) ...[const SizedBox(height: 8), footer!],
      ],
    );
  }
}

/// "3 set x 12  •  Dinlenme: 1 dk" gibi özet metni.
String itemSummary(WorkoutItem i) {
  final parts = <String>[];
  if (i.sets != null && i.reps != null) {
    parts.add('${i.sets} set x ${i.reps}');
  } else if (i.sets != null) {
    parts.add('${i.sets} set');
  } else if (i.reps != null) {
    parts.add(i.reps!);
  }
  if (i.restSeconds != null) {
    parts.add('Dinlenme: ${formatRest(i.restSeconds!)}');
  }
  return parts.join('  •  ');
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});
  final WorkoutItem item;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final summary = itemSummary(item);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.exercise,
            style: t.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (summary.isNotEmpty) Text(summary, style: t.textTheme.bodyMedium),
          if (item.note != null)
            Text(
              item.note!,
              style: t.textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }
}

class ProgramStatusChip extends StatelessWidget {
  const ProgramStatusChip({super.key, required this.isActive});
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Chip(
      label: Text(isActive ? 'Aktif' : 'Pasif'),
      visualDensity: VisualDensity.compact,
      backgroundColor: isActive
          ? c.primaryContainer
          : c.surfaceContainerHighest,
    );
  }
}

/// Kart içinde [ProgramView].
class ProgramCard extends StatelessWidget {
  const ProgramCard({super.key, required this.program, this.footer});
  final WorkoutProgram program;
  final Widget? footer;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: ProgramView(program: program, footer: footer),
    ),
  );
}
