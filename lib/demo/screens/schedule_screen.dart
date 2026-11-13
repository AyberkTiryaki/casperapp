import 'package:flutter/material.dart';

import '../data/studio_store.dart';
import '../models/models.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  DateTime _selected = gunBasi(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final today = gunBasi(DateTime.now());
    final days = List.generate(14, (i) => today.add(Duration(days: i)));
    final classes = store.classesOn(_selected);

    return Scaffold(
      appBar: AppBar(title: const Text('Ders Programı')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: store.trainers.isEmpty
            ? null
            : () => showDialog<void>(
                context: context,
                builder: (_) => _ClassFormDialog(day: _selected),
              ),
        icon: const Icon(Icons.add),
        label: const Text('Ders Ekle'),
      ),
      body: ContentWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 76,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                scrollDirection: Axis.horizontal,
                itemCount: days.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final d = days[i];
                  final count = store.classesOn(d).length;
                  return _DayChip(
                    day: d,
                    count: count,
                    selected: ayniGun(d, _selected),
                    onTap: () => setState(() => _selected = d),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Text(
                tarihGun(_selected),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Expanded(
              child: classes.isEmpty
                  ? const EmptyState(
                      icon: Icons.event_busy,
                      message: 'Bu gün için ders yok.\n"Ders Ekle" ile yeni ders oluşturabilirsiniz.',
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                      children: [
                        for (final c in classes)
                          _ClassCard(studioClass: c, store: store),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.day,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final DateTime day;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = selected ? scheme.onPrimary : scheme.onSurface;
    return Material(
      color: selected ? scheme.primary : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(
          width: 56,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(gunKisa(day), style: TextStyle(color: fg, fontSize: 12)),
              Text(
                '${day.day}',
                style: TextStyle(
                  color: fg,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                count == 0 ? '–' : '$count ders',
                style: TextStyle(color: fg, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({required this.studioClass, required this.store});

  final StudioClass studioClass;
  final StudioStore store;

  @override
  Widget build(BuildContext context) {
    final c = studioClass;
    final trainer = store.trainerById(c.trainerId);
    final ratio = c.capacity == 0 ? 0.0 : c.attendeeIds.length / c.capacity;
    final scheme = Theme.of(context).colorScheme;
    final isPast = c.end.isBefore(DateTime.now());

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => _BookingSheet(classId: c.id),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${saatAraligi(c.start, c.end)} • ${trainer?.name ?? '-'}'
                          '${isPast ? ' • tamamlandı' : ''}',
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${c.attendeeIds.length}/${c.capacity}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Seçenekler',
                    onSelected: (v) async {
                      if (v != 'sil') return;
                      final ok = await confirmDialog(
                        context,
                        title: 'Ders silinsin mi?',
                        message:
                            '${c.title} (${tarihGun(c.start)} ${saat(c.start)}) ve '
                            '${c.attendeeIds.length} rezervasyon silinecek.',
                      );
                      if (ok) store.deleteClass(c.id);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'sil', child: Text('Dersi sil')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ratio.clamp(0, 1),
                    minHeight: 6,
                    color: c.isFull ? scheme.error : scheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                c.isFull
                    ? 'Kontenjan dolu'
                    : '${c.capacity - c.attendeeIds.length} yer boş • rezervasyon için dokunun',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bir derse üye ekleyip çıkarmak için alt panel.
class _BookingSheet extends StatelessWidget {
  const _BookingSheet({required this.classId});

  final String classId;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final c = store.classes.where((x) => x.id == classId).firstOrNull;
    if (c == null) return const SizedBox.shrink();
    final members = [...store.members]
      ..sort((a, b) {
        final ab = c.attendeeIds.contains(a.id) ? 0 : 1;
        final bb = c.attendeeIds.contains(b.id) ? 0 : 1;
        return ab != bb ? ab - bb : a.name.compareTo(b.name);
      });

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (context, scroll) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            title: Text(c.title, style: Theme.of(context).textTheme.titleLarge),
            subtitle: Text(
              '${tarihGun(c.start)} • ${saatAraligi(c.start, c.end)}\n'
              'Katılımcı: ${c.attendeeIds.length}/${c.capacity}',
            ),
            isThreeLine: true,
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              controller: scroll,
              children: [
                for (final m in members)
                  CheckboxListTile(
                    value: c.attendeeIds.contains(m.id),
                    secondary: MemberAvatar(member: m),
                    title: Text(m.name),
                    subtitle: m.isExpired ? const Text('Üyelik bitmiş') : null,
                    onChanged: (_) {
                      final error = store.toggleBooking(c.id, m.id);
                      if (error != null) showMessage(context, error);
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassFormDialog extends StatefulWidget {
  const _ClassFormDialog({required this.day});

  final DateTime day;

  @override
  State<_ClassFormDialog> createState() => _ClassFormDialogState();
}

class _ClassFormDialogState extends State<_ClassFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _capacity = TextEditingController(text: '10');
  late DateTime _day = widget.day;
  TimeOfDay _time = const TimeOfDay(hour: 18, minute: 0);
  int _minutes = 60;
  String? _trainerId;

  @override
  void dispose() {
    _title.dispose();
    _capacity.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _day = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final start = DateTime(
      _day.year,
      _day.month,
      _day.day,
      _time.hour,
      _time.minute,
    );
    StoreScope.read(context).addClass(
      title: _title.text.trim(),
      trainerId: _trainerId!,
      start: start,
      duration: Duration(minutes: _minutes),
      capacity: int.parse(_capacity.text),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    _trainerId ??= store.trainers.first.id;
    final timeText =
        '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';

    return AlertDialog(
      title: const Text('Yeni Ders'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _title,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Ders adı',
                    hintText: 'Örn. Reformer Pilates',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Ders adı girin' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _trainerId,
                  decoration: const InputDecoration(labelText: 'Antrenör'),
                  items: [
                    for (final t in store.trainers)
                      DropdownMenuItem(value: t.id, child: Text(t.name)),
                  ],
                  onChanged: (v) => setState(() => _trainerId = v),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _pickDate,
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Tarih'),
                          child: Text(tarih(_day)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: _pickTime,
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Saat'),
                          child: Text(timeText),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: _minutes,
                        decoration: const InputDecoration(labelText: 'Süre'),
                        items: [
                          for (final m in const [30, 45, 50, 60, 75, 90])
                            DropdownMenuItem(value: m, child: Text('$m dk')),
                        ],
                        onChanged: (v) => setState(() => _minutes = v ?? 60),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _capacity,
                        decoration: const InputDecoration(
                          labelText: 'Kontenjan',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          final n = int.tryParse(v ?? '');
                          return (n == null || n < 1 || n > 200)
                              ? '1–200 arası'
                              : null;
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Vazgeç'),
        ),
        FilledButton(onPressed: _save, child: const Text('Kaydet')),
      ],
    );
  }
}
