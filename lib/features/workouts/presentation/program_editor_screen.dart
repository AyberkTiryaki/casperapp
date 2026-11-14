import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/error_messages.dart';
import '../data/workout_repository.dart';
import '../domain/workout_models.dart';
import 'program_widgets.dart';

String? _blankToNull(String s) {
  final t = s.trim();
  return t.isEmpty ? null : t;
}

class ProgramEditorScreen extends ConsumerStatefulWidget {
  const ProgramEditorScreen({
    super.key,
    required this.memberId,
    required this.memberName,
    this.existing,
  });

  final String memberId;
  final String memberName;
  final WorkoutProgram? existing;

  @override
  ConsumerState<ProgramEditorScreen> createState() =>
      _ProgramEditorScreenState();
}

class _ProgramEditorScreenState extends ConsumerState<ProgramEditorScreen> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _goal = TextEditingController(text: widget.existing?.goal ?? '');
  late final _notes = TextEditingController(text: widget.existing?.notes ?? '');
  late bool _active = widget.existing?.isActive ?? true;
  late final List<WorkoutItem> _items = [...?widget.existing?.items];
  bool _saving = false;
  bool _itemsError = false;

  @override
  void dispose() {
    _title.dispose();
    _goal.dispose();
    _notes.dispose();
    super.dispose();
  }

  String get _lastDay => _items.isEmpty ? 'Gün 1' : _items.last.dayLabel;

  Future<void> _editItem(WorkoutItem? existing) async {
    final r = await showDialog<WorkoutItem>(
      context: context,
      builder: (_) => _ItemDialog(existing: existing, defaultDay: _lastDay),
    );
    if (r == null || !mounted) return;
    setState(() {
      _itemsError = false;
      if (existing == null) {
        _items.add(r);
      } else {
        final i = _items.indexOf(existing);
        if (i >= 0) _items[i] = r;
      }
    });
  }

  void _delete(WorkoutItem item) => setState(() => _items.remove(item));

  /// Aynı gün içindeki komşu ile yer değiştirir.
  void _move(WorkoutItem item, int dir) {
    final idx = _items.indexOf(item);
    var j = idx + dir;
    while (j >= 0 && j < _items.length) {
      if (_items[j].dayLabel == item.dayLabel) {
        setState(() {
          _items[idx] = _items[j];
          _items[j] = item;
        });
        return;
      }
      j += dir;
    }
  }

  Future<void> _save() async {
    final ok = _form.currentState!.validate();
    if (_items.isEmpty) {
      setState(() => _itemsError = true);
      return;
    }
    if (!ok) return;
    setState(() => _saving = true);
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(workoutRepositoryProvider)
          .saveProgram(
            memberId: widget.memberId,
            programId: widget.existing?.id,
            title: _title.text.trim(),
            goal: _blankToNull(_goal.text),
            notes: _blankToNull(_notes.text),
            items: [for (final d in groupItemsByDay(_items)) ...d.value],
            isActive: _active,
          );
      if (!mounted) return;
      nav.pop(true);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final days = groupItemsByDay(_items);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing == null ? 'Yeni program' : 'Programı düzenle',
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Kaydet'),
          ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _saving,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(widget.memberName, style: t.textTheme.bodySmall),
            const SizedBox(height: 8),
            Form(
              key: _form,
              child: Column(
                children: [
                  TextFormField(
                    controller: _title,
                    maxLength: 80,
                    decoration: const InputDecoration(labelText: 'Başlık'),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? 'Başlık gerekli' : null,
                  ),
                  TextFormField(
                    controller: _goal,
                    maxLength: 200,
                    decoration: const InputDecoration(labelText: 'Hedef'),
                  ),
                  TextFormField(
                    controller: _notes,
                    maxLength: 2000,
                    minLines: 2,
                    maxLines: 5,
                    keyboardType: TextInputType.multiline,
                    decoration: const InputDecoration(labelText: 'Notlar'),
                  ),
                ],
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Aktif program'),
              subtitle: const Text(
                'Aktif yapılırsa üyenin diğer aktif programı pasife alınır.',
              ),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
            const SizedBox(height: 8),
            Text('Egzersizler', style: t.textTheme.titleMedium),
            if (_itemsError)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'En az bir egzersiz ekleyin.',
                  style: TextStyle(color: t.colorScheme.error),
                ),
              ),
            for (final d in days) ...[
              const SizedBox(height: 12),
              Text(
                d.key,
                style: t.textTheme.titleSmall?.copyWith(
                  color: t.colorScheme.primary,
                ),
              ),
              for (var k = 0; k < d.value.length; k++)
                _ItemCard(
                  item: d.value[k],
                  canUp: k > 0,
                  canDown: k < d.value.length - 1,
                  onEdit: () => _editItem(d.value[k]),
                  onDelete: () => _delete(d.value[k]),
                  onUp: () => _move(d.value[k], -1),
                  onDown: () => _move(d.value[k], 1),
                ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _editItem(null),
              icon: const Icon(Icons.add),
              label: const Text('Egzersiz ekle'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.item,
    required this.canUp,
    required this.canDown,
    required this.onEdit,
    required this.onDelete,
    required this.onUp,
    required this.onDown,
  });

  final WorkoutItem item;
  final bool canUp;
  final bool canDown;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onUp;
  final VoidCallback onDown;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final summary = itemSummary(item);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.exercise,
              style: t.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (summary.isNotEmpty)
              Text(summary, style: t.textTheme.bodyMedium),
            if (item.note != null)
              Text(item.note!, style: t.textTheme.bodySmall),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Yukarı taşı',
                  onPressed: canUp ? onUp : null,
                  icon: const Icon(Icons.arrow_upward),
                ),
                IconButton(
                  tooltip: 'Aşağı taşı',
                  onPressed: canDown ? onDown : null,
                  icon: const Icon(Icons.arrow_downward),
                ),
                IconButton(
                  tooltip: 'Düzenle',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'Sil',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemDialog extends StatefulWidget {
  const _ItemDialog({this.existing, required this.defaultDay});
  final WorkoutItem? existing;
  final String defaultDay;

  @override
  State<_ItemDialog> createState() => _ItemDialogState();
}

class _ItemDialogState extends State<_ItemDialog> {
  final _form = GlobalKey<FormState>();
  late final _day = TextEditingController(
    text: widget.existing?.dayLabel ?? widget.defaultDay,
  );
  late final _exercise = TextEditingController(
    text: widget.existing?.exercise ?? '',
  );
  late final _sets = TextEditingController(
    text: widget.existing?.sets?.toString() ?? '',
  );
  late final _reps = TextEditingController(text: widget.existing?.reps ?? '');
  late final _rest = TextEditingController(
    text: widget.existing?.restSeconds?.toString() ?? '',
  );
  late final _note = TextEditingController(text: widget.existing?.note ?? '');

  @override
  void dispose() {
    _day.dispose();
    _exercise.dispose();
    _sets.dispose();
    _reps.dispose();
    _rest.dispose();
    _note.dispose();
    super.dispose();
  }

  String? _intRange(String? v, int min, int max, String msg) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return null;
    final n = int.tryParse(s);
    if (n == null || n < min || n > max) return msg;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      actionsOverflowDirection: VerticalDirection.up,
      actionsOverflowButtonSpacing: 12,
      title: Text(
        widget.existing == null ? 'Egzersiz ekle' : 'Egzersizi düzenle',
      ),
      scrollable: true,
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _day,
              maxLength: 40,
              decoration: const InputDecoration(labelText: 'Gün'),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Gün gerekli' : null,
            ),
            TextFormField(
              controller: _exercise,
              maxLength: 120,
              decoration: const InputDecoration(labelText: 'Egzersiz'),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Egzersiz gerekli' : null,
            ),
            TextFormField(
              controller: _sets,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Set'),
              validator: (v) => _intRange(v, 1, 99, 'Set 1-99 arası olmalı'),
            ),
            TextFormField(
              controller: _reps,
              maxLength: 40,
              decoration: const InputDecoration(
                labelText: 'Tekrar',
                hintText: 'örn. 12, 8-10, 30 sn',
              ),
            ),
            TextFormField(
              controller: _rest,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Dinlenme (saniye)'),
              validator: (v) =>
                  _intRange(v, 0, 3600, 'Dinlenme 0-3600 arası olmalı'),
            ),
            TextFormField(
              controller: _note,
              maxLength: 300,
              decoration: const InputDecoration(labelText: 'Not'),
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: () {
            if (!_form.currentState!.validate()) return;
            Navigator.of(context).pop(
              WorkoutItem(
                dayLabel: _day.text.trim(),
                exercise: _exercise.text.trim(),
                sets: int.tryParse(_sets.text.trim()),
                reps: _blankToNull(_reps.text),
                restSeconds: int.tryParse(_rest.text.trim()),
                note: _blankToNull(_note.text),
              ),
            );
          },
          child: const Text('Tamam'),
        ),
      ],
    );
  }
}
