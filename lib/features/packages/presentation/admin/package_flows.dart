import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/utils/error_messages.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/uuid.dart';
import '../../../../core/widgets/async_value_view.dart' show isNetworkError;
import '../../data/package_repository.dart';
import '../../../referrals/data/referral_repository.dart';
import '../../../referrals/domain/referral_models.dart';
import '../../domain/package_models.dart';

Future<bool> _confirm(BuildContext context, String title, String message,
    {String ok = 'Onayla'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Vazgeç')),
        FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true), child: Text(ok)),
      ],
    ),
  );
  return r == true;
}

bool _isCode(Object e, String code) =>
    e is PostgrestException && e.message.trim() == code;

/// "Paket ata" akışı. İşlem anahtarı bir kez üretilir; ağ hatasında aynı anahtarla tekrar denenir.
Future<void> runAssignFlow(
    BuildContext context, WidgetRef ref, MemberSummary member) async {
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
        const SnackBar(content: Text('Atanabilecek aktif paket tanımı yok.')));
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
                '${d.categoryName ?? ''} - ${d.name}\n${d.sessionCount} ders, ${d.validityDays} gün, ${formatTl(d.price)}'),
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
        final retry = await _confirm(context, 'Bağlantı hatası',
            'İşlem tamamlanamadı. Aynı işlemi tekrar denemek ister misiniz?',
            ok: 'Tekrar dene');
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
    BuildContext context, WidgetRef ref, MemberPackage pkg) async {
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
  final note = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Paketi dondur'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              '${formatDate(range.start)} - ${formatDate(range.end)} ($days gün) arasındaki rezervasyonlar iptal edilecek ve haklar iade edilecek. Paketin bitiş tarihi $days gün uzatılacak.'),
          const SizedBox(height: 12),
          TextField(
            controller: note,
            decoration: const InputDecoration(labelText: 'Not (isteğe bağlı)'),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Vazgeç')),
        FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Dondur')),
      ],
    ),
  );
  final noteText = note.text;
  note.dispose();
  if (ok != true) return;
  try {
    await ref.read(packageRepositoryProvider).freezePackage(
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
    final result =
        double.parse((d.price * (100 - applied) / 100).toStringAsFixed(2));
    return AlertDialog(
      title: const Text('Paket ata'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                '${widget.member.fullName} adlı üyeye "${d.name}" paketi (${d.sessionCount} ders) atanacak.'),
            const SizedBox(height: 12),
            if (_error != null)
              Text(friendlyError(_error!),
                  style: TextStyle(color: Theme.of(context).colorScheme.error))
            else if (s == null)
              const LinearProgressIndicator()
            else if (entitlement == 0)
              const Text('Bu üyenin referans indirimi hakkı yok.')
            else ...[
              Text(
                  'Referans indirimi hakkı: %$entitlement (${s.activeCount} aktif referans)'),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('İndirim uygula'),
                value: _apply,
                onChanged: (v) => setState(() => _apply = v),
              ),
              if (_apply)
                DropdownButtonFormField<int>(
                  initialValue: _percent,
                  decoration:
                      const InputDecoration(labelText: 'İndirim oranı (%)'),
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
            child: const Text('Vazgeç')),
        if (_error != null)
          TextButton(onPressed: _load, child: const Text('Tekrar dene')),
        FilledButton(
          onPressed:
              s == null ? null : () => Navigator.of(context).pop(applied),
          child: const Text('Onayla'),
        ),
      ],
    );
  }
}
