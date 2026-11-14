import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/supabase.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_view.dart';
import '../../profile/deletion_request.dart';
import '../data/admin_repository.dart';
import '../../../core/widgets/home_button.dart';

class DeletionItem {
  const DeletionItem(this.request, this.name);
  final DeletionRequest request;
  final String name;
}

final deletionRequestsProvider = FutureProvider.autoDispose<List<DeletionItem>>(
  (ref) async {
    final rows = await supabase
        .from('account_deletion_requests')
        .select()
        .order('requested_at', ascending: false)
        .limit(200);
    final reqs = rows.map(DeletionRequest.fromJson).toList();
    var names = <String, String>{};
    try {
      names = await ref
          .read(adminRepositoryProvider)
          .names(reqs.map((r) => r.userId));
    } catch (_) {
      // Ad çözümlenemezse talepler yine gösterilir.
    }
    final items = [
      for (final r in reqs)
        DeletionItem(r, names[r.userId] ?? 'Bilinmeyen kullanıcı'),
    ];
    // Bekleyenler önce; her grup kendi içinde yeniden eskiye.
    return [
      ...items.where((i) => i.request.status == DeletionStatus.pending),
      ...items.where((i) => i.request.status != DeletionStatus.pending),
    ];
  },
);

class DeletionRequestsScreen extends ConsumerWidget {
  const DeletionRequestsScreen({super.key});

  Future<void> _decide(
    BuildContext context,
    WidgetRef ref,
    DeletionItem item,
    DeletionStatus status,
  ) async {
    final done = status == DeletionStatus.processed;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        actionsOverflowDirection: VerticalDirection.up,
        actionsOverflowButtonSpacing: 12,
        title: Text(done ? 'Tamamlandı olarak işaretle' : 'Talebi reddet'),
        content: Text(
          done
              ? 'Bu işlem yalnızca talebi tamamlandı olarak işaretler. Verilerin '
                    'fiilen silinmesi/anonimleştirilmesi şimdilik ayrı ve manuel '
                    'bir adımdır; otomatik yapılmaz.'
              : '${item.name} kullanıcısının silme talebi reddedilecek.',
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Onayla'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    var msg = done
        ? 'Talep tamamlandı olarak işaretlendi.'
        : 'Talep reddedildi.';
    try {
      await supabase
          .from('account_deletion_requests')
          .update({
            'status': status.name,
            'processed_at': DateTime.now().toUtc().toIso8601String(),
            'processed_by': supabase.auth.currentUser?.id,
          })
          .eq('id', item.request.id);
      ref.invalidate(deletionRequestsProvider);
    } catch (e) {
      msg = friendlyError(e);
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(deletionRequestsProvider);
    return Scaffold(
      appBar: AppBar(
        actions: const [HomeButton()],
        title: const Text('Hesap silme talepleri'),
      ),
      body: SafeArea(
        child: AsyncValueView<List<DeletionItem>>(
          value: value,
          onRetry: () => ref.invalidate(deletionRequestsProvider),
          data: (items) => RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(deletionRequestsProvider);
              await ref.read(deletionRequestsProvider.future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Not: "Tamamlandı" yalnızca talebi kapatır. Kişisel verilerin '
                  'fiilen anonimleştirilmesi şimdilik manuel/ayrı bir adımdır.',
                ),
                const SizedBox(height: 12),
                if (items.isEmpty)
                  const EmptyView(title: 'Silme talebi yok')
                else
                  for (final i in items)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              i.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${i.request.status.label} - talep: ${formatDate(i.request.requestedAt)}',
                            ),
                            if (i.request.note != null) ...[
                              const SizedBox(height: 4),
                              Text('Not: ${i.request.note}'),
                            ],
                            if (i.request.status == DeletionStatus.pending) ...[
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 10,
                                children: [
                                  FilledButton(
                                    onPressed: () => _decide(
                                      context,
                                      ref,
                                      i,
                                      DeletionStatus.processed,
                                    ),
                                    child: const Text(
                                      'Tamamlandı olarak işaretle',
                                    ),
                                  ),
                                  OutlinedButton(
                                    onPressed: () => _decide(
                                      context,
                                      ref,
                                      i,
                                      DeletionStatus.rejected,
                                    ),
                                    child: const Text('Reddet'),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
