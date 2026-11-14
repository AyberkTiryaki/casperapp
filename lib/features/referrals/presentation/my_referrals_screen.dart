import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/async_value_view.dart';
import '../data/referral_repository.dart';
import '../domain/referral_models.dart';
import '../../../core/widgets/home_button.dart';

Color referralStatusColor(ReferralStatus s) => switch (s) {
  ReferralStatus.pending => Colors.orange,
  ReferralStatus.approved => Colors.green,
  ReferralStatus.rejected => Colors.red,
};

class ReferralStatusChip extends StatelessWidget {
  const ReferralStatusChip(this.status, {super.key});
  final ReferralStatus status;

  @override
  Widget build(BuildContext context) {
    final c = referralStatusColor(status);
    return Chip(
      label: Text(status.label, style: TextStyle(color: c, fontSize: 12)),
      side: BorderSide(color: c),
      backgroundColor: c.withValues(alpha: 0.1),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
    );
  }
}

class MyReferralsScreen extends ConsumerWidget {
  const MyReferralsScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(referralSummaryProvider(null));
    ref.invalidate(myReferralsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final summary = ref.watch(referralSummaryProvider(null));
    final list = ref.watch(myReferralsProvider);
    final combined = summary.hasError
        ? AsyncValue<void>.error(summary.error!, summary.stackTrace!)
        : list.hasError
        ? AsyncValue<void>.error(list.error!, list.stackTrace!)
        : (summary.isLoading || list.isLoading)
        ? const AsyncValue<void>.loading()
        : const AsyncValue<void>.data(null);
    final signupCode = ref.watch(signupReferralCodeProvider);

    return Scaffold(
      appBar: AppBar(
        actions: const [HomeButton()],
        title: const Text('Referanslarım'),
      ),
      body: AsyncValueView<void>(
        value: combined,
        onRetry: () => _refresh(ref),
        data: (_) {
          final s = summary.requireValue;
          final items = list.requireValue;
          return RefreshIndicator(
            onRefresh: () => _refresh(ref),
            child: ListView(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (shouldShowInvalidReferralWarning(
                  signupCode: signupCode,
                  wasReferred: s.wasReferred,
                ))
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Card(
                      child: ListTile(
                        leading: Icon(Icons.info_outline),
                        title: Text(invalidReferralWarningText),
                      ),
                    ),
                  ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text('Referans kodum', style: t.textTheme.labelLarge),
                        const SizedBox(height: 8),
                        SelectableText(
                          s.referralCode ?? '-',
                          style: t.textTheme.headlineMedium?.copyWith(
                            letterSpacing: 4,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: s.referralCode == null
                              ? null
                              : () async {
                                  final m = ScaffoldMessenger.of(context);
                                  await Clipboard.setData(
                                    ClipboardData(text: s.referralCode!),
                                  );
                                  m.showSnackBar(
                                    const SnackBar(content: Text('Kopyalandı')),
                                  );
                                },
                          icon: const Icon(Icons.copy),
                          label: const Text('Kopyala'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sayılan referans: ${s.activeCount}'),
                        const SizedBox(height: 4),
                        Text(
                          'Güncel indirim: %${s.discountPercent}',
                          style: t.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text('Bekleyen referans: ${s.pendingCount}'),
                        const SizedBox(height: 8),
                        Text(
                          'Her sayılan referans %5 indirim sağlar; en fazla %50. İndirim otomatik uygulanmaz, ödeme sırasında stüdyo tarafından uygulanır.',
                          style: t.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Referanslarım', style: t.textTheme.titleLarge),
                const SizedBox(height: 8),
                if (items.isEmpty)
                  const Text('Henüz referansınız yok.')
                else
                  for (final r in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        child: ListTile(
                          title: Text(r.displayName),
                          subtitle: r.status == ReferralStatus.approved
                              ? Text(
                                  r.countsNow
                                      ? 'Sayılıyor'
                                      : 'Sayılmıyor (aktif paketi yok)',
                                )
                              : null,
                          trailing: ReferralStatusChip(r.status),
                        ),
                      ),
                    ),
              ],
            ),
          );
        },
      ),
    );
  }
}
