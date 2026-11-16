import '../../features/packages/domain/package_models.dart';
import '../../features/schedule/domain/schedule_models.dart';

/// Planlanan tek bir yerel bildirim.
class PlannedNotification {
  const PlannedNotification({
    required this.id,
    required this.when,
    required this.title,
    required this.body,
  });

  final int id;

  /// Gösterim anı (UTC an).
  final DateTime when;
  final String title;
  final String body;
}

/// Stüdyo Türkiye'de; Türkiye yıl boyu UTC+3 (yaz saati uygulaması yok).
const _istanbulOffset = Duration(hours: 3);

const _weekdays = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
const _months = [
  'Oca',
  'Şub',
  'Mar',
  'Nis',
  'May',
  'Haz',
  'Tem',
  'Ağu',
  'Eyl',
  'Eki',
  'Kas',
  'Ara',
];

/// Süreçler arası kararlı 31 bit FNV-1a özeti (String.hashCode kararlılığı garanti değildir).
int stableNotificationId(String key) {
  var h = 0x811c9dc5;
  for (final unit in key.codeUnits) {
    h ^= unit;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return h & 0x7fffffff;
}

int reservationReminderId(String reservationId) =>
    stableNotificationId('reservation:$reservationId');
int packageExpiryId(String packageId) =>
    stableNotificationId('package:$packageId');
int bookingConfirmedId(String classId) =>
    stableNotificationId('booked:$classId');

/// "Pzt 17 Kas 10:00" (İstanbul saati).
String formatIstanbulShort(DateTime instant) {
  final d = instant.toUtc().add(_istanbulOffset);
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return '${_weekdays[d.weekday - 1]} ${d.day} ${_months[d.month - 1]} $hh:$mm';
}

/// Gövde: "Özel Ders · Pzt 17 Kas 10:00 · Ayşe Eğitmen".
String classNotificationBody({
  required String categoryName,
  required DateTime startsAt,
  String trainerName = '',
}) => [
  categoryName.isEmpty ? 'Ders' : categoryName,
  formatIstanbulShort(startsAt),
  if (trainerName.isNotEmpty) trainerName,
].join(' · ');

/// Hatırlatma, ders başlamadan bu kadar önce gelir.
const reservationLead = Duration(hours: 2);

/// Paket bitiminden kaç gün önce uyarılır.
const packageWarnDays = 3;

/// Üyenin verisinden istenen bildirim kümesini çıkarır (saf fonksiyon).
List<PlannedNotification> planNotifications({
  required DateTime now,
  required List<MyReservation> reservations,
  required List<MemberPackage> packages,
}) {
  final out = <PlannedNotification>[];
  for (final r in reservations) {
    if (!r.isUpcoming(now)) continue;
    final when = r.startsAt.toUtc().subtract(reservationLead);
    if (!when.isAfter(now)) continue;
    out.add(
      PlannedNotification(
        id: reservationReminderId(r.reservationId),
        when: when,
        title: 'Dersin 2 saat sonra',
        body: classNotificationBody(
          categoryName: r.categoryName,
          startsAt: r.startsAt,
          trainerName: r.trainerName,
        ),
      ),
    );
  }
  for (final p in packages) {
    if (p.displayStatus(now) != PackageDisplayStatus.active) continue;
    // Bitişten 3 gün önceki İstanbul gününün 10:00'u.
    final endLocal = p.endsAt.toUtc().add(_istanbulOffset);
    final when = DateTime.utc(
      endLocal.year,
      endLocal.month,
      endLocal.day - packageWarnDays,
      10,
    ).subtract(_istanbulOffset);
    if (!when.isAfter(now)) continue;
    final name = p.categoryName ?? p.definitionName ?? 'Paket';
    out.add(
      PlannedNotification(
        id: packageExpiryId(p.id),
        when: when,
        title: 'Paketin bitmek üzere',
        body:
            '$name · $packageWarnDays gün kaldı · kalan ${p.remainingCredits} ders',
      ),
    );
  }
  out.sort((a, b) => a.when.compareTo(b.when));
  return out;
}
