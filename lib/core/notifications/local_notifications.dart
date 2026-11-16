import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'notification_planner.dart';

const _channelId = 'casper_reminders';
const _channelName = 'Casper hatırlatmalar';
const _prefsEnabledKey = 'notifications_enabled';
const _prefsAskedKey = 'notifications_permission_asked';

/// Cihaz içi (yerel) bildirim servisi. Desteklenmeyen yerde (test, web, Linux/macOS)
/// ya da [init] çağrılmadıysa tüm çağrılar sessizce hiçbir şey yapmaz; arayüze hata atmaz.
class LocalNotifications {
  LocalNotifications();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;
  late tz.Location _istanbul;

  bool get isReady => _ready;

  static bool get _platformSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.windows);

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Ders hatırlatmaları ve paket uyarıları',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    ),
    iOS: DarwinNotificationDetails(),
    windows: WindowsNotificationDetails(),
  );

  Future<void> init() async {
    if (_ready || !_platformSupported) return;
    try {
      tzdata.initializeTimeZones();
      _istanbul = tz.getLocation('Europe/Istanbul');
      final ok = await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
          windows: WindowsInitializationSettings(
            appName: 'Casper Training Studio',
            appUserModelId: 'CasperTrainingStudio.App',
            guid: '5f0c6d3e-8a4b-4c1e-9d27-3b6a1f8e2c40',
          ),
        ),
      );
      _ready = ok != false;
    } catch (e) {
      debugPrint('Bildirimler başlatılamadı: $e');
      _ready = false;
    }
  }

  /// Android 13+ ve iOS bildirim izni. Başarısızlık hata atmaz.
  Future<void> requestPermission() async {
    if (!_ready) return;
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission();
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true);
      }
    } catch (e) {
      debugPrint('Bildirim izni istenemedi: $e');
    }
  }

  Future<void> showNow(int id, String title, String body) async {
    if (!_ready) return;
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: _details,
      );
    } catch (e) {
      debugPrint('Bildirim gösterilemedi: $e');
    }
  }

  Future<void> schedule(
    int id,
    DateTime when,
    String title,
    String body,
  ) async {
    if (!_ready || !when.isAfter(DateTime.now())) return;
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(when, _istanbul),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('Bildirim planlanamadı: $e');
    }
  }

  Future<void> cancel(int id) async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id: id);
    } catch (e) {
      debugPrint('Bildirim iptal edilemedi: $e');
    }
  }

  Future<void> cancelAll() async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('Bildirimler iptal edilemedi: $e');
    }
  }

  /// Daha önce planlanmış bekleyen bildirimleri siler, yenilerini planlar.
  /// Anında gösterilmiş (ör. rezervasyon onayı) bildirimlere dokunmaz.
  Future<void> replaceScheduled(List<PlannedNotification> planned) async {
    if (!_ready) return;
    try {
      final pending = await _plugin.pendingNotificationRequests();
      for (final p in pending) {
        await _plugin.cancel(id: p.id);
      }
    } catch (e) {
      debugPrint('Bekleyen bildirimler okunamadı: $e');
    }
    for (final n in planned) {
      await schedule(n.id, n.when, n.title, n.body);
    }
  }
}

final localNotificationsProvider = Provider<LocalNotifications>(
  (ref) => LocalNotifications(),
);

/// Üyenin "Bildirimler" tercihi (cihazda saklanır, varsayılan açık).
class NotificationsEnabled extends Notifier<bool> {
  @override
  bool build() {
    _load();
    return true;
  }

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final v = p.getBool(_prefsEnabledKey);
      if (v != null && v != state) state = v;
    } catch (_) {}
  }

  Future<void> set(bool value) async {
    state = value;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_prefsEnabledKey, value);
    } catch (_) {}
  }
}

final notificationsEnabledProvider =
    NotifierProvider<NotificationsEnabled, bool>(NotificationsEnabled.new);

/// İzni cihaz başına bir kez ister.
Future<void> requestPermissionOnce(LocalNotifications service) async {
  if (!service.isReady) return;
  try {
    final p = await SharedPreferences.getInstance();
    if (p.getBool(_prefsAskedKey) ?? false) return;
    await p.setBool(_prefsAskedKey, true);
  } catch (_) {
    return;
  }
  await service.requestPermission();
}

/// Rezervasyon başarıyla yapılınca anında onay bildirimi gösterir.
Future<void> notifyBookingConfirmed(
  WidgetRef ref, {
  required String classId,
  required String categoryName,
  required DateTime startsAt,
  String trainerName = '',
}) async {
  if (!ref.read(notificationsEnabledProvider)) return;
  await ref
      .read(localNotificationsProvider)
      .showNow(
        bookingConfirmedId(classId),
        'Rezervasyonun onaylandı',
        classNotificationBody(
          categoryName: categoryName,
          startsAt: startsAt,
          trainerName: trainerName,
        ),
      );
}
