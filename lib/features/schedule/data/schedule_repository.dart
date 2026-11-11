import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/supabase.dart';
import '../../../core/utils/uuid.dart';
import '../domain/schedule_models.dart';

abstract class ScheduleRepository {
  Future<List<StudioClass>> listClasses({
    required DateTime from,
    required DateTime to,
    String? categoryId,
    String? trainerId,
    bool includeCancelled = false,
  });
  Future<List<MyReservation>> myReservations();
  Future<List<ClassParticipant>> classParticipants(String classId);
  Future<List<AdminClassReservation>> adminClassReservations(String classId);
  Future<List<TrainerSummary>> listTrainers();

  Future<void> createClass({
    required String categoryId,
    required ClassType classType,
    required DateTime startsAt,
    required int durationMinutes,
    String? title,
    String? trainerId,
  });
  Future<void> cancelClass({
    required String classId,
    bool? refund,
    String? reason,
  });
  Future<void> bookClass({
    required String classId,
    required String idempotencyKey,
    String? memberId,
  });
  Future<void> cancelReservation({
    required String reservationId,
    bool? refund,
    String? reason,
  });
}

List<Map<String, dynamic>> _rows(dynamic r) =>
    (r as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

String? _blankToNull(String? s) =>
    (s == null || s.trim().isEmpty) ? null : s.trim();

class SupabaseScheduleRepository implements ScheduleRepository {
  @override
  Future<List<StudioClass>> listClasses({
    required DateTime from,
    required DateTime to,
    String? categoryId,
    String? trainerId,
    bool includeCancelled = false,
  }) async {
    final r = await supabase.rpc(
      'list_classes',
      params: {
        'p_from': from.toUtc().toIso8601String(),
        'p_to': to.toUtc().toIso8601String(),
        'p_category_id': categoryId,
        'p_trainer_id': trainerId,
        'p_include_cancelled': includeCancelled,
      },
    );
    return _rows(r).map(StudioClass.fromJson).toList();
  }

  @override
  Future<List<MyReservation>> myReservations() async {
    final r = await supabase.rpc('my_reservations');
    return _rows(r).map(MyReservation.fromJson).toList();
  }

  @override
  Future<List<ClassParticipant>> classParticipants(String classId) async {
    final r = await supabase.rpc(
      'class_participants',
      params: {'p_class_id': classId},
    );
    return _rows(r).map(ClassParticipant.fromJson).toList();
  }

  @override
  Future<List<AdminClassReservation>> adminClassReservations(
    String classId,
  ) async {
    final r = await supabase.rpc(
      'admin_class_reservations',
      params: {'p_class_id': classId},
    );
    return _rows(r).map(AdminClassReservation.fromJson).toList();
  }

  @override
  Future<List<TrainerSummary>> listTrainers() async {
    final r = await supabase.rpc('list_trainers');
    return _rows(r).map(TrainerSummary.fromJson).toList();
  }

  @override
  Future<void> createClass({
    required String categoryId,
    required ClassType classType,
    required DateTime startsAt,
    required int durationMinutes,
    String? title,
    String? trainerId,
  }) async {
    await supabase.rpc(
      'create_class',
      params: {
        'p_category_id': categoryId,
        'p_class_type': classType.apiValue,
        'p_starts_at': startsAt.toUtc().toIso8601String(),
        'p_duration_minutes': durationMinutes,
        'p_title': _blankToNull(title),
        'p_trainer_id': ?trainerId,
      },
    );
  }

  @override
  Future<void> cancelClass({
    required String classId,
    bool? refund,
    String? reason,
  }) async {
    await supabase.rpc(
      'cancel_class',
      params: {
        'p_class_id': classId,
        'p_refund': refund ?? true,
        'p_reason': _blankToNull(reason),
      },
    );
  }

  @override
  Future<void> bookClass({
    required String classId,
    required String idempotencyKey,
    String? memberId,
  }) async {
    await supabase.rpc(
      'book_class',
      params: {
        'p_class_id': classId,
        'p_idempotency_key': idempotencyKey,
        'p_member_id': ?memberId,
      },
    );
  }

  @override
  Future<void> cancelReservation({
    required String reservationId,
    bool? refund,
    String? reason,
  }) async {
    await supabase.rpc(
      'cancel_reservation',
      params: {
        'p_reservation_id': reservationId,
        'p_refund': refund,
        'p_reason': _blankToNull(reason),
      },
    );
  }
}

final scheduleRepositoryProvider = Provider<ScheduleRepository>(
  (ref) => SupabaseScheduleRepository(),
);

final bookingKeyHolderProvider = Provider<BookingKeyHolder>(
  (ref) => BookingKeyHolder(generateUuidV4),
);

typedef ClassQuery = ({
  DateTime day,
  String? categoryId,
  String? trainerId,
  bool includeCancelled,
});

/// Yerel günün başlangıcı.
DateTime dayStart(DateTime d) => DateTime(d.year, d.month, d.day);

final classesProvider = FutureProvider.family<List<StudioClass>, ClassQuery>((
  ref,
  q,
) {
  final from = dayStart(q.day);
  final to = DateTime(from.year, from.month, from.day + 1);
  return ref
      .watch(scheduleRepositoryProvider)
      .listClasses(
        from: from,
        to: to,
        categoryId: q.categoryId,
        trainerId: q.trainerId,
        includeCancelled: q.includeCancelled,
      );
}, retry: (_, _) => null);

final myReservationsProvider = FutureProvider<List<MyReservation>>(
  (ref) => ref.watch(scheduleRepositoryProvider).myReservations(),
  retry: (_, _) => null,
);

final participantsProvider =
    FutureProvider.family<List<ClassParticipant>, String>(
      (ref, id) => ref.watch(scheduleRepositoryProvider).classParticipants(id),
      retry: (_, _) => null,
    );

final adminReservationsProvider =
    FutureProvider.family<List<AdminClassReservation>, String>(
      (ref, id) =>
          ref.watch(scheduleRepositoryProvider).adminClassReservations(id),
      retry: (_, _) => null,
    );

final trainersProvider = FutureProvider<List<TrainerSummary>>(
  (ref) => ref.watch(scheduleRepositoryProvider).listTrainers(),
  retry: (_, _) => null,
);
