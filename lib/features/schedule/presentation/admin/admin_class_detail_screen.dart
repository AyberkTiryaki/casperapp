import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/empty_view.dart';
import '../../../packages/data/package_repository.dart';
import '../../../packages/domain/package_models.dart';
import '../../data/schedule_repository.dart';
import '../../domain/schedule_models.dart';
import '../shared/schedule_flows.dart';
import '../shared/schedule_widgets.dart';

class AdminClassDetailScreen extends ConsumerWidget {
  const AdminClassDetailScreen({super.key, required StudioClass item})
    : snapshot = item;

  /// Ekran açılırken geçen kopya; güncel veri bulunamazsa bu kullanılır.
  final StudioClass snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Güncel katılım sayısı için dersin gününü yeniden okur (mutasyonlarda invalidate edilir).
    final fresh = ref
        .watch(
          classesProvider((
            day: dayStart(snapshot.startsAt),
            categoryId: null,
            trainerId: null,
            includeCancelled: true,
          )),
        )
        .value
        ?.where((c) => c.id == snapshot.id)
        .firstOrNull;
    final item = fresh ?? snapshot;
    final async = ref.watch(adminReservationsProvider(item.id));
    final canBook = !item.isCancelled && !item.hasStarted(DateTime.now());
    return Scaffold(
      appBar: AppBar(title: const Text('Ders detayı')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ClassInfo(item),
          const SizedBox(height: 12),
          if (!item.isCancelled)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (canBook)
                  FilledButton.icon(
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    label: const Text('Üye ekle'),
                    onPressed: () async {
                      final m = await showDialog<MemberSummary>(
                        context: context,
                        builder: (_) => const MemberPickerDialog(),
                      );
                      if (m == null || !context.mounted) return;
                      await runBookFlow(
                        context,
                        ref,
                        item,
                        memberId: m.id,
                        memberName: m.fullName,
                      );
                    },
                  ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Dersi iptal et'),
                  onPressed: () async {
                    final nav = Navigator.of(context);
                    final done = await runCancelClassFlow(context, ref, item);
                    if (done) nav.pop();
                  },
                ),
              ],
            ),
          const SizedBox(height: 16),
          Text('Rezervasyonlar', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          AsyncValueView<List<AdminClassReservation>>(
            value: async,
            onRetry: () => ref.invalidate(adminReservationsProvider(item.id)),
            data: (items) => items.isEmpty
                ? const EmptyView(
                    title: 'Rezervasyon yok',
                    icon: Icons.event_seat_outlined,
                  )
                : Column(
                    children: [
                      for (final r in items)
                        Card(
                          child: ListTile(
                            title: Text(r.fullName),
                            subtitle: Text(_statusText(r)),
                            leading: r.status == 'no_show'
                                ? const Icon(
                                    Icons.person_off_outlined,
                                    color: AppColors.danger,
                                  )
                                : null,
                            trailing: _trailing(context, ref, item, r),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget? _trailing(
    BuildContext context,
    WidgetRef ref,
    StudioClass item,
    AdminClassReservation r,
  ) {
    if (item.isCancelled) return null;
    final started = item.hasStarted(DateTime.now());
    if (started && (r.status == 'booked' || r.status == 'no_show')) {
      final noShow = r.status == 'no_show';
      return TextButton(
        onPressed: () => runSetNoShowFlow(
          context,
          ref,
          reservationId: r.reservationId,
          noShow: !noShow,
        ),
        child: Text(
          noShow ? 'Gelmedi işaretini kaldır' : 'Gelmedi olarak işaretle',
        ),
      );
    }
    if (r.status == 'booked') {
      return IconButton(
        tooltip: 'Rezervasyonu iptal et',
        icon: const Icon(Icons.close, color: AppColors.danger),
        onPressed: () => runAdminCancelReservationFlow(
          context,
          ref,
          reservationId: r.reservationId,
          memberName: r.fullName,
        ),
      );
    }
    return null;
  }

  String _statusText(AdminClassReservation r) {
    switch (r.status) {
      case 'cancelled':
        final base = r.creditRefunded
            ? 'İptal edildi (hak iade edildi)'
            : 'İptal edildi (hak iade edilmedi)';
        return r.cancelReason == null || r.cancelReason!.isEmpty
            ? base
            : '$base - ${r.cancelReason}';
      case 'no_show':
        return 'Gelmedi';
      default:
        return 'Rezervasyon aktif';
    }
  }
}

/// Üye arama diyaloğu; seçilen üyeyi döndürür.
class MemberPickerDialog extends ConsumerStatefulWidget {
  const MemberPickerDialog({super.key});

  @override
  ConsumerState<MemberPickerDialog> createState() => _MemberPickerDialogState();
}

class _MemberPickerDialogState extends ConsumerState<MemberPickerDialog> {
  final _controller = TextEditingController();
  Timer? _debounce;
  AsyncValue<List<MemberSummary>> _result = const AsyncLoading();
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    final seq = ++_seq;
    setState(() => _result = const AsyncLoading());
    try {
      final r = await ref
          .read(packageRepositoryProvider)
          .searchMembers(q.trim());
      if (mounted && seq == _seq) setState(() => _result = AsyncData(r));
    } catch (e, st) {
      if (mounted && seq == _seq) setState(() => _result = AsyncError(e, st));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Üye seçin'),
      content: SizedBox(
        width: double.maxFinite,
        height: 360,
        child: Column(
          children: [
            TextField(
              controller: _controller,
              onChanged: (v) {
                _debounce?.cancel();
                _debounce = Timer(
                  const Duration(milliseconds: 400),
                  () => _search(v),
                );
              },
              decoration: const InputDecoration(
                labelText: 'Üye ara',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: AsyncValueView<List<MemberSummary>>(
                value: _result,
                onRetry: () => _search(_controller.text),
                data: (items) => items.isEmpty
                    ? const EmptyView(
                        title: 'Üye bulunamadı',
                        icon: Icons.person_search,
                      )
                    : ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (_, i) => ListTile(
                          leading: const Icon(Icons.person_outline),
                          title: Text(items[i].fullName),
                          subtitle: items[i].email == null
                              ? null
                              : Text(items[i].email!),
                          onTap: () => Navigator.of(context).pop(items[i]),
                        ),
                      ),
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
      ],
    );
  }
}
