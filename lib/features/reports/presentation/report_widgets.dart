import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/report_models.dart';

/// Rapor grafiklerinin renkleri. Tek tonun (marka mavisi) iki adımı:
/// açıklık farkı renk körlüğünde de korunur (OKLab ΔE açıkta 31, koyuda 21).
/// Açık adım zemine karşı düşük kontrastlı olduğundan değerler her zaman yazıyla da verilir.
class ReportColors {
  const ReportColors._(this.primary, this.secondary, this.track);

  /// Ana seri (paket, doluluk, katılım).
  final Color primary;

  /// İkinci seri (ürün).
  final Color secondary;

  /// Çubuk izi: aynı tonun çok açık adımı.
  final Color track;

  static ReportColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const ReportColors._(
          AppColors.skyBlue,
          AppColors.electricBlue,
          Color(0xFF243163),
        )
      : const ReportColors._(
          AppColors.brandBlue,
          AppColors.skyBlue,
          Color(0xFFE3EAFB),
        );
}

/// Başlıklı rapor kartı.
class ReportPanel extends StatelessWidget {
  const ReportPanel({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.subtitle,
  });

  final String title;
  final IconData icon;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final p = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.outline),
        boxShadow: p.cardShadow,
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: p.link),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: t.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Text(
                subtitle!,
                style: t.textTheme.bodySmall?.copyWith(color: p.muted),
              ),
            ),
          ],
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// Önceki döneme göre değişim rozeti: ok + işaretli yüzde (renk tek başına anlam taşımaz).
class DeltaBadge extends StatelessWidget {
  const DeltaBadge({super.key, required this.change, this.upIsGood = true});

  /// Yüzde değişim; null ise önceki dönemde veri yok.
  final double? change;
  final bool upIsGood;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final p = context.palette;
    final c = change;
    if (c == null) {
      return Text(
        'önceki dönem: veri yok',
        style: t.textTheme.labelSmall?.copyWith(color: p.muted),
      );
    }
    final rounded = c.abs() < 0.5 ? 0.0 : c;
    final IconData icon;
    final Color color;
    if (rounded == 0) {
      icon = Icons.trending_flat;
      color = p.muted;
    } else {
      final up = rounded > 0;
      icon = up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;
      color = up == upIsGood ? AppColors.success : AppColors.danger;
    }
    final text = rounded == 0
        ? 'değişim yok'
        : '${rounded > 0 ? '+' : '−'}${formatPercent(rounded.abs())}';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 2),
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: t.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// Gösterge kutusu: etiket, değer, açıklama ve isteğe bağlı değişim rozeti.
class KpiTile extends StatelessWidget {
  const KpiTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.sub,
    this.delta,
    this.showDelta = false,
    this.upIsGood = true,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? sub;
  final double? delta;
  final bool showDelta;
  final bool upIsGood;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final p = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.outline),
        boxShadow: p.cardShadow,
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: p.raised,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: p.link),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: t.textTheme.labelMedium?.copyWith(color: p.muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: t.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (showDelta) ...[
            const SizedBox(height: 4),
            DeltaBadge(change: delta, upIsGood: upIsGood),
          ],
          if (sub != null) ...[
            const SizedBox(height: 6),
            Text(
              sub!,
              style: t.textTheme.bodySmall?.copyWith(color: p.muted),
            ),
          ],
        ],
      ),
    );
  }
}

/// Duyarlı ızgara: dar ekranda 2, genişte 3–4 sütun; satırdaki kutular eşit yükseklikte.
class KpiGrid extends StatelessWidget {
  const KpiGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      const gap = 10.0;
      final cols = c.maxWidth >= 1100 && children.length % 6 == 0
          ? 6
          : c.maxWidth >= 680
          ? 3
          : 2;
      final rows = <Widget>[];
      for (var i = 0; i < children.length; i += cols) {
        final slice = children.sublist(
          i,
          (i + cols).clamp(0, children.length),
        );
        rows.add(
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var j = 0; j < cols; j++) ...[
                  if (j > 0) const SizedBox(width: gap),
                  Expanded(
                    child: j < slice.length ? slice[j] : const SizedBox(),
                  ),
                ],
              ],
            ),
          ),
        );
      }
      return Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: gap),
            rows[i],
          ],
        ],
      );
    },
  );
}

/// Yatay çubuk (oran / büyüklük). Uç yuvarlak, iz aynı tonun açık adımı.
class ReportBar extends StatelessWidget {
  const ReportBar({super.key, required this.fraction, this.height = 8});

  /// 0..1
  final double fraction;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = ReportColors.of(context);
    final f = fraction.isNaN ? 0.0 : fraction.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: colors.track),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: f,
              child: ColoredBox(color: colors.primary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Oran satırı: ad, yanında değer; altında çubuk ve açıklama.
class MeterRow extends StatelessWidget {
  const MeterRow({
    super.key,
    required this.label,
    required this.valueText,
    required this.fraction,
    this.caption,
  });

  final String label;
  final String valueText;
  final double fraction;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: t.textTheme.bodyMedium)),
            Text(
              valueText,
              style: t.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ReportBar(fraction: fraction),
        if (caption != null) ...[
          const SizedBox(height: 4),
          Text(
            caption!,
            style: t.textTheme.bodySmall?.copyWith(color: p.muted),
          ),
        ],
      ],
    );
  }
}

/// Bir bütünün iki parçası: ince bölünmüş çubuk + adları ve tutarlarıyla açıklama.
class SplitBar extends StatelessWidget {
  const SplitBar({super.key, required this.parts});

  /// (ad, değer, değer yazısı); en fazla 2 parça (ana ve ikinci renk).
  final List<(String, double, String)> parts;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final p = context.palette;
    final colors = ReportColors.of(context);
    final palette = [colors.primary, colors.secondary];
    final total = parts.fold<double>(0, (s, e) => s + e.$2);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: SizedBox(
            height: 10,
            child: total <= 0
                ? ColoredBox(color: colors.track)
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < parts.length; i++)
                        if (parts[i].$2 > 0) ...[
                          // Parçalar arasında 2 px zemin boşluğu
                          if (i > 0 && parts[i - 1].$2 > 0)
                            const SizedBox(width: 2),
                          Expanded(
                            flex: (parts[i].$2 * 1000 / total).round().clamp(
                              1,
                              1000,
                            ),
                            child: ColoredBox(color: palette[i]),
                          ),
                        ],
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 16,
          runSpacing: 6,
          children: [
            for (var i = 0; i < parts.length; i++)
              // Satır yerine metin: dar ekranda taşmak yerine alta kayar.
              Text.rich(
                TextSpan(
                  children: [
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: palette[i],
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    TextSpan(
                      text: '${parts[i].$1}  ',
                      style: TextStyle(color: p.muted),
                    ),
                    TextSpan(
                      text: total > 0
                          ? '${parts[i].$3} · ${formatPercent(parts[i].$2 * 100 / total)}'
                          : parts[i].$3,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                style: t.textTheme.bodySmall,
              ),
          ],
        ),
      ],
    );
  }
}

/// Bölüm içi boş durum satırı.
class ReportEmptyLine extends StatelessWidget {
  const ReportEmptyLine(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: context.palette.muted),
    ),
  );
}
