import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/utils/error_messages.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/uuid.dart';
import '../../../../core/widgets/async_value_view.dart' show isNetworkError;
import '../../../../core/widgets/text_controller_scope.dart';
import '../../data/package_repository.dart';
import '../../../referrals/data/referral_repository.dart';
import '../../../referrals/domain/referral_models.dart';
import '../../domain/package_models.dart';

Future<bool> _confirm(
  BuildContext context,
  String title,
  String message, {
  String ok = 'Onayla',
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(ok),
        ),
      ],
    ),
  );
  return r == true;
}

bool _isCode(Object e, String code) =>
    e is PostgrestException && e.message.trim() == code;

/// "Paket ata" akışı. İşlem anahtarı bir kez üretilir; ağ hatasında aynı anahtarla tekrar denenir.
Future<void> runAssignFlow(
  BuildContext context,
  WidgetRef ref,
  MemberSummary member,
) async {
  final messenger = ScaffoldMessenger.of(context);
  List<PackageDefinition> defs;
  try {
    defs = (await ref.read(definitionsProvider.future))
        .where((d) => d.isActive)
        .toList();
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    return;
  }
  if (!context.mounted) return;
  if (defs.isEmpty) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Atanabilecek aktif paket tanımı yok.')),
    );
    return;
  }
  final picked = await showDialog<PackageDefinition>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: const Text('Paket seçin'),
      children: [
        for (final d in defs)
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop(d),
            child: Text(
              '${d.categoryName ?? ''} - ${d.name}\n${d.sessionCount} ders, ${d.validityDays} gün, ${formatTl(d.price)}',
            ),
          ),
      ],
    ),
  );
  if (picked == null || !context.mounted) return;
  final discount = await showDialog<int>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _AssignDialog(member: member, definition: picked),
  );
  if (discount == null || !context.mounted) return;

  final key = generateUuidV4();
  final repo = ref.read(packageRepositoryProvider);
  var replace = false;
  while (true) {
    try {
      await repo.assignPackage(
        memberId: member.id,
        definitionId: picked.id,
        idempotencyKey: key,
        replaceExisting: replace,
        discountPercent: discount,
      );
      ref.invalidate(memberPackagesProvider(member.id));
      messenger.showSnackBar(const SnackBar(content: Text('Paket atandı.')));
      return;
    } catch (e) {
      if (!context.mounted) return;
      if (!replace && _isCode(e, 'ACTIVE_PACKAGE_EXISTS')) {
        final go = await _confirm(
          context,
          'Aktif paket var',
          'Bu kategoride aktif paket var. Erken sonlandırıp yenisini aktif etmek ister misiniz? Uygun gelecek rezervasyonlar yeni pakete aktarılır; aktarılamayanlar iptal edilip hak iade edilir.',
          ok: 'Sonlandır ve ata',
        );
        if (!go || !context.mounted) return;
        replace = true;
        continue;
      }
      if (isNetworkError(e)) {
        final retry = await _confirm(
          context,
          'Bağlantı hatası',
          'İşlem tamamlanamadı. Aynı işlemi tekrar denemek ister misiniz?',
          ok: 'Tekrar dene',
        );
        if (retry && context.mounted) continue;
        return;
      }
      if (_isCode(e, 'DISCOUNT_EXCEEDS_ENTITLEMENT')) {
        ref.invalidate(referralSummaryProvider(member.id));
      }
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
      return;
    }
  }
}

