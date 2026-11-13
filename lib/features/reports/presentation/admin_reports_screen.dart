import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/async_value_view.dart';
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
    return Scaffold(
      appBar: AppBar(title: const Text('Raporlar')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${formatDate(_range.from)} – ${formatDate(_range.to)}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _pickRange,
                      icon: const Icon(Icons.date_range),
                      label: const Text('Tarih seç'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final q in _Quick.values)
                      ChoiceChip(
                        label: Text(_quickLabels[q]!),
                        selected: _quick == q,
                        onSelected: (_) => _pickQuick(q),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: AsyncValueView<AdminReport>(
              value: report,
              onRetry: () => ref.invalidate(adminReportProvider(_range)),
              data: (r) => RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(adminReportProvider(_range));
                  await ref.read(adminReportProvider(_range).future);
                },
                child: _ReportBody(report: r),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.report});

  final AdminReport report;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final ps = report.packageSales;
    final pr = report.productSales;
    final c = report.classes;
    final a = report.attendance;
    final rate = a.attendanceRate;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        const ReportSectionHeader('Gelir'),
        StatGrid(
          cards: [
            StatCard(
              label: 'Paket satışı',
              value: formatTl(ps.total),
              sub:
                  '${ps.count} paket · ${formatTl(ps.discountTotal)} indirim (${ps.discountedCount} pakette)',
            ),
            StatCard(
              label: 'Ürün satışı',
              value: formatTl(pr.total),
              sub: [
                '${pr.count} satış · ${pr.quantity} adet',
                if (pr.reversedCount > 0)
                  '${pr.reversedCount} iptal edilen satış hariç',
              ].join('\n'),
            ),
            StatCard(
              label: 'Cüzdan yüklemesi',
              value: formatTl(report.walletTopups.total),
              sub: '${report.walletTopups.count} yükleme',
            ),
          ],
        ),
        const ReportSectionHeader('Üyeler'),
        StatGrid(
          cards: [
            StatCard(label: 'Yeni üye', value: '${report.members.newCount}'),
            StatCard(
              label: 'Aktif paketli üye',
              value: '${report.members.activeWithPackage}',
              sub: 'şu an',
            ),
          ],
        ),
        const ReportSectionHeader('Dersler'),
        StatGrid(
          cards: [
            StatCard(label: 'Yapılan ders', value: '${c.held}'),
            StatCard(label: 'İptal edilen ders', value: '${c.cancelled}'),
            StatCard(label: 'Planlanan ders', value: '${c.upcoming}'),
            StatCard(
              label: 'Ortalama doluluk',
              value: formatPercent(c.occupancyPct),
              sub: '${c.booked} / ${c.capacity} kontenjan',
            ),
            StatCard(
              label: 'Katılım',
              value: rate == null ? '—' : formatPercent(rate),
              sub: '${a.attended} katıldı · ${a.noShow} gelmedi',
            ),
          ],
        ),
        const ReportSectionHeader('Eğitmenler'),
        if (report.trainers.isEmpty)
          Text('Bu aralıkta yapılan ders yok.', style: t.textTheme.bodyMedium)
        else
          for (final tr in report.trainers)
            Card(
              child: ListTile(
                title: Text(tr.fullName),
                subtitle: Text(
                  '${tr.classCount} ders · ${tr.booked} / ${tr.capacity} kontenjan\n'
                  '${tr.attended} katıldı · ${tr.noShow} gelmedi',
                ),
                isThreeLine: true,
              ),
            ),
        const ReportSectionHeader('En çok satan ürünler'),
        if (report.topProducts.isEmpty)
          Text('Bu aralıkta ürün satışı yok.', style: t.textTheme.bodyMedium)
        else
          for (var i = 0; i < report.topProducts.length; i++)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 14,
                child: Text('${i + 1}', style: t.textTheme.labelMedium),
              ),
              title: Text(report.topProducts[i].name),
              subtitle: Text('${report.topProducts[i].quantity} adet'),
              trailing: Text(formatTl(report.topProducts[i].total)),
            ),
      ],
    );
  }
}
