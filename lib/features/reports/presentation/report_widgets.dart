import 'package:flutter/material.dart';

/// Rapor bölüm başlığı.
class ReportSectionHeader extends StatelessWidget {
  const ReportSectionHeader(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 20, 0, 8),
    child: Text(title, style: Theme.of(context).textTheme.titleMedium),
  );
}

/// Sayı kartı; yarım genişlikte iki sütun oluşturmak için [width] verilir.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.sub,
    this.width,
  });

  final String label;
  final String value;
  final String? sub;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return SizedBox(
      width: width,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: t.textTheme.labelMedium),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value, style: t.textTheme.headlineSmall),
              ),
              if (sub != null) ...[
                const SizedBox(height: 4),
                Text(sub!, style: t.textTheme.bodySmall),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// İki sütunlu duyarlı kart ızgarası.
class StatGrid extends StatelessWidget {
  const StatGrid({super.key, required this.cards});

  /// Genişlik ızgara tarafından atanır.
  final List<StatCard> cards;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      const gap = 8.0;
      final w = (c.maxWidth - gap) / 2;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final s in cards)
            StatCard(label: s.label, value: s.value, sub: s.sub, width: w),
        ],
      );
    },
  );
}
