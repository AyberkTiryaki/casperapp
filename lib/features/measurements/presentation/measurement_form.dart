import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/utils/formatters.dart';
import '../data/measurement_repository.dart';
import '../domain/measurement_models.dart';

/// Ölçüm ekleme formu. Kaydedilirse true döner.
Future<bool> showAddMeasurementDialog(
  BuildContext context,
  WidgetRef ref, {
  required String memberId,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final saved = await showDialog<bool>(
    context: context,
    builder: (_) => _AddMeasurementDialog(memberId: memberId),
  );
  if (saved != true) return false;
  ref.invalidate(measurementsProvider(memberId));
  messenger.showSnackBar(const SnackBar(content: Text('Ölçüm kaydedildi.')));
  return true;
}

class _AddMeasurementDialog extends ConsumerStatefulWidget {
  const _AddMeasurementDialog({required this.memberId});
  final String memberId;

  @override
  ConsumerState<_AddMeasurementDialog> createState() =>
      _AddMeasurementDialogState();
}

class _AddMeasurementDialogState extends ConsumerState<_AddMeasurementDialog> {
  final _form = GlobalKey<FormState>();
  final _controllers = {
    for (final m in MeasurementMetric.values) m: TextEditingController(),
  };
  final _note = TextEditingController();
  late DateTime _date = _today();
  bool _saving = false;
  String? _error;

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = _today();
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: today,
    );
    if (d != null) setState(() => _date = DateTime(d.year, d.month, d.day));
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final values = <MeasurementMetric, double>{};
    for (final e in _controllers.entries) {
      final v = parseDecimal(e.value.text);
      if (v != null) values[e.key] = v;
    }
    if (values.isEmpty) {
      setState(() => _error = 'En az bir ölçüm değeri girin.');
      return;
    }
    final note = _note.text.trim();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(measurementRepositoryProvider)
          .add(
            memberId: widget.memberId,
            measuredOn: _date,
            values: values,
            note: note.isEmpty ? null : note,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = friendlyError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      actionsOverflowDirection: VerticalDirection.up,
      actionsOverflowButtonSpacing: 12,
      title: const Text('Ölçüm ekle'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InkWell(
                  onTap: _saving ? null : _pickDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Tarih',
                      suffixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                    child: Text(formatDate(_date)),
                  ),
                ),
                for (final m in MeasurementMetric.values) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _controllers[m],
                    enabled: !_saving,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: m.label,
                      suffixText: m.unit,
                    ),
                    validator: (v) => validateMetricInput(m, v),
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: _note,
                  enabled: !_saving,
                  maxLength: 500,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Not (isteğe bağlı)',
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: AppColors.danger),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('Kaydet'),
        ),
      ],
    );
  }
}
