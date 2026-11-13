import '../../../core/utils/formatters.dart';

/// Sayı ya da metin olarak gelen sayısal değeri tolere eder; boş/geçersizse null.
double? parseNumeric(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString().trim().replaceAll(',', '.'));
}

enum MeasurementMetric {
  weight('Kilo', 'kg', 20, 400),
  bodyFat('Yağ oranı', '%', 1, 75),
  muscle('Kas kütlesi', 'kg', 5, 150),
  waist('Bel', 'cm', 30, 250),
  hip('Kalça', 'cm', 30, 250),
  chest('Göğüs', 'cm', 30, 250),
  arm('Kol', 'cm', 10, 100),
  thigh('Bacak', 'cm', 20, 150);

  const MeasurementMetric(this.label, this.unit, this.min, this.max);
  final String label;
  final String unit;
  final double min;
  final double max;

  double? valueOf(BodyMeasurement m) => switch (this) {
    MeasurementMetric.weight => m.weightKg,
    MeasurementMetric.bodyFat => m.bodyFatPct,
    MeasurementMetric.muscle => m.muscleKg,
    MeasurementMetric.waist => m.waistCm,
    MeasurementMetric.hip => m.hipCm,
    MeasurementMetric.chest => m.chestCm,
    MeasurementMetric.arm => m.armCm,
    MeasurementMetric.thigh => m.thighCm,
  };

  /// RPC parametre adı.
  String get rpcParam => switch (this) {
    MeasurementMetric.weight => 'p_weight_kg',
    MeasurementMetric.bodyFat => 'p_body_fat_pct',
    MeasurementMetric.muscle => 'p_muscle_kg',
    MeasurementMetric.waist => 'p_waist_cm',
    MeasurementMetric.hip => 'p_hip_cm',
    MeasurementMetric.chest => 'p_chest_cm',
    MeasurementMetric.arm => 'p_arm_cm',
    MeasurementMetric.thigh => 'p_thigh_cm',
  };
}

class BodyMeasurement {
  const BodyMeasurement({
    required this.id,
    required this.memberId,
    required this.measuredOn,
    required this.createdAt,
    this.weightKg,
    this.bodyFatPct,
    this.muscleKg,
    this.waistCm,
    this.hipCm,
    this.chestCm,
    this.armCm,
    this.thighCm,
    this.note,
    this.createdBy,
  });

  final String id;
  final String memberId;

  /// Yerel gün (saat 00:00).
  final DateTime measuredOn;
  final DateTime createdAt;
  final double? weightKg,
      bodyFatPct,
      muscleKg,
      waistCm,
      hipCm,
      chestCm,
      armCm,
      thighCm;
  final String? note;
  final String? createdBy;

  factory BodyMeasurement.fromJson(Map<String, dynamic> j) {
    final on = (j['measured_on'] as String).substring(0, 10).split('-');
    final created = j['created_at'] == null
        ? null
        : DateTime.tryParse(j['created_at'].toString());
    final note = (j['note'] as String?)?.trim();
    return BodyMeasurement(
      id: j['id'].toString(),
      memberId: j['member_id'].toString(),
      measuredOn: DateTime(
        int.parse(on[0]),
        int.parse(on[1]),
        int.parse(on[2]),
      ),
      createdAt: created ?? DateTime.fromMillisecondsSinceEpoch(0),
      weightKg: parseNumeric(j['weight_kg']),
      bodyFatPct: parseNumeric(j['body_fat_pct']),
      muscleKg: parseNumeric(j['muscle_kg']),
      waistCm: parseNumeric(j['waist_cm']),
      hipCm: parseNumeric(j['hip_cm']),
      chestCm: parseNumeric(j['chest_cm']),
      armCm: parseNumeric(j['arm_cm']),
      thighCm: parseNumeric(j['thigh_cm']),
      note: note == null || note.isEmpty ? null : note,
      createdBy: j['created_by'] as String?,
    );
  }
}

class TrendPoint {
  const TrendPoint(this.date, this.value);
  final DateTime date;
  final double value;

  @override
  bool operator ==(Object other) =>
      other is TrendPoint && other.date == date && other.value == value;

  @override
  int get hashCode => Object.hash(date, value);
}

class MetricProgress {
  const MetricProgress({
    required this.latest,
    required this.latestDate,
    this.previous,
    this.first,
    this.changeFromPrevious,
    this.changeFromFirst,
  });
  final double latest;
  final DateTime latestDate;
  final double? previous;
  final double? first;
  final double? changeFromPrevious;
  final double? changeFromFirst;
}

/// Eskiden yeniye: ölçüm günü, sonra kayıt zamanı.
List<BodyMeasurement> chronological(List<BodyMeasurement> list) {
  final l = [...list];
  l.sort((a, b) {
    final c = a.measuredOn.compareTo(b.measuredOn);
    return c != 0 ? c : a.createdAt.compareTo(b.createdAt);
  });
  return l;
}

MetricProgress? metricProgress(
  MeasurementMetric metric,
  List<BodyMeasurement> list,
) {
  final rows = chronological(list)
      .where((m) => metric.valueOf(m) != null)
      .toList();
  if (rows.isEmpty) return null;
  final latest = metric.valueOf(rows.last)!;
  final date = rows.last.measuredOn;
  if (rows.length == 1) return MetricProgress(latest: latest, latestDate: date);
  final previous = metric.valueOf(rows[rows.length - 2])!;
  final first = metric.valueOf(rows.first)!;
  return MetricProgress(
    latest: latest,
    latestDate: date,
    previous: previous,
    first: first,
    changeFromPrevious: latest - previous,
    changeFromFirst: latest - first,
  );
}

List<TrendPoint> weightTrendPoints(List<BodyMeasurement> list) => [
  for (final m in chronological(list))
    if (m.weightKg != null) TrendPoint(m.measuredOn, m.weightKg!),
];

/// 72.5 -> "72,5", 72.0 -> "72".
String formatNumber(double v) {
  final r = (v * 10).round() / 10;
  if (r == r.truncateToDouble()) return r.truncate().toString();
  return r.toStringAsFixed(1).replaceAll('.', ',');
}

/// "+1,2 kg", "-0,5 kg", "0 kg".
String formatSignedChange(double change, String unit) {
  final r = (change * 10).round() / 10;
  if (r == 0) return '0 $unit';
  return '${r > 0 ? '+' : '-'}${formatNumber(r.abs())} $unit';
}

String formatMetric(MeasurementMetric m, double v) =>
    '${formatNumber(v)} ${m.unit}';

/// Boş = girilmedi (geçerli).
String? validateMetricInput(MeasurementMetric m, String? text) {
  final t = (text ?? '').trim();
  if (t.isEmpty) return null;
  final v = parseDecimal(t);
  if (v == null || !v.isFinite || !RegExp(r'^\d+([.,]\d*)?$').hasMatch(t)) {
    return 'Geçerli bir sayı girin';
  }
  final frac = t.replaceAll(',', '.').split('.');
  if (frac.length > 1 && frac[1].length > 1) {
    return 'En fazla bir ondalık basamak girin';
  }
  if (v < m.min || v > m.max) {
    return '${formatNumber(m.min)} - ${formatNumber(m.max)} ${m.unit} arasında olmalı';
  }
  return null;
}
