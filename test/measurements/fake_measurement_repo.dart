import 'package:caspertrainingstudio/features/measurements/data/measurement_repository.dart';
import 'package:caspertrainingstudio/features/measurements/domain/measurement_models.dart';

class AddCall {
  AddCall(this.memberId, this.measuredOn, this.values, this.note);
  final String memberId;
  final DateTime measuredOn;
  final Map<MeasurementMetric, double> values;
  final String? note;
}

class FakeMeasurementRepository implements MeasurementRepository {
  List<BodyMeasurement> rows = [];
  final addCalls = <AddCall>[];
  final deleted = <String>[];
  Object? addError;

  @override
  Future<List<BodyMeasurement>> measurements(String memberId) async => rows;

  @override
  Future<void> add({
    required String memberId,
    required DateTime measuredOn,
    required Map<MeasurementMetric, double> values,
    String? note,
  }) async {
    if (addError != null) throw addError!;
    addCalls.add(AddCall(memberId, measuredOn, values, note));
  }

  @override
  Future<void> delete(String measurementId) async => deleted.add(measurementId);
}

BodyMeasurement sampleMeasurement(
  String id,
  String day, {
  double? weight,
  double? waist,
  String? note,
  DateTime? createdAt,
}) => BodyMeasurement(
  id: id,
  memberId: 'm1',
  measuredOn: DateTime.parse(day),
  createdAt: createdAt ?? DateTime.parse('${day}T10:00:00Z'),
  weightKg: weight,
  waistCm: waist,
  note: note,
);
