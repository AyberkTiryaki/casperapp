import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/error_messages.dart';
import '../../../packages/data/package_repository.dart';
import '../../data/schedule_repository.dart';
import '../../domain/schedule_models.dart';
import 'schedule_widgets.dart';

/// Rezervasyon/ders değişikliklerinden sonra ilgili tüm önbellekleri yeniler.
void invalidateSchedule(WidgetRef ref) {
  ref.invalidate(classesProvider);
  ref.invalidate(myReservationsProvider);
  ref.invalidate(participantsProvider);
  ref.invalidate(adminReservationsProvider);
  ref.invalidate(myPackagesProvider);
}

void _snack(ScaffoldMessengerState m, String text) =>
    m.showSnackBar(SnackBar(content: Text(text)));

/// Rezervasyon yapar (üye kendisi için; yönetici [memberId] ile üye adına).
/// Ağ hatasında anahtar korunur; kullanıcı tekrar denediğinde aynı anahtar kullanılır.
Future<bool> runBookFlow(
  BuildContext context,
  WidgetRef ref,
  StudioClass c, {
  String? memberId,
  String? memberName,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final who = memberName == null
      ? 'Bu derse'
      : '$memberName adlı üyeyi bu derse';
  final ok = await confirmDialog(
    context,
    'Rezervasyon yap',
    '$who rezervasyon yapılacak ve paketinden 1 ders hakkı düşülecek.\n${c.categoryName} - ${classTimeRange(c)}',
    ok: 'Rezervasyon yap',
  );
  if (!ok) return false;
  final repo = ref.read(scheduleRepositoryProvider);
  final holder = ref.read(bookingKeyHolderProvider);
  try {
    await holder.run(
      memberId == null ? c.id : '${c.id}:$memberId',
      (key) => repo.bookClass(
        classId: c.id,
        idempotencyKey: key,
        memberId: memberId,
      ),
    );
    invalidateSchedule(ref);
    _snack(messenger, 'Rezervasyon yapıldı.');
    return true;
  } catch (e) {
    invalidateSchedule(ref);
    _snack(messenger, friendlyError(e));
    return false;
  }
}

/// Üyenin kendi rezervasyonunu iptali (2 saat kuralı sunucuda da denetlenir).
Future<bool> runMemberCancelFlow(
  BuildContext context,
  WidgetRef ref, {
  required String reservationId,
  required DateTime startsAt,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  if (!canMemberCancel(startsAt, DateTime.now())) {
    _snack(
      messenger,
      'Dersin başlamasına 2 saatten az kaldığı için iptal edilemez.',
    );
    return false;
  }
  final ok = await confirmDialog(
    context,
    'Rezervasyonu iptal et',
    'Rezervasyonunuz iptal edilecek ve ders hakkınız iade edilecek.',
    ok: 'İptal et',
  );
  if (!ok) return false;
  try {
    await ref
        .read(scheduleRepositoryProvider)
        .cancelReservation(reservationId: reservationId);
    invalidateSchedule(ref);
    _snack(messenger, 'Rezervasyon iptal edildi.');
    return true;
  } catch (e) {
    invalidateSchedule(ref);
    _snack(messenger, friendlyError(e));
    return false;
  }
}

/// Yönetici rezervasyon iptali: hak iadesi seçilir.
Future<bool> runAdminCancelReservationFlow(
  BuildContext context,
  WidgetRef ref, {
  required String reservationId,
  required String memberName,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final r = await showDialog<({bool refund, String? reason})>(
    context: context,
    builder: (_) => RefundDialog(
      title: 'Rezervasyonu iptal et',
      message: '$memberName adlı üyenin rezervasyonu iptal edilecek.',
    ),
  );
  if (r == null) return false;
  try {
    await ref
        .read(scheduleRepositoryProvider)
        .cancelReservation(
          reservationId: reservationId,
          refund: r.refund,
          reason: r.reason,
        );
    invalidateSchedule(ref);
    _snack(messenger, 'Rezervasyon iptal edildi.');
    return true;
  } catch (e) {
    invalidateSchedule(ref);
    _snack(messenger, friendlyError(e));
    return false;
  }
}

/// Yönetici: başlamış dersteki rezervasyonu "gelmedi" yapar veya geri alır (hak değişmez).
Future<bool> runSetNoShowFlow(
  BuildContext context,
  WidgetRef ref, {
  required String reservationId,
  required bool noShow,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref.read(scheduleRepositoryProvider).setNoShow(reservationId, noShow);
    invalidateSchedule(ref);
    _snack(
      messenger,
      noShow ? 'Gelmedi olarak işaretlendi.' : 'Gelmedi işareti kaldırıldı.',
    );
    return true;
  } catch (e) {
    invalidateSchedule(ref);
    _snack(messenger, friendlyError(e));
    return false;
  }
}

/// Dersin tamamını iptal eder; hak iadesi ve neden seçilir.
Future<bool> runCancelClassFlow(
  BuildContext context,
  WidgetRef ref,
  StudioClass c,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final r = await showDialog<({bool refund, String? reason})>(
    context: context,
    builder: (_) => RefundDialog(
      title: 'Dersi iptal et',
      message:
          '${c.categoryName} - ${classTimeRange(c)} dersi ve tüm rezervasyonları iptal edilecek.',
    ),
  );
  if (r == null) return false;
  try {
    await ref
        .read(scheduleRepositoryProvider)
        .cancelClass(classId: c.id, refund: r.refund, reason: r.reason);
    invalidateSchedule(ref);
    _snack(messenger, 'Ders iptal edildi.');
    return true;
  } catch (e) {
    invalidateSchedule(ref);
    _snack(messenger, friendlyError(e));
    return false;
  }
}

/// Hak iadesi (evet/hayır) ve isteğe bağlı neden seçtiren diyalog.
class RefundDialog extends StatefulWidget {
  const RefundDialog({super.key, required this.title, required this.message});
  final String title;
  final String message;

  @override
  State<RefundDialog> createState() => _RefundDialogState();
}

class _RefundDialogState extends State<RefundDialog> {
  bool _refund = true;
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      actionsOverflowDirection: VerticalDirection.up,
      actionsOverflowButtonSpacing: 12,
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.message),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Ders hakkı iade edilsin'),
              value: _refund,
              onChanged: (v) => setState(() => _refund = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reason,
              decoration: const InputDecoration(
                labelText: 'Neden (isteğe bağlı)',
              ),
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
          onPressed: () =>
              Navigator.of(context)
                  .pop((refund: _refund, reason: _reason.text)),
          child: const Text('İptal et'),
        ),
      ],
    );
  }
}
