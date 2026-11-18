import 'package:caspertrainingstudio/features/reports/domain/report_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_report_repo.dart';

void main() {
  test('fromJson: tam örnek', () {
    final r = AdminReport.fromJson(sampleReportJson);
    expect(r.packageSales.count, 5);
    expect(r.packageSales.total, 12300);
    expect(r.packageSales.discountTotal, 600);
    expect(r.packageSales.discountedCount, 2);
    expect(r.productSales.quantity, 7);
    expect(r.productSales.reversedCount, 1);
    expect(r.walletTopups.total, 750);
    expect(r.members.newCount, 6);
    expect(r.members.activeWithPackage, 5);
    expect(r.classes.held, 12);
    expect(r.classes.occupancyPct, 35);
    expect(r.attendance.noShow, 2);
    expect(r.trainers.single.fullName, 'Ayşe Eğitmen');
    expect(r.trainers.single.classCount, 8);
    expect(r.topProducts.single.name, 'Su');
    expect(r.topProducts.single.total, 80);
  });

  test('fromJson: sayılar String gelebilir', () {
    final r = AdminReport.fromJson({
      'package_sales': {
        'count': '5',
        'total': '12300.50',
        'discount_total': '600',
      },
      'classes': {'held': '12', 'occupancy_pct': '35.5'},
      'trainers': [
        {'trainer_id': 'x', 'full_name': 'A', 'class_count': '3'},
      ],
    });
    expect(r.packageSales.count, 5);
    expect(r.packageSales.total, 12300.5);
    expect(r.classes.held, 12);
    expect(r.classes.occupancyPct, 35.5);
    expect(r.trainers.single.classCount, 3);
  });

  test('fromJson: boş nesne varsayılanlara düşer', () {
    final r = AdminReport.fromJson({});
    expect(r.packageSales.total, 0);
    expect(r.productSales.count, 0);
    expect(r.members.newCount, 0);
    expect(r.classes.capacity, 0);
    expect(r.attendance.attendanceRate, isNull);
    expect(r.trainers, isEmpty);
    expect(r.topProducts, isEmpty);
  });

  test('tarih aralıkları', () {
    final nov = currentMonthRange(DateTime(2026, 11, 13));
    expect(nov.from, DateTime(2026, 11, 1));
    expect(nov.to, DateTime(2026, 11, 30));

    final dec = currentMonthRange(DateTime(2026, 12, 31));
    expect(dec.to, DateTime(2026, 12, 31));
    expect(
      previousMonthRange(DateTime(2026, 12, 5)).from,
      DateTime(2026, 11, 1),
    );
    expect(
      previousMonthRange(DateTime(2026, 12, 5)).to,
      DateTime(2026, 11, 30),
    );

    final jan = previousMonthRange(DateTime(2026, 1, 10));
    expect(jan.from, DateTime(2025, 12, 1));
    expect(jan.to, DateTime(2025, 12, 31));

    expect(currentMonthRange(DateTime(2028, 2, 10)).to, DateTime(2028, 2, 29));
    expect(currentMonthRange(DateTime(2027, 2, 10)).to, DateTime(2027, 2, 28));
    expect(previousMonthRange(DateTime(2028, 3, 1)).to, DateTime(2028, 2, 29));

    final l7 = lastNDaysRange(DateTime(2026, 11, 3, 15), 7);
    expect(l7.from, DateTime(2026, 10, 28));
    expect(l7.to, DateTime(2026, 11, 3));
  });

  test('DateRange eşitliği', () {
    expect(
      DateRange(DateTime(2026, 1, 1), DateTime(2026, 1, 31)),
      DateRange(DateTime(2026, 1, 1), DateTime(2026, 1, 31)),
    );
    expect(
      DateRange(DateTime(2026, 1, 1), DateTime(2026, 1, 31)).hashCode,
      DateRange(DateTime(2026, 1, 1), DateTime(2026, 1, 31)).hashCode,
    );
  });

  test('yüzde biçimi ve katılım oranı', () {
    expect(formatPercent(35), '35 %');
    expect(formatPercent(35.0), '35 %');
    expect(formatPercent(35.5), '35,5 %');
    expect(formatPercent(0), '0 %');
    expect(formatPercent(33.333), '33,3 %');
    expect(attendanceRateOf(19, 1), 95);
    expect(attendanceRateOf(0, 0), isNull);
    expect(const AttendanceStats(attended: 1, noShow: 1).attendanceRate, 50);
  });

  group('comparisonRange', () {
    final now = DateTime(2026, 11, 18, 15);

    test('devam eden ay, önceki ayın aynı gün sayısıyla kıyaslanır', () {
      final r = comparisonRange(currentMonthRange(now), now)!;
      expect(r.from, DateTime(2026, 10, 1));
      expect(r.to, DateTime(2026, 10, 18));
    });

    test('biten ay, önceki ayın tamamıyla kıyaslanır', () {
      final r = comparisonRange(previousMonthRange(now), now)!;
      expect(r.from, DateTime(2026, 9, 1));
      expect(r.to, DateTime(2026, 9, 30));
    });

    test('31 günlük ay, 30 günlük ayın sonunu aşmaz', () {
      final r = comparisonRange(
        DateRange(DateTime(2026, 10, 1), DateTime(2026, 10, 31)),
        now,
      )!;
      expect(r.to, DateTime(2026, 9, 30));
    });

    test('son 7 gün, hemen önceki 7 günle kıyaslanır', () {
      final r = comparisonRange(lastNDaysRange(now, 7), now)!;
      expect(r.from, DateTime(2026, 11, 5));
      expect(r.to, DateTime(2026, 11, 11));
    });

    test('gelecekteki aralık için karşılaştırma yok', () {
      expect(
        comparisonRange(
          DateRange(DateTime(2026, 12, 1), DateTime(2026, 12, 31)),
          now,
        ),
        isNull,
      );
    });

    test('percentChange: önceki 0 ise null', () {
      expect(percentChange(5, 0), isNull);
      expect(percentChange(150, 100), 50);
      expect(percentChange(50, 100), -50);
    });
  });
}
