import 'package:caspertrainingstudio/features/measurements/domain/measurement_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_measurement_repo.dart';

void main() {
  group('fromJson', () {
    test('sayı, metin ve null değerleri okur', () {
      final m = BodyMeasurement.fromJson({
        'id': 'a',
        'member_id': 'm1',
        'measured_on': '2026-11-05',
        'weight_kg': '72.5',
        'body_fat_pct': 18,
        'muscle_kg': null,
        'waist_cm': 80.0,
        'note': '  ',
        'created_by': null,
        'created_at': '2026-11-05T08:00:00+00:00',
      });
      expect(m.weightKg, 72.5);
      expect(m.bodyFatPct, 18.0);
      expect(m.muscleKg, isNull);
      expect(m.waistCm, 80.0);
      expect(m.note, isNull);
      expect(m.measuredOn, DateTime(2026, 11, 5));
    });
  });

  group('metricProgress', () {
    test('tek değer: önceki ve ilk null', () {
      final p = metricProgress(MeasurementMetric.weight, [
        sampleMeasurement('a', '2026-11-01', weight: 70),
      ])!;
      expect(p.latest, 70);
      expect(p.previous, isNull);
      expect(p.first, isNull);
      expect(p.changeFromPrevious, isNull);
      expect(p.changeFromFirst, isNull);
    });

    test('değişimler ve null satırlar atlanır', () {
      final p = metricProgress(MeasurementMetric.weight, [
        sampleMeasurement('c', '2026-11-10', weight: 73.5),
        sampleMeasurement('b', '2026-10-20', waist: 80),
        sampleMeasurement('a', '2026-10-01', weight: 75),
        sampleMeasurement('d', '2026-10-25', weight: 73),
      ])!;
      expect(p.latest, 73.5);
      expect(p.previous, 73);
      expect(p.first, 75);
      expect(p.changeFromPrevious, closeTo(0.5, 1e-9));
      expect(p.changeFromFirst, closeTo(-1.5, 1e-9));
      expect(p.latestDate, DateTime(2026, 11, 10));
    });

    test('aynı gün: kayıt zamanına göre sıralanır', () {
      final p = metricProgress(MeasurementMetric.weight, [
        sampleMeasurement(
          'late',
          '2026-11-01',
          weight: 71,
          createdAt: DateTime.utc(2026, 11, 1, 18),
        ),
        sampleMeasurement(
          'early',
          '2026-11-01',
          weight: 72,
          createdAt: DateTime.utc(2026, 11, 1, 8),
        ),
      ])!;
      expect(p.latest, 71);
      expect(p.previous, 72);
    });

    test('veri yoksa null', () {
      expect(
        metricProgress(MeasurementMetric.arm, [
          sampleMeasurement('a', '2026-11-01', weight: 70),
        ]),
        isNull,
      );
    });
  });

  test('weightTrendPoints kronolojik ve null kiloları atlar', () {
    final pts = weightTrendPoints([
      sampleMeasurement('b', '2026-11-05', weight: 71),
      sampleMeasurement('c', '2026-11-03', waist: 80),
      sampleMeasurement('a', '2026-11-01', weight: 72),
    ]);
    expect(pts, [
      TrendPoint(DateTime(2026, 11, 1), 72),
      TrendPoint(DateTime(2026, 11, 5), 71),
    ]);
  });

  test('formatNumber ve formatSignedChange', () {
    expect(formatNumber(72.5), '72,5');
    expect(formatNumber(72.0), '72');
    expect(formatNumber(72.04), '72');
    expect(formatSignedChange(1.2, 'kg'), '+1,2 kg');
    expect(formatSignedChange(-0.5, 'kg'), '-0,5 kg');
    expect(formatSignedChange(0, 'kg'), '0 kg');
    expect(formatSignedChange(0.01, 'cm'), '0 cm');
    expect(formatSignedChange(-2.0000000001, 'cm'), '-2 cm');
  });

  group('validateMetricInput', () {
    const w = MeasurementMetric.weight;
    test('boş geçerli', () {
      expect(validateMetricInput(w, null), isNull);
      expect(validateMetricInput(w, '  '), isNull);
    });
    test('sınırlar', () {
      expect(validateMetricInput(w, '20'), isNull);
      expect(validateMetricInput(w, '400'), isNull);
      expect(validateMetricInput(w, '19,9'), isNotNull);
      expect(validateMetricInput(w, '400.1'), isNotNull);
      expect(validateMetricInput(MeasurementMetric.bodyFat, '1'), isNull);
      expect(validateMetricInput(MeasurementMetric.bodyFat, '75'), isNull);
      expect(validateMetricInput(MeasurementMetric.bodyFat, '0,9'), isNotNull);
      expect(validateMetricInput(MeasurementMetric.arm, '100'), isNull);
      expect(validateMetricInput(MeasurementMetric.arm, '101'), isNotNull);
    });
    test('virgül ve nokta, tek ondalık', () {
      expect(validateMetricInput(w, '72,5'), isNull);
      expect(validateMetricInput(w, '72.5'), isNull);
      expect(validateMetricInput(w, '72,55'), isNotNull);
    });
    test('geçersiz metin', () {
      expect(validateMetricInput(w, 'abc'), isNotNull);
      expect(validateMetricInput(w, '-70'), isNotNull);
      expect(validateMetricInput(w, 'NaN'), isNotNull);
    });
  });
}
