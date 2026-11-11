import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/error_messages.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_view.dart';
import '../data/referral_repository.dart';
import '../domain/referral_models.dart';
import 'my_referrals_screen.dart' show ReferralStatusChip;

class AdminReferralsScreen extends ConsumerStatefulWidget {
  const AdminReferralsScreen({super.key});

  @override
  ConsumerState<AdminReferralsScreen> createState() =>
      _AdminReferralsScreenState();
}

class _AdminReferralsScreenState extends ConsumerState<AdminReferralsScreen> {
  String? _filter = 'pending';

  static const _filters = <(String?, String)>[
    (null, 'Tümü'),
    ('pending', 'Bekleyen'),
    ('approved', 'Onaylı'),
    ('rejected', 'Reddedilmiş'),
  ];

  Future<void> _decide(AdminReferral r, bool approve) async {
    final note = TextEditingController();
    final changing = r.status != ReferralStatus.pending;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(approve ? 'Referansı onayla' : 'Referansı reddet'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${r.referrerName} → ${r.referredName} referansı ${approve ? 'onaylanacak' : 'reddedilecek'}.${changing ? ' (Önceki karar değiştirilecek.)' : ''}',
            ),
            if (!approve) ...[
              const SizedBox(height: 12),
              TextField(
                controller: note,
                decoration: const InputDecoration(
                  labelText: 'Not (isteğe bağlı)',
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(approve ? 'Onayla' : 'Reddet'),
          ),
        ],
      ),
    );
    final noteText = note.text;
    note.dispose();
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(referralRepositoryProvider)
          .decide(
            referralId: r.id,
            approve: approve,
            note: approve ? null : noteText,
          );
      ref.invalidate(adminReferralsProvider);
      messenger.showSnackBar(
        const SnackBar(content: Text('Karar kaydedildi.')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(adminReferralsProvider(_filter));
    return Scaffold(
      appBar: AppBar(title: const Text('Referanslar')),
      body: Column(
        children: [
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                for (final f in _filters)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f.$2),
                      selected: _filter == f.$1,
                      onSelected: (_) => setState(() => _filter = f.$1),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: AsyncValueView<List<AdminReferral>>(
              value: async,
              onRetry: () => ref.invalidate(adminReferralsProvider),
              data: (items) => RefreshIndicator(
                onRefresh: () async => ref.invalidate(adminReferralsProvider),
                child: items.isEmpty
                    ? ListView(
                        children: const [
                          SizedBox(height: 120),
                          EmptyView(
                            title: 'Referans yok',
                            icon: Icons.group_add_outlined,
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => _ReferralCard(
                          r: items[i],
                          onApprove: () => _decide(items[i], true),
                          onReject: () => _decide(items[i], false),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReferralCard extends StatelessWidget {
  const _ReferralCard({
    required this.r,
    required this.onApprove,
    required this.onReject,
  });
  final AdminReferral r;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final pending = r.status == ReferralStatus.pending;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Getiren: ${r.referrerName}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                ReferralStatusChip(r.status),
              ],
            ),
            Text(
              'Kod: ${r.referrerCode ?? '-'} - Güncel indirim: %${r.referrerDiscountPercent}',
            ),
            const SizedBox(height: 4),
            Text('Getirilen: ${r.referredName}'),
            Text(
              r.referredHasActivePackage
                  ? 'Aktif paketi var'
                  : 'Aktif paketi yok',
            ),
            if (r.createdAt != null) Text('Tarih: ${formatDate(r.createdAt!)}'),
            if (r.decisionNote != null && r.decisionNote!.isNotEmpty)
              Text('Not: ${r.decisionNote}'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (pending) ...[
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 40),
                    ),
                    onPressed: onApprove,
                    child: const Text('Onayla'),
                  ),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 40),
                    ),
                    onPressed: onReject,
                    child: const Text('Reddet'),
                  ),
                ] else
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 40),
                    ),
                    onPressed: r.status == ReferralStatus.approved
                        ? onReject
                        : onApprove,
                    child: const Text('Kararı değiştir'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