/// "Dondur" akışı.
Future<void> runFreezeFlow(
  BuildContext context,
  WidgetRef ref,
  MemberPackage pkg,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final last = DateTime(pkg.endsAt.year, pkg.endsAt.month, pkg.endsAt.day);
  final range = await showDateRangePicker(
    context: context,
    firstDate: today,
    lastDate: last.isBefore(today) ? today : last,
    helpText: 'Dondurma aralığı',
    saveText: 'Tamam',
  );
  if (range == null || !context.mounted) return;
  final days = range.end.difference(range.start).inDays + 1;
  // Dondur: not metni döner; Vazgeç: null
  final noteText = await showDialog<String>(
    context: context,
    builder: (ctx) => TextControllerScope(
      builder: (ctx, note) => AlertDialog(
        title: const Text('Paketi dondur'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${formatDate(range.start)} - ${formatDate(range.end)} ($days gün) arasındaki rezervasyonlar iptal edilecek ve haklar iade edilecek. Paketin bitiş tarihi $days gün uzatılacak.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: note,
              decoration: const InputDecoration(
                labelText: 'Not (isteğe bağlı)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(note.text),
            child: const Text('Dondur'),
          ),
        ],
      ),
    ),
  );
  if (noteText == null) return;
  try {
    await ref
        .read(packageRepositoryProvider)
        .freezePackage(
          packageId: pkg.id,
          startDate: range.start,
          endDate: range.end,
          note: noteText,
        );
    ref.invalidate(memberPackagesProvider(pkg.memberId));
    ref.invalidate(freezesProvider(pkg.id));
    ref.invalidate(ledgerProvider(pkg.id));
    messenger.showSnackBar(const SnackBar(content: Text('Paket donduruldu.')));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
  }
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Dondurmanın son günü (bitiş dışlayıcı olduğundan 1 gün geri).
DateTime freezeLastDay(PackageFreeze f) {
  final e = f.endsAt.toLocal();
  return DateTime(e.year, e.month, e.day - 1);
}

/// Dondurma henüz sona ermemişse (son gün >= bugün) erken bitirilebilir.
bool canEndFreeze(PackageFreeze f, DateTime now) =>
    !freezeLastDay(f).isBefore(_dateOnly(now));

/// Paketin dondurmalarını listeler; bitirilebilir olanlar için seçilen dondurmayı döndürür.
Future<void> showFreezesSheet(
  BuildContext context,
  WidgetRef ref,
  MemberPackage pkg,
) async {
  final now = DateTime.now();
  final freezes = [...pkg.freezes]
    ..sort((a, b) => b.startsAt.compareTo(a.startsAt));
  final picked = await showModalBottomSheet<PackageFreeze>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          for (final f in freezes)
            ListTile(
              leading: const Icon(Icons.ac_unit),
              title: Text(
                '${formatDate(f.startsAt)} - ${formatDate(freezeLastDay(f))} (${f.days} gün)',
              ),
              subtitle: Text(
                f.note == null || f.note!.isEmpty
                    ? (canEndFreeze(f, now)
                          ? 'Devam ediyor / yaklaşan'
                          : 'Sona erdi')
                    : f.note!,
              ),
              trailing: canEndFreeze(f, now)
                  ? TextButton(
                      onPressed: () => Navigator.of(ctx).pop(f),
                      child: const Text('Dondurmayı bitir'),
                    )
                  : null,
            ),
        ],
      ),
    ),
  );
  if (picked == null || !context.mounted) return;
  await runEndFreezeFlow(context, ref, pkg, picked);
}

/// "Dondurmayı bitir" akışı: şimdi bitir veya yeni son gün seç.
Future<void> runEndFreezeFlow(
  BuildContext context,
  WidgetRef ref,
  MemberPackage pkg,
  PackageFreeze freeze,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final today = _dateOnly(DateTime.now());
  final first = _dateOnly(freeze.startsAt);
  final oldLast = freezeLastDay(freeze);
  final yesterday = DateTime(today.year, today.month, today.day - 1);
  final dayBeforeFirst = DateTime(first.year, first.month, first.day - 1);
  final minLast = dayBeforeFirst.isAfter(yesterday)
      ? dayBeforeFirst
      : yesterday;
  final maxLast = DateTime(oldLast.year, oldLast.month, oldLast.day - 1);
  final canPick = !minLast.isAfter(maxLast);
  final started = !first.isAfter(today);

  final choice = await showDialog<String>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: const Text('Dondurmayı bitir'),
      children: [
        SimpleDialogOption(
          onPressed: () => Navigator.of(ctx).pop('now'),
          child: Text(
            started
                ? 'Şimdi bitir (paket bugünden itibaren kullanılabilir)'
                : 'Dondurmayı tamamen kaldır',
          ),
        ),
        if (canPick)
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop('pick'),
            child: const Text('Yeni son gün seç'),
          ),
      ],
    ),
  );
  if (choice == null || !context.mounted) return;

  DateTime? lastDay;
  if (choice == 'pick') {
    lastDay = await showDatePicker(
      context: context,
      initialDate: maxLast,
      firstDate: minLast,
      lastDate: maxLast,
      helpText: 'Dondurmanın yeni son günü',
    );
    if (lastDay == null || !context.mounted) return;
  }
  final removed = lastDay == null ? null : oldLast.difference(lastDay).inDays;
  final ok = await _confirm(
    context,
    'Dondurmayı bitir',
    lastDay == null
        ? (started
              ? 'Dondurma bugünden itibaren sona erecek. Kalan dondurma günleri paketin bitiş tarihinden düşülecek. Dondurma sırasında iptal edilen rezervasyonlar geri gelmez.'
              : 'Dondurma tamamen kaldırılacak ve dondurma günleri paketin bitiş tarihinden düşülecek.')
        : 'Dondurmanın son günü ${formatDate(lastDay)} olacak. $removed gün paketin bitiş tarihinden düşülecek. İptal edilen rezervasyonlar geri gelmez.',
    ok: 'Bitir',
  );
  if (!ok) return;
  try {
    await ref
        .read(packageRepositoryProvider)
        .endFreeze(freeze.id, lastDay: lastDay);
    ref.invalidate(memberPackagesProvider(pkg.memberId));
    ref.invalidate(freezesProvider(pkg.id));
    ref.invalidate(ledgerProvider(pkg.id));
    messenger.showSnackBar(
      const SnackBar(content: Text('Dondurma güncellendi.')),
    );
  } catch (e) {
    ref.invalidate(memberPackagesProvider(pkg.memberId));
    messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
  }
}

