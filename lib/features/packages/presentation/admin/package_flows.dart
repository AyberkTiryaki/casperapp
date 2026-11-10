import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/utils/error_messages.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/uuid.dart';
import '../../../../core/widgets/async_value_view.dart' show isNetworkError;
import '../../data/package_repository.dart';
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
  final ok = await _confirm(
    context,
    'Paket ata',
    '${member.fullName} adlı üyeye "${picked.name}" paketi (${picked.sessionCount} ders, ${formatTl(picked.price)}) atanacak.',
  );
  if (!ok || !context.mounted) return;

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
