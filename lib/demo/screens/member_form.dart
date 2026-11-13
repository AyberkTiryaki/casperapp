import 'package:flutter/material.dart';

import '../data/studio_store.dart';
import '../models/models.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

/// Yeni üye ekleme ya da [existing] üyeyi düzenleme penceresini açar.
Future<void> showMemberForm(BuildContext context, {Member? existing}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _MemberFormDialog(existing: existing),
  );
}

class _MemberFormDialog extends StatefulWidget {
  const _MemberFormDialog({this.existing});

  final Member? existing;

  @override
  State<_MemberFormDialog> createState() => _MemberFormDialogState();
}

class _MemberFormDialogState extends State<_MemberFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late MembershipType _membership;
  late DateTime _end;
  String? _trainerId;
  String? _programId;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final m = widget.existing;
    _name = TextEditingController(text: m?.name ?? '');
    _phone = TextEditingController(text: m?.phone ?? '');
    _membership = m?.membership ?? MembershipType.aylik;
    _end =
        m?.membershipEnd ??
        gunBasi(DateTime.now()).add(Duration(days: _membership.days));
    _trainerId = m?.trainerId;
    _programId = m?.programId;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _end,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _end = picked);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final store = StoreScope.read(context);
    final m = widget.existing;
    if (m == null) {
      store.addMember(
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        membership: _membership,
        membershipEnd: _end,
        trainerId: _trainerId,
        programId: _programId,
      );
      showMessage(context, '${_name.text.trim()} eklendi.');
    } else {
      m
        ..name = _name.text.trim()
        ..phone = _phone.text.trim()
        ..membership = _membership
        ..membershipEnd = _end
        ..trainerId = _trainerId
        ..programId = _programId;
      store.updateMember(m);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return AlertDialog(
      title: Text(_isEdit ? 'Üyeyi Düzenle' : 'Yeni Üye'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  autofocus: !_isEdit,
                  decoration: const InputDecoration(labelText: 'Ad Soyad'),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => (v == null || v.trim().length < 2)
                      ? 'Ad soyad girin'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phone,
                  decoration: const InputDecoration(labelText: 'Telefon'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<MembershipType>(
                  initialValue: _membership,
                  decoration: const InputDecoration(labelText: 'Üyelik tipi'),
                  items: [
                    for (final t in MembershipType.values)
                      DropdownMenuItem(value: t, child: Text(t.label)),
                  ],
                  onChanged: (t) {
                    if (t == null) return;
                    setState(() {
                      _membership = t;
                      if (!_isEdit) {
                        _end = gunBasi(DateTime.now())
                            .add(Duration(days: t.days));
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Üyelik bitiş tarihi',
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(tarih(_end)),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: _trainerId,
                  decoration: const InputDecoration(labelText: 'Antrenör'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Yok')),
                    for (final t in store.trainers)
                      DropdownMenuItem(
                        value: t.id,
                        child: Text('${t.name} (${t.specialty})'),
                      ),
                  ],
                  onChanged: (v) => setState(() => _trainerId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: _programId,
                  decoration: const InputDecoration(
                    labelText: 'Antrenman programı',
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Yok')),
                    for (final p in store.programs)
                      DropdownMenuItem(value: p.id, child: Text(p.name)),
                  ],
                  onChanged: (v) => setState(() => _programId = v),
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