/// "Hak düzelt" akışı: +/- miktar ve zorunlu not.
Future<void> runAdjustCreditsFlow(
  BuildContext context,
  WidgetRef ref,
  MemberPackage pkg,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final r = await showDialog<({int delta, String note})>(
    context: context,
    builder: (_) => _AdjustDialog(package: pkg),
  );
  if (r == null) return;
  try {
    await ref
        .read(packageRepositoryProvider)
        .adjustCredits(pkg.id, r.delta, r.note);
    ref.invalidate(memberPackagesProvider(pkg.memberId));
    ref.invalidate(freezesProvider(pkg.id));
    ref.invalidate(ledgerProvider(pkg.id));
    messenger.showSnackBar(const SnackBar(content: Text('Hak düzeltildi.')));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
  }
}

class _AdjustDialog extends StatefulWidget {
  const _AdjustDialog({required this.package});
  final MemberPackage package;

  @override
  State<_AdjustDialog> createState() => _AdjustDialogState();
}

class _AdjustDialogState extends State<_AdjustDialog> {
  final _amount = TextEditingController(text: '1');
  final _note = TextEditingController();
  bool _add = true;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    final n = int.tryParse(_amount.text.trim());
    if (n == null || n < 1 || n > 100) {
      setState(() => _error = 'Miktar 1 ile 100 arasında olmalı.');
      return;
    }
    final delta = _add ? n : -n;
    if (widget.package.remainingCredits + delta < 0) {
      setState(() => _error = 'Hak sıfırın altına düşemez.');
      return;
    }
    if (_note.text.trim().isEmpty) {
      setState(() => _error = 'Not zorunludur.');
      return;
    }
    Navigator.of(context).pop((delta: delta, note: _note.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Hak düzelt'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mevcut hak: ${widget.package.remainingCredits}'),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Ekle (+)')),
                ButtonSegment(value: false, label: Text('Düş (-)')),
              ],
              selected: {_add},
              onSelectionChanged: (s) => setState(() => _add = s.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Miktar'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              decoration: const InputDecoration(labelText: 'Not (zorunlu)'),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Vazgeç'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Onayla')),
      ],
    );
  }
}

/// Paket atama onayı: referans indirimi hakkını yükler; seçilen indirimi (0 olabilir) döndürür.
class _AssignDialog extends ConsumerStatefulWidget {
  const _AssignDialog({required this.member, required this.definition});
  final MemberSummary member;
  final PackageDefinition definition;

  @override
  ConsumerState<_AssignDialog> createState() => _AssignDialogState();
}

class _AssignDialogState extends ConsumerState<_AssignDialog> {
  ReferralSummary? _summary;
  Object? _error;
  bool _apply = false;
  int _percent = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final s = await ref
          .read(referralRepositoryProvider)
          .summary(userId: widget.member.id);
      if (!mounted) return;
      setState(() {
        _summary = s;
        _percent = s.discountPercent;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.definition;
    final s = _summary;
    final entitlement = s?.discountPercent ?? 0;
    final applied = (_apply && entitlement > 0) ? _percent : 0;
    final result = double.parse(
      (d.price * (100 - applied) / 100).toStringAsFixed(2),
    );
    return AlertDialog(
      title: const Text('Paket ata'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.member.fullName} adlı üyeye "${d.name}" paketi (${d.sessionCount} ders) atanacak.',
            ),
            const SizedBox(height: 12),
            if (_error != null)
              Text(
                friendlyError(_error!),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              )
            else if (s == null)
              const LinearProgressIndicator()
            else if (entitlement == 0)
              const Text('Bu üyenin referans indirimi hakkı yok.')
            else ...[
              Text(
                'Referans indirimi hakkı: %$entitlement (${s.activeCount} aktif referans)',
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('İndirim uygula'),
                value: _apply,
                onChanged: (v) => setState(() => _apply = v),
              ),
              if (_apply)
                DropdownButtonFormField<int>(
                  initialValue: _percent,
                  decoration: const InputDecoration(
                    labelText: 'İndirim oranı (%)',
                  ),
                  items: [
                    for (var p = 5; p <= entitlement; p += 5)
                      DropdownMenuItem(value: p, child: Text('%$p')),
                  ],
                  onChanged: (v) => setState(() => _percent = v ?? _percent),
                ),
            ],
            const SizedBox(height: 12),
            Text('Liste fiyatı: ${formatTl(d.price)}'),
            Text('İndirim: %$applied'),
            Text('Ödenecek tutar: ${formatTl(result)}'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Vazgeç'),
        ),
        if (_error != null)
          TextButton(onPressed: _load, child: const Text('Tekrar dene')),
        FilledButton(
          onPressed: s == null
              ? null
              : () => Navigator.of(context).pop(applied),
          child: const Text('Onayla'),
        ),
      ],
    );
  }
}
