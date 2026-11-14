import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/error_messages.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/unsaved_changes_guard.dart';
import '../../../packages/data/package_repository.dart';
import '../../data/schedule_repository.dart';
import '../../domain/schedule_models.dart';
import 'schedule_flows.dart';

/// "Ders aç" formu. [asAdmin] ise antrenör seçimi zorunludur.
class CreateClassScreen extends ConsumerStatefulWidget {
  const CreateClassScreen({super.key, this.asAdmin = false, this.initialDay});
  final bool asAdmin;
  final DateTime? initialDay;

  @override
  ConsumerState<CreateClassScreen> createState() => _CreateClassScreenState();
}

class _CreateClassScreenState extends ConsumerState<CreateClassScreen> {
  final _title = TextEditingController();
  final _duration = TextEditingController(text: '60');
  String? _categoryId;
  String? _trainerId;
  ClassType _type = ClassType.group;
  late DateTime _date = widget.initialDay ?? DateTime.now();
  TimeOfDay _time = const TimeOfDay(hour: 10, minute: 0);
  late final DateTime _initialDate = _date;
  bool _saving = false;
  String? _error;

  bool get _dirty =>
      _title.text.isNotEmpty ||
      _duration.text != '60' ||
      _categoryId != null ||
      _trainerId != null ||
      _type != ClassType.group ||
      _time != const TimeOfDay(hour: 10, minute: 0) ||
      !(_date.year == _initialDate.year &&
          _date.month == _initialDate.month &&
          _date.day == _initialDate.day);

  @override
  void initState() {
    super.initState();
    _title.addListener(_onChanged);
    _duration.addListener(_onChanged);
  }

  bool _lastDirty = false;
  void _onChanged() {
    if (_dirty != _lastDirty) setState(() => _lastDirty = _dirty);
  }

  @override
  void dispose() {
    _title.dispose();
    _duration.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final duration = int.tryParse(_duration.text.trim());
    if (_categoryId == null) {
      setState(() => _error = 'Kategori seçin.');
      return;
    }
    if (widget.asAdmin && _trainerId == null) {
      setState(() => _error = 'Antrenör seçin.');
      return;
    }
    if (duration == null || duration <= 0) {
      setState(() => _error = 'Geçerli bir süre girin (dakika).');
      return;
    }
    final startsAt = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _time.hour,
      _time.minute,
    );
    setState(() {
      _saving = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      await ref
          .read(scheduleRepositoryProvider)
          .createClass(
            categoryId: _categoryId!,
            classType: _type,
            startsAt: startsAt,
            durationMinutes: duration,
            title: _title.text,
            trainerId: widget.asAdmin ? _trainerId : null,
          );
      invalidateSchedule(ref);
      messenger.showSnackBar(const SnackBar(content: Text('Ders açıldı.')));
      nav.pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = friendlyError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cats =
        ref
            .watch(categoriesProvider)
            .value
            ?.where((c) => c.isActive)
            .toList() ??
        const [];
    final trainers = ref.watch(trainersProvider).value ?? const [];
    return UnsavedChangesGuard(
      dirty: _dirty,
      child: Scaffold(
        appBar: AppBar(title: const Text('Ders aç')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              initialValue: _categoryId,
              decoration: const InputDecoration(labelText: 'Kategori'),
              items: [
                for (final c in cats)
                  DropdownMenuItem(value: c.id, child: Text(c.name)),
              ],
              onChanged: (v) => setState(() => _categoryId = v),
            ),
            if (widget.asAdmin) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _trainerId,
                decoration: const InputDecoration(labelText: 'Antrenör'),
                items: [
                  for (final t in trainers)
                    DropdownMenuItem(value: t.id, child: Text(t.fullName)),
                ],
                onChanged: (v) => setState(() => _trainerId = v),
              ),
            ],
            const SizedBox(height: 12),
            SegmentedButton<ClassType>(
              segments: [
                for (final t in ClassType.values)
                  ButtonSegment(value: t, label: Text(t.label)),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 4),
            Text(
              _type == ClassType.individual
                  ? 'Bireysel ders: kontenjan 1'
                  : 'Grup dersi: kontenjan 6',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined),
              title: const Text('Tarih'),
              trailing: Text(formatDate(_date)),
              onTap: () async {
                final today = dayStart(DateTime.now());
                final d = await showDatePicker(
                  context: context,
                  initialDate: _date.isBefore(today) ? today : _date,
                  firstDate: today,
                  lastDate: today.add(const Duration(days: 365)),
                );
                if (d != null) setState(() => _date = d);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule),
              title: const Text('Saat'),
              trailing: Text(_time.format(context)),
              onTap: () async {
                final t = await showTimePicker(
                  context: context,
                  initialTime: _time,
                );
                if (t != null) setState(() => _time = t);
              },
            ),
            TextField(
              controller: _duration,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Süre (dakika)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Başlık (isteğe bağlı)',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: Text(_saving ? 'Kaydediliyor...' : 'Dersi aç'),
            ),
          ],
        ),
      ),
    );
  }
}
