import 'package:caspertrainingstudio/core/notifications/local_notifications.dart';
import 'package:caspertrainingstudio/core/notifications/notification_planner.dart';
import 'package:caspertrainingstudio/features/packages/domain/package_models.dart';
import 'package:caspertrainingstudio/features/schedule/domain/schedule_models.dart';
import 'package:flutter_test/flutter_test.dart';

MyReservation res(
  String id,
  DateTime start, {
  String status = 'booked',
  String classStatus = 'scheduled',
}) => MyReservation(
  reservationId: id,
  status: status,
  classId: 'c-$id',
  classStatus: classStatus,
  classType: ClassType.individual,
  startsAt: start,
  endsAt: start.add(const Duration(hours: 1)),
  categoryName: 'Özel Ders',
  trainerName: 'Ayşe Eğitmen',
);

MemberPackage pkg(
  String id,
  DateTime ends, {
  String status = 'active',
  List<PackageFreeze> freezes = const [],
}) => MemberPackage(
  id: id,
  memberId: 'm',
  definitionId: 'd',
  categoryId: 'cat',
  totalCredits: 10,
  remainingCredits: 4,
  pricePaid: 100,
  activatedAt: DateTime.utc(2026, 1, 1),
  endsAt: ends,
  status: status,
  categoryName: 'Pilates',
  freezes: freezes,
);

void main() {
  // 14 Kas 2026 (Cumartesi) 09:00 İstanbul = 06:00 UTC
  final now = DateTime.utc(2026, 11, 14, 6);

  test('ders hatırlatması dersten 3 saat önce, iptal süresiyle', () {
    // Pzt 16 Kas 2026 10:00 İstanbul = 07:00 UTC
    final start = DateTime.utc(2026, 11, 16, 7);
    final plan = planNotifications(
      now: now,
      reservations: [res('a', start)],
      packages: const [],
    );
    expect(plan, hasLength(1));
    expect(plan.single.when, DateTime.utc(2026, 11, 16, 4));
    expect(plan.single.title, 'Dersin 3 saat sonra');
    expect(
      plan.single.body,
      'İptal için son 1 saat · Özel Ders · Pzt 16 Kas 10:00 · Ayşe Eğitmen',
    );
  });

  test('geçmiş, iptal ve 3 saatten yakın dersler atlanır', () {
    final plan = planNotifications(
      now: now,
      reservations: [
        res('past', now.subtract(const Duration(days: 1))),
        res('soon', now.add(const Duration(hours: 2, minutes: 30))),
        res('cancelled', now.add(const Duration(days: 2)), status: 'cancelled'),
        res(
          'classcancelled',
          now.add(const Duration(days: 2)),
          classStatus: 'cancelled',
        ),
      ],
      packages: const [],
    );
    expect(plan, isEmpty);
  });

  test('paket uyarısı bitişten 3 gün önce İstanbul 10:00', () {
    // Bitiş 20 Kas 2026 23:59 İstanbul -> uyarı 17 Kas 10:00 İstanbul = 07:00 UTC
    final plan = planNotifications(
      now: now,
      reservations: const [],
      packages: [pkg('p', DateTime.utc(2026, 11, 20, 20, 59))],
    );
    expect(plan.single.when, DateTime.utc(2026, 11, 17, 7));
    expect(plan.single.title, 'Paketin bitmek üzere');
    expect(plan.single.body, 'Pilates · 3 gün kaldı · kalan 4 ders');
  });

  test('zamanı geçmiş uyarı, dondurulmuş, süresi dolmuş paket atlanır', () {
    final plan = planNotifications(
      now: now,
      reservations: const [],
      packages: [
        pkg('late', DateTime.utc(2026, 11, 16, 12)), // uyarı anı geçti
        pkg('expired', DateTime.utc(2026, 11, 10)),
        pkg('terminated', DateTime.utc(2026, 12, 30), status: 'terminated'),
        pkg(
          'frozen',
          DateTime.utc(2026, 12, 30),
          freezes: [
            PackageFreeze(
              id: 'f',
              memberPackageId: 'frozen',
              startsAt: now.subtract(const Duration(days: 1)),
              endsAt: now.add(const Duration(days: 5)),
              days: 6,
            ),
          ],
        ),
      ],
    );
    expect(plan, isEmpty);
  });

  test('kimlikler kararlı ve türe göre ayrık', () {
    expect(stableNotificationId('reservation:abc'), 147297799);
    expect(reservationReminderId('x'), reservationReminderId('x'));
    expect(reservationReminderId('x'), isNot(packageExpiryId('x')));
    expect(reservationReminderId('x'), inInclusiveRange(0, 0x7fffffff));
  });

  test('servis testte başlatılmadan hiçbir şey yapmaz, hata atmaz', () async {
    final s = LocalNotifications();
    await s.init();
    expect(s.isReady, isFalse);
    await s.requestPermission();
    await s.showNow(1, 'a', 'b');
    await s.schedule(1, DateTime.now().add(const Duration(days: 1)), 'a', 'b');
    await s.cancel(1);
    await s.cancelAll();
    await s.replaceScheduled(const []);
  });
}
