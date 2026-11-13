import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/supabase.dart';
import '../../../core/utils/formatters.dart';
import '../domain/report_models.dart';

abstract class ReportRepository {
  Future<AdminReport> adminReport(DateTime from, DateTime to);
}

class SupabaseReportRepository implements ReportRepository {
  @override
  Future<AdminReport> adminReport(DateTime from, DateTime to) async {
    final r = await supabase.rpc(
      'admin_report',
      params: {'p_from': isoDate(from), 'p_to': isoDate(to)},
    );
    return AdminReport.fromJson(Map<String, dynamic>.from(r as Map));
  }
}

final reportRepositoryProvider = Provider<ReportRepository>(
  (ref) => SupabaseReportRepository(),
);

final adminReportProvider = FutureProvider.family<AdminReport, DateRange>(
  (ref, range) =>
      ref.watch(reportRepositoryProvider).adminReport(range.from, range.to),
);
