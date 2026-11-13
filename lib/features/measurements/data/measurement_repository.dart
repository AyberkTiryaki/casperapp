import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/supabase.dart';
import '../../../core/utils/formatters.dart';
import '../domain/measurement_models.dart';

abstract class MeasurementRepository {
  Future<List<BodyMeasurement>> measurements(String memberId);
  Future<void> add({
    required String memberId,
    required DateTime measuredOn,
    required Map<MeasurementMetric, double> values,
    String? note,
  });
  Future<void> delete(String measurementId);
}

class SupabaseMeasurementRepository implements MeasurementRepository {
  @override
  Future<List<BodyMeasurement>> measurements(String memberId) async {
    final r = await supabase
        .from('body_measurements')
        .select()
        .eq('member_id', memberId)
        .order('measured_on', ascending: false)
        .order('created_at', ascending: false)
        .limit(500);
    return (r as List)
        .map(
          (e) => BodyMeasurement.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  @override
  Future<void> add({
    required String memberId,
    required DateTime measuredOn,
    required Map<MeasurementMetric, double> values,
    String? note,
  }) => supabase.rpc(
    'add_body_measurement',
    params: {
      'p_member_id': memberId,
      'p_measured_on': isoDate(measuredOn),
      for (final m in MeasurementMetric.values) m.rpcParam: values[m],
      'p_note': note,
    },
  );

  @override
  Future<void> delete(String measurementId) => supabase.rpc(
    'delete_body_measurement',
    params: {'p_measurement_id': measurementId},
  );
}

final measurementRepositoryProvider = Provider<MeasurementRepository>(
  (ref) => SupabaseMeasurementRepository(),
);

final measurementsProvider =
    FutureProvider.family<List<BodyMeasurement>, String>(
      (ref, memberId) =>
          ref.watch(measurementRepositoryProvider).measurements(memberId),
    );
