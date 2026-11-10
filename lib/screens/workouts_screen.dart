import 'package:flutter/material.dart';

import '../data/studio_store.dart';
import '../models/models.dart';
import '../widgets/common.dart';

class WorkoutsScreen extends StatelessWidget {
  const WorkoutsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Antrenman Programları')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Program Ekle'),
      ),
      body: store.programs.isEmpty
          ? const EmptyState(
              icon: Icons.fitness_center,
              message: 'Henüz program yok.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                ContentWidth(
                  child: Column(
                    children: [
                      for (final p in store.programs)
                        _ProgramCard(program: p, store: store),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

void _openForm(BuildContext context, {WorkoutProgram? existing}) {
  showDialog<void>(
    context: context,
    builder: (_) => _ProgramFormDialog(existing: existing),
  );
}

class _ProgramCard extends StatelessWidget {
  const _ProgramCard({required this.program, required this.store});

  final WorkoutProgram program;
  final StudioStore store;

  @override
  Widget build(BuildContext context) {
    final p = program;
    final count = store.membersOnProgram(p.id);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: const Border(),
        leading: const Icon(Icons.fitness_center),
        title: Text(p.name),
        subtitle: Text('${p.goal} • ${p.exercises.length} egzersiz • $count üye'),
        children: [
          for (final (i, e) in p.exercises.indexed)
            ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 12,
                child: Text('${i + 1}', style: const TextStyle(fontSize: 11)),
              ),
              title: Text(e.name),
              trailing: Text(
                '${e.sets} × ${e.reps}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          OverflowBar(
            alignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _openForm(context, existing: p),
                icon: const Icon(Icons.edit),
                label: const Text('Düzenle'),
              ),
              TextButton.icon(
                onPressed: () async {
                  final ok = await confirmDialog(
                    context,
                    title: 'Program silinsin mi?',
                    message: count == 0
                        ? '"${p.name}" silinecek.'
                        : '"${p.name}" silinecek ve $count üyeden kaldırılacak.',
                  );
                  if (ok) store.deleteProgram(p.id);
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('Sil'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "Squat - 4x10" biçimindeki satırları egzersiz listesine çevirir.
/// Set×tekrar yazılmamışsa 3×10 varsayılır.
List<Exercise> parseExercises(String text) {
  final result = <Exercise>[];
  final setRep = RegExp(r'^(\d+)\s*[xX×*]\s*(.+)$');
  for (final raw in text.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    final dash = line.lastIndexOf(RegExp(r'\s[-–]\s'));
    if (dash > 0) {
      final name = line.substring(0, dash).trim();
      final spec = line.substring(dash + 3).trim();
      final match = setRep.firstMatch(spec);
      if (match != null && name.isNotEmpty) {
        result.add(Exercise(
          name: name,
          sets: int.parse(match.group(1)!),
          reps: match.group(2)!.trim(),
        ));
        continue;
      }
    }
    result.add(Exercise(name: line, sets: 3, reps: '10'));
  }
  return result;
}

String formatExercises(List<Exercise> list) =>
    list.map((e) => '${e.name} - ${e.sets}x${e.reps}').join('\n');

class _ProgramFormDialog extends StatefulWidget {
  const _ProgramFormDialog({this.existing});

  final WorkoutProgram? existing;

  @override
  State<_ProgramFormDialog> createState() => _ProgramFormDialogState();
}

class _ProgramFormDialogState extends State<_ProgramFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _goal = TextEditingController(text: widget.existing?.goal);
  late final _exercises = TextEditingController(
    text: widget.existing == null ? '' : formatExercises(widget.existing!.exercises),
  );

  @override
  void dispose() {
    _name.dispose();
    _goal.dispose();
    _exercises.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final store = StoreScope.read(context);
    final exercises = parseExercises(_exercises.text);
    final p = widget.existing;
    if (p == null) {
      store.addProgram(
        name: _name.text.trim(),
        goal: _goal.text.trim(),
        exercises: exercises,
      );
    } else {
      p
        ..name = _name.text.trim()
        ..goal = _goal.text.trim()
        ..exercises = exercises;
      store.updateProgram(p);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Yeni Program' : 'Programı Düzenle'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Program adı'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Program adı girin' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _goal,
                  decoration: const InputDecoration(
                    labelText: 'Hedef',
                    hintText: 'Örn. Kuvvet, kilo verme, mobilite',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _exercises,
                  minLines: 5,
                  maxLines: 12,
                  decoration: const InputDecoration(
                    labelText: 'Egzersizler (her satıra bir tane)',
                    hintText: 'Squat - 4x10\nŞınav - 3x12\nPlank - 3x45 sn',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => parseExercises(v ?? '').isEmpty
                      ? 'En az bir egzersiz girin'
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Vazgeç'),
        ),
        FilledButton(onPressed: _save, child: const Text('Kaydet')),
      ],
    );
  }
}
