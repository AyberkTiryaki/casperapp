import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/error_messages.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/warning_box.dart';
import '../data/measurement_repository.dart';
import '../domain/measurement_models.dart';
import 'measurement_form.dart';
import 'weight_trend_chart.dart';

/// Ölçüm ekle butonu (iki ekran ortak).
class AddMeasurementFab extends ConsumerWidget {
  const AddMeasurementFab({super.key, required this.memberId});
  final String memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Onay yoksa (veya henüz bilinmiyorsa) ekleme butonu gizlenir.
    final ok = ref.watch(healthConsentProvider(memberId)).value ?? false;
    if (!ok) return const SizedBox.shrink();
    return FloatingActionButton.extended(
      onPressed: () =>
          showAddMeasurementDialog(context, ref, memberId: memberId),
      icon: const Icon(Icons.add),
      label: const Text('Ölçüm ekle'),
    );
  }
}

/// Özet + kilo eğilimi + geçmiş; iki ekranın ortak gövdesi.
class MeasurementsBody extends ConsumerWidget {
  const MeasurementsBody({
    super.key,
    required this.memberId,
    required this.emptyTitle,
    this.emptyMessage,
    this.isSelf = false,
  });
  final bool isSelf;
  final String memberId;
  final String emptyTitle;
  final String? emptyMessage;

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(measurementsProvider(memberId));
    ref.invalidate(healthConsentProvider(memberId));
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    BodyMeasurement m,
  ) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bu ölçüm silinsin mi?'),
        content: const Text('Bu işlem geri alınamaz.'),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (go != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(measurementRepositoryProvider).delete(m.id);
      ref.invalidate(measurementsProvider(memberId));
      messenger.showSnackBar(const SnackBar(content: Text('Ölçüm silindi.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(measurementsProvider(memberId));
    final t = Theme.of(context);
    final consent = ref.watch(healthConsentProvider(memberId)).value;
    return AsyncValueView<List<BodyMeasurement>>(
      value: value,
      onRetry: () => _refresh(ref),
      data: (items) {
        final sorted = chronological(items).reversed.toList();
        return RefreshIndicator(
          onRefresh: () => _refresh(ref),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              if (consent == false) ...[
                WarningBox(
                  text: isSelf
                      ? 'Vücut ölçümü kaydı için sağlık verisi onayınız yok. Profil ekranından onay verebilirsiniz.'
                      : 'Bu üyenin sağlık verisi onayı yok; ölçüm kaydedilemez. Üye onayı Profil ekranından verebilir.',
                ),
                const SizedBox(height: 16),
              ],
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 48),
                  child: EmptyView(
                    title: emptyTitle,
                    message: emptyMessage,
                    icon: Icons.monitor_weight_outlined,
                  ),
                )
              else ...[
                Text(
                  'Son ölçüm: ${formatDate(sorted.first.measuredOn)}',
                  style: t.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                MeasurementProgressCard(measurements: items),
                const SizedBox(height: 24),
                Text('Kilo eğilimi', style: t.textTheme.titleMedium),
                const SizedBox(height: 8),
                WeightTrendChart(points: weightTrendPoints(items)),
                const SizedBox(height: 24),
                Text('Geçmiş', style: t.textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final m in sorted)
                  MeasurementTile(
                    measurement: m,
                    onDelete: () => _delete(context, ref, m),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Geçmiş listesindeki tek ölçüm.
class MeasurementTile extends StatelessWidget {
  const MeasurementTile({super.key, required this.measurement, this.onDelete});
  final BodyMeasurement measurement;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final parts = [
      for (final m in MeasurementMetric.values)
        if (m.valueOf(measurement) != null)
          '${m.label} ${formatMetric(m, m.valueOf(measurement)!)}',
    ];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatDate(measurement.measuredOn),
                    style: t.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(parts.join(' · '), style: t.textTheme.bodyMedium),
                  if (measurement.note != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      measurement.note!,
                      style: t.textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (onDelete != null)
              IconButton(
                tooltip: 'Sil',
                icon: const Icon(Icons.delete_outline),
                onPressed: onDelete,
              ),
          ],
        ),
      ),
    );
  }
}

/// Ölçü başına son değer ve değişim özeti. Değişimler iyi/kötü diye renklenmez.
class MeasurementProgressCard extends StatelessWidget {
  const MeasurementProgressCard({super.key, required this.measurements});
  final List<BodyMeasurement> measurements;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final rows = <Widget>[];
    for (final m in MeasurementMetric.values) {
      final p = metricProgress(m, measurements);
      if (p == null) continue;
      if (rows.isNotEmpty) rows.add(const Divider(height: 24));
      rows.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(m.label, style: t.textTheme.titleSmall)),
                Text(formatMetric(m, p.latest), style: t.textTheme.titleMedium),
              ],
            ),
            if (p.changeFromPrevious != null)
              _ChangeLine(
                text:
                    'Öncekine göre ${formatSignedChange(p.changeFromPrevious!, m.unit)}',
                change: p.changeFromPrevious!,
              ),
            if (p.changeFromFirst != null)
              _ChangeLine(
                text:
                    'İlk ölçüme göre ${formatSignedChange(p.changeFromFirst!, m.unit)}',
                change: p.changeFromFirst!,
              ),
          ],
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: rows),
      ),
    );
  }
}

class _ChangeLine extends StatelessWidget {
  const _ChangeLine({required this.text, required this.change});
  final String text;
  final double change;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final r = (change * 10).round();
    final icon = r > 0
        ? Icons.arrow_upward
        : r < 0
        ? Icons.arrow_downward
        : Icons.remove;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: t.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: t.textTheme.bodyMedium?.copyWith(
                color: t.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
