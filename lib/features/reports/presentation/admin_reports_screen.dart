import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/home_button.dart';
import '../data/report_repository.dart';
import '../domain/report_models.dart';
import 'report_widgets.dart';

enum _Quick { thisMonth, lastMonth, last7, last30 }

const _quickLabels = {
  _Quick.thisMonth: 'Bu ay',
  _Quick.lastMonth: 'Geçen ay',
  _Quick.last7: 'Son 7 gün',
  _Quick.last30: 'Son 30 gün',
};

String _rangeText(DateRange r) => r.from == r.to
    ? formatDate(r.from)
    : '${formatDate(r.from)} – ${formatDate(r.to)}';

class AdminReportsScreen extends ConsumerStatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  ConsumerState<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends ConsumerState<AdminReportsScreen> {
  late DateRange _range = currentMonthRange(DateTime.now());
  _Quick? _quick = _Quick.thisMonth;

  DateRange _rangeFor(_Quick q) {
    final now = DateTime.now();
    return switch (q) {
      _Quick.thisMonth => currentMonthRange(now),
      _Quick.lastMonth => previousMonthRange(now),
      _Quick.last7 => lastNDaysRange(now, 7),
      _Quick.last30 => lastNDaysRange(now, 30),
    };
  }

  void _pickQuick(_Quick q) => setState(() {
    _quick = q;
    _range = _rangeFor(q);
  });

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime(now.year, now.month + 2, 0),
      initialDateRange: DateTimeRange(start: _range.from, end: _range.to),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _quick = null;
      _range = DateRange(
        DateTime(picked.start.year, picked.start.month, picked.start.day),
        DateTime(picked.end.year, picked.end.month, picked.end.day),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final report = ref.watch(adminReportProvider(_range));
    final prevRange = comparisonRange(_range, DateTime.now());
    // Karşılaştırma isteğe bağlı: yüklenemezse değişim rozetleri gizlenir.
    final prev = prevRange == null
        ? null
        : ref.watch(adminReportProvider(prevRange)).value;
    return Scaffold(
      appBar: AppBar(
        actions: const [HomeButton()],
        title: const Text('Raporlar'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: _PeriodHeader(
                  range: _range,
                  comparison: prevRange,
                  quick: _quick,
                  onQuick: _pickQuick,
                  onPickRange: _pickRange,
                ),
              ),
            ),
          ),
          Expanded(
            child: AsyncValueView<AdminReport>(
              value: report,
              onRetry: () => ref.invalidate(adminReportProvider(_range)),
              data: (r) => RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(adminReportProvider);
                  await ref.read(adminReportProvider(_range).future);
                },
                child: _ReportBody(report: r, previous: prev),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodHeader extends StatelessWidget {
  const _PeriodHeader({
    required this.range,
    required this.comparison,
    required this.quick,
    required this.onQuick,
    required this.onPickRange,
  });

  final DateRange range;
  final DateRange? comparison;
  final _Quick? quick;
  final ValueChanged<_Quick> onQuick;
  final VoidCallback onPickRange;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'RAPOR DÖNEMİ',
          style: t.textTheme.labelSmall?.copyWith(
            color: p.muted,
            letterSpacing: 1.1,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _rangeText(range),
          style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (comparison != null)
          Text(
            'Karşılaştırma: ${_rangeText(comparison!)}',
            style: t.textTheme.bodySmall?.copyWith(color: p.muted),
          ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final q in _Quick.values)
              ChoiceChip(
                label: Text(_quickLabels[q]!),
                selected: quick == q,
                onSelected: (_) => onQuick(q),
              ),
            ChoiceChip(
              avatar: const Icon(Icons.date_range, size: 18),
              label: const Text('Özel aralık'),
              selected: quick == null,
              onSelected: (_) => onPickRange(),
            ),
          ],
        ),
      ],
    );
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.report, required this.previous});

  final AdminReport report;
  final AdminReport? previous;

  @override
  Widget build(BuildContext context) {
    final pv = previous;
    final hasPrev = pv != null;
    double? d(num Function(AdminReport) f) =>
        pv == null ? null : percentChange(f(report), f(pv));

    final ps = report.packageSales;
    final pr = report.productSales;

    final kpis = KpiGrid(
      children: [
        KpiTile(
          icon: Icons.inventory_2_outlined,
          label: 'Paket satışı',
          value: formatTl(ps.total),
          sub:
              '${ps.count} paket · ${formatTl(ps.discountTotal)} indirim (${ps.discountedCount} pakette)',
          showDelta: hasPrev,
          delta: d((r) => r.packageSales.total),
        ),
        KpiTile(
          icon: Icons.shopping_bag_outlined,
          label: 'Ürün satışı',
          value: formatTl(pr.total),
          sub: [
            '${pr.count} satış · ${pr.quantity} adet',
            if (pr.reversedCount > 0)
              '${pr.reversedCount} iptal edilen satış hariç',
          ].join('\n'),
          showDelta: hasPrev,
          delta: d((r) => r.productSales.total),
        ),
        KpiTile(
          icon: Icons.account_balance_wallet_outlined,
          label: 'Cüzdan yüklemesi',
          value: formatTl(report.walletTopups.total),
          sub: '${report.walletTopups.count} yükleme',
          showDelta: hasPrev,
          delta: d((r) => r.walletTopups.total),
        ),
        KpiTile(
          icon: Icons.person_add_alt_1_outlined,
          label: 'Yeni üye',
          value: '${report.members.newCount}',
          showDelta: hasPrev,
          delta: d((r) => r.members.newCount),
        ),
        KpiTile(
          icon: Icons.verified_user_outlined,
          label: 'Aktif paketli üye',
          value: '${report.members.activeWithPackage}',
          sub: 'şu an',
        ),
        KpiTile(
          icon: Icons.event_available_outlined,
          label: 'Yapılan ders',
          value: '${report.classes.held}',
          showDelta: hasPrev,
          delta: d((r) => r.classes.held),
        ),
      ],
    );

    final classes = _ClassesPanel(report: report);
    final trainers = _TrainersPanel(trainers: report.trainers);
    final products = _ProductsPanel(products: report.topProducts);

    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 900;
        const gap = SizedBox(height: 14);
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: wide ? 24 : 16,
            vertical: 12,
          ),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SalesHero(report: report, previous: pv),
                    gap,
                    kpis,
                    gap,
                    if (wide)
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: classes),
                            const SizedBox(width: 14),
                            Expanded(child: trainers),
                          ],
                        ),
                      )
                    else ...[
                      classes,
                      gap,
                      trainers,
                    ],
                    gap,
                    products,
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Dönemin öne çıkan tek sayısı: toplam satış ve paket/ürün dağılımı.
class _SalesHero extends StatelessWidget {
  const _SalesHero({required this.report, required this.previous});

