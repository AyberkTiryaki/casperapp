import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/packages/data/package_repository.dart';
import '../../features/schedule/data/schedule_repository.dart';
import 'local_notifications.dart';
import 'notification_planner.dart';

/// Üye ana ekranını sarar: rezervasyon/paket verisi yüklenince veya değişince
/// hatırlatmaları yeniden planlar. Tercih kapalıysa tümünü iptal eder.
class NotificationSync extends ConsumerStatefulWidget {
  const NotificationSync({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<NotificationSync> createState() => _NotificationSyncState();
}

class _NotificationSyncState extends ConsumerState<NotificationSync> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(notificationsEnabledProvider)) {
        requestPermissionOnce(ref.read(localNotificationsProvider));
      }
      _sync();
    });
  }

  Future<void> _sync() async {
    final service = ref.read(localNotificationsProvider);
    if (!service.isReady) return;
    if (!ref.read(notificationsEnabledProvider)) {
      await service.cancelAll();
      return;
    }
    final reservations = ref.read(myReservationsProvider).value;
    final packages = ref.read(myPackagesProvider).value;
    if (reservations == null || packages == null) return;
    await service.replaceScheduled(
      planNotifications(
        now: DateTime.now(),
        reservations: reservations,
        packages: packages,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(myReservationsProvider, (_, _) => _sync());
    ref.listen(myPackagesProvider, (_, _) => _sync());
    ref.listen(notificationsEnabledProvider, (_, next) {
      if (next) requestPermissionOnce(ref.read(localNotificationsProvider));
      _sync();
    });
    return widget.child;
  }
}
