import 'dart:async';

import '../../../core/widgets/async_value_view.dart' show isNetworkError;

DateTime _dt(dynamic v) => DateTime.parse(v as String).toLocal();
DateTime? _dtOrNull(dynamic v) => v == null ? null : _dt(v);

/// Üye, dersten en geç bu kadar öncesine kadar (sınır dahil) iptal edebilir.
/// Sunucudaki cancel_reservation kuralıyla aynı olmalıdır.
const memberCancelCutoff = Duration(hours: 2);

bool canMemberCancel(DateTime startsAt, DateTime now) =>
    !now.isAfter(startsAt.subtract(memberCancelCutoff));

enum ClassType {
  individual('Bireysel', 'individual'),
  group('Grup', 'group');

  const ClassType(this.label, this.apiValue);
  final String label;
  final String apiValue;

  static ClassType fromString(String? v) =>
      v == 'group' ? ClassType.group : ClassType.individual;
}

class StudioClass {
  const StudioClass({
    required this.id,
    required this.trainerId,
    required this.trainerName,
    required this.categoryId,
    required this.categoryName,
    required this.classType,
    required this.capacity,
    required this.bookedCount,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    this.title,
    this.myReservationId,
  });
  final String id;
  final String trainerId;
  final String trainerName;
  final String categoryId;
  final String categoryName;
  final ClassType classType;
  final int capacity;
  final int bookedCount;
  final String? title;
  final DateTime startsAt;
  final DateTime endsAt;

  /// 'scheduled' | 'cancelled'
  final String status;
  final String? myReservationId;

  int get remainingSpots =>
      (capacity - bookedCount) < 0 ? 0 : capacity - bookedCount;
  bool get isFull => bookedCount >= capacity;
  bool get isCancelled => status == 'cancelled';
  bool get isBookedByMe => myReservationId != null;
  bool hasStarted(DateTime now) => !startsAt.isAfter(now);

  factory StudioClass.fromJson(Map<String, dynamic> j) => StudioClass(
    id: j['id'] as String,
    trainerId: (j['trainer_id'] as String?) ?? '',
    trainerName: (j['trainer_name'] as String?) ?? '',
    categoryId: (j['category_id'] as String?) ?? '',
    categoryName: (j['category_name'] as String?) ?? '',
    classType: ClassType.fromString(j['class_type'] as String?),
    capacity: (j['capacity'] as num).toInt(),
    bookedCount: (j['booked_count'] as num?)?.toInt() ?? 0,
    title: j['title'] as String?,
    startsAt: _dt(j['starts_at']),
    endsAt: _dt(j['ends_at']),
    status: (j['status'] as String?) ?? 'scheduled',
    myReservationId: j['my_reservation_id'] as String?,
  );
}

class MyReservation {
  const MyReservation({
    required this.reservationId,
    required this.status,
    required this.classId,
    required this.classStatus,
    required this.classType,
    required this.startsAt,
    required this.endsAt,
    required this.categoryName,
    required this.trainerName,
    this.creditRefunded = false,
    this.title,
    this.cancelledAt,
  });
  final String reservationId;

  /// 'booked' | 'cancelled' | 'no_show'
  final String status;
  final String classId;
  final String classStatus;
  final ClassType classType;
  final String? title;
  final DateTime startsAt;
  final DateTime endsAt;
  final String categoryName;
  final String trainerName;
  final bool creditRefunded;
  final DateTime? cancelledAt;

  bool isUpcoming(DateTime now) =>
      status == 'booked' && classStatus == 'scheduled' && startsAt.isAfter(now);

  String statusLabel(DateTime now) {
    if (classStatus == 'cancelled') return 'Ders iptal edildi';
    switch (status) {
      case 'cancelled':
        return creditRefunded
            ? 'İptal edildi (hak iade edildi)'
            : 'İptal edildi (hak iade edilmedi)';
      case 'no_show':
        return 'Gelmedi';
      default:
        return isUpcoming(now) ? 'Rezervasyon aktif' : 'Katıldı';
    }
  }

  factory MyReservation.fromJson(Map<String, dynamic> j) => MyReservation(
    reservationId: j['reservation_id'] as String,
    status: (j['status'] as String?) ?? 'booked',
    classId: (j['class_id'] as String?) ?? '',
    classStatus: (j['class_status'] as String?) ?? 'scheduled',
    classType: ClassType.fromString(j['class_type'] as String?),
    title: j['title'] as String?,
    startsAt: _dt(j['starts_at']),
    endsAt: _dt(j['ends_at']),
    categoryName: (j['category_name'] as String?) ?? '',
    trainerName: (j['trainer_name'] as String?) ?? '',
    creditRefunded: (j['credit_refunded'] as bool?) ?? false,
    cancelledAt: _dtOrNull(j['cancelled_at']),
  );
}

class ClassParticipant {
  const ClassParticipant({
    required this.reservationId,
    required this.memberId,
    required this.fullName,
    required this.status,
  });
  final String reservationId;
  final String memberId;
  final String fullName;
  final String status;

  factory ClassParticipant.fromJson(Map<String, dynamic> j) => ClassParticipant(
    reservationId: j['reservation_id'] as String,
    memberId: (j['member_id'] as String?) ?? '',
    fullName: (j['full_name'] as String?) ?? '',
    status: (j['status'] as String?) ?? 'booked',
  );
}

class AdminClassReservation {
  const AdminClassReservation({
    required this.reservationId,
    required this.memberId,
    required this.fullName,
    required this.status,
    required this.creditRefunded,
    this.cancelReason,
  });
  final String reservationId;
  final String memberId;
  final String fullName;
  final String status;
  final bool creditRefunded;
  final String? cancelReason;

  factory AdminClassReservation.fromJson(Map<String, dynamic> j) =>
      AdminClassReservation(
        reservationId: j['reservation_id'] as String,
        memberId: (j['member_id'] as String?) ?? '',
        fullName: (j['full_name'] as String?) ?? '',
        status: (j['status'] as String?) ?? 'booked',
        creditRefunded: (j['credit_refunded'] as bool?) ?? false,
        cancelReason: j['cancel_reason'] as String?,
      );
}

class TrainerSummary {
  const TrainerSummary({required this.id, required this.fullName});
  final String id;
  final String fullName;

  factory TrainerSummary.fromJson(Map<String, dynamic> j) => TrainerSummary(
    id: j['id'] as String,
    fullName: (j['full_name'] as String?) ?? '',
  );
}

/// Rezervasyon işlem anahtarı tutucu: ağ hatasında aynı anahtar yeniden kullanılır;
/// başarı veya iş kuralı hatasında temizlenir (sonraki deneme yeni anahtar alır).
class BookingKeyHolder {
  BookingKeyHolder(this._generate);
  final String Function() _generate;
  final _pending = <String, String>{};

  String keyFor(String id) => _pending.putIfAbsent(id, _generate);
  void clear(String id) => _pending.remove(id);

  Future<T> run<T>(String id, Future<T> Function(String key) action) async {
    final key = keyFor(id);
    try {
      final r = await action(key);
      clear(id);
      return r;
    } catch (e) {
      if (!isNetworkError(e) && e is! TimeoutException) clear(id);
      rethrow;
    }
  }
}