  final AdminReport report;
  final AdminReport? previous;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final p = context.palette;
    final pv = previous;
    return ReportPanel(
      title: 'Gelir',
      icon: Icons.insights_outlined,
      subtitle: 'Paket ve ürün satışları toplamı (cüzdan yüklemeleri hariç)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Toplam satış',
            style: t.textTheme.labelMedium?.copyWith(color: p.muted),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatTl(report.salesTotal),
              style: t.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
          ),
          if (pv != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                DeltaBadge(
                  change: percentChange(report.salesTotal, pv.salesTotal),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'önceki döneme göre (${formatTl(pv.salesTotal)})',
                    overflow: TextOverflow.ellipsis,
                    style: t.textTheme.labelSmall?.copyWith(color: p.muted),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          SplitBar(
            parts: [
              (
                'Paket',
                report.packageSales.total,
                formatTl(report.packageSales.total),
              ),
              (
                'Ürün',
                report.productSales.total,
                formatTl(report.productSales.total),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClassesPanel extends StatelessWidget {
  const _ClassesPanel({required this.report});

  final AdminReport report;

  @override
  Widget build(BuildContext context) {
    final c = report.classes;
    final a = report.attendance;
    final rate = a.attendanceRate;
    return ReportPanel(
      title: 'Dersler',
      icon: Icons.fitness_center_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _Figure(label: 'Yapılan', value: '${c.held}'),
              ),
              Expanded(
                child: _Figure(label: 'Planlanan', value: '${c.upcoming}'),
              ),
              Expanded(
                child: _Figure(
                  label: 'İptal edilen',
                  value: '${c.cancelled}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          MeterRow(
            label: 'Ortalama doluluk',
            valueText: formatPercent(c.occupancyPct),
            fraction: c.occupancyPct / 100,
            caption: '${c.booked} / ${c.capacity} kontenjan',
          ),
          const SizedBox(height: 16),
          MeterRow(
            label: 'Katılım',
            valueText: rate == null ? '—' : formatPercent(rate),
            fraction: (rate ?? 0) / 100,
            caption: '${a.attended} katıldı · ${a.noShow} gelmedi',
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: t.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: t.textTheme.bodySmall?.copyWith(color: context.palette.muted),
        ),
      ],
    );
  }
}

class _TrainersPanel extends StatelessWidget {
  const _TrainersPanel({required this.trainers});

  final List<TrainerStats> trainers;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final p = context.palette;
    final sorted = [...trainers]
      ..sort((a, b) => b.classCount.compareTo(a.classCount));
    return ReportPanel(
      title: 'Eğitmenler',
      icon: Icons.sports_outlined,
      subtitle: sorted.isEmpty ? null : 'Çubuk: ortalama doluluk',
      child: sorted.isEmpty
          ? const ReportEmptyLine('Bu aralıkta yapılan ders yok.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < sorted.length; i++) ...[
                  if (i > 0) Divider(height: 24, color: p.outline),
                  Builder(
                    builder: (context) {
                      final tr = sorted[i];
                      final occ = tr.capacity == 0
                          ? 0.0
                          : tr.booked * 100 / tr.capacity;
                      final att = attendanceRateOf(tr.attended, tr.noShow);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  tr.fullName,
                                  style: t.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Text(
                                formatPercent(occ),
                                style: t.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ReportBar(fraction: occ / 100, height: 6),
                          const SizedBox(height: 6),
                          Text(
                            '${tr.classCount} ders · ${tr.booked} / ${tr.capacity} kontenjan\n'
                            'Katılım ${att == null ? '—' : formatPercent(att)} · '
                            '${tr.attended} katıldı · ${tr.noShow} gelmedi',
                            style: t.textTheme.bodySmall?.copyWith(
                              color: p.muted,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ],
            ),
    );
  }
}

class _ProductsPanel extends StatelessWidget {
  _ProductsPanel({required List<TopProduct> products})
    // Sıra ve çubuk aynı ölçüyü (tutar) göstersin.
    : products = [...products]..sort((a, b) => b.total.compareTo(a.total));

  final List<TopProduct> products;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final p = context.palette;
    final maxTotal = products.fold<double>(
      0,
      (m, e) => e.total > m ? e.total : m,
    );
    return ReportPanel(
      title: 'En çok satan ürünler',
      icon: Icons.local_mall_outlined,
      subtitle: products.isEmpty ? null : 'Çubuk: satış tutarı',
      child: products.isEmpty
          ? const ReportEmptyLine('Bu aralıkta ürün satışı yok.')
          : Column(
              children: [
                for (var i = 0; i < products.length; i++) ...[
                  if (i > 0) const SizedBox(height: 14),
                  Row(
                    children: [
                      SizedBox(
                        width: 28,
                        child: Text(
                          '${i + 1}.',
                          style: t.textTheme.titleSmall?.copyWith(
                            color: p.muted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    products[i].name,
                                    overflow: TextOverflow.ellipsis,
                                    style: t.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${products[i].quantity} adet',
                                  style: t.textTheme.bodySmall?.copyWith(
                                    color: p.muted,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  formatTl(products[i].total),
                                  style: t.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ReportBar(
                              fraction: maxTotal == 0
                                  ? 0
                                  : products[i].total / maxTotal,
                              height: 6,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
    );
  }
}
