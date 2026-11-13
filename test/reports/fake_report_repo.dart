import 'package:caspertrainingstudio/features/reports/data/report_repository.dart';
import 'package:caspertrainingstudio/features/reports/domain/report_models.dart';

const sampleReportJson = <String, dynamic>{
  'from': '2026-11-01',
  'to': '2026-11-30',
  'generated_at': '2026-11-13T10:00:00Z',
  'package_sales': {
    'count': 5,
    'total': 12300.00,
    'list_total': 12900.00,
    'discount_total': 600.00,
    'discounted_count': 2,
  },
  'product_sales': {
    'count': 4,
    'quantity': 7,
    'total': 420.00,
    'reversed_count': 1,
  },
  'wallet_topups': {'count': 3, 'total': 750.00},
  'members': {'new': 6, 'active_with_package': 5},
  'classes': {
    'held': 12,
    'upcoming': 40,
    'cancelled': 1,
    'capacity': 60,
    'booked': 21,
    'occupancy_pct': 35.0,
  },
  'attendance': {'attended': 19, 'no_show': 2},
  'trainers': [
    {
      'trainer_id': 'uuid',
      'full_name': 'Ayşe Eğitmen',
      'class_count': 8,
      'capacity': 48,
      'booked': 17,
      'attended': 16,
      'no_show': 1,
    },
  ],
  'top_products': [
    {'product_id': 'uuid', 'name': 'Su', 'quantity': 4, 'total': 80.00},
  ],
};

class FakeReportRepository implements ReportRepository {
  AdminReport report = AdminReport.fromJson(sampleReportJson);
  Object? error;
  final calls = <DateRange>[];

  @override
  Future<AdminReport> adminReport(DateTime from, DateTime to) async {
    calls.add(DateRange(from, to));
    if (error != null) throw error!;
    return report;
  }
}
