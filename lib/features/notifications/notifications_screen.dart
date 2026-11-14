import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/supabase.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/async_value_view.dart';
import '../../core/widgets/empty_view.dart';
import '../auth/auth_providers.dart';
import '../../core/widgets/home_button.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String kind;
  final String title;
  final String body;
  final DateTime createdAt;

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
    id: j['id'] as String,
    kind: (j['kind'] as String?) ?? '',
    title: (j['title'] as String?) ?? '',
    body: (j['body'] as String?) ?? '',
    createdAt: DateTime.parse(j['created_at'] as String),
  );
}

IconData notificationIcon(String kind) => switch (kind) {
  'booking_confirmed' => Icons.event_available_outlined,
  'reservation_cancelled' => Icons.event_busy_outlined,
  'class_reminder' => Icons.alarm_outlined,
  'package_expiring' => Icons.hourglass_bottom_outlined,
  _ => Icons.notifications_outlined,
};

final notificationsProvider = FutureProvider.autoDispose<List<AppNotification>>(
  (ref) async {
    final uid = ref.watch(currentUserIdProvider);
    if (uid == null) return [];
    final rows = await supabase
        .from('notifications')
        .select('id, kind, title, body, created_at')
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(100);
    return rows.map(AppNotification.fromJson).toList();
  },
);

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(notificationsProvider);
    return Scaffold(
      appBar: AppBar(
        actions: const [HomeButton()],
        title: const Text('Bildirimler'),
      ),
      body: SafeArea(
        child: AsyncValueView<List<AppNotification>>(
          value: value,
          onRetry: () => ref.invalidate(notificationsProvider),
          data: (items) => RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(notificationsProvider);
              await ref.read(notificationsProvider.future);
            },
            child: items.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 120),
                      EmptyView(
                        title: 'Bildirim yok',
                        message: 'Yeni bildirimleriniz burada görünür.',
                        icon: Icons.notifications_none,
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final n = items[i];
                      return ListTile(
                        leading: Icon(notificationIcon(n.kind)),
                        title: Text(n.title),
                        subtitle: Text(
                          '${n.body}\n${formatDate(n.createdAt)} ${formatTime(n.createdAt)}',
                        ),
                        isThreeLine: true,
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }
}
