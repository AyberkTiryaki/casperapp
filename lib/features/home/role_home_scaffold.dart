import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import '../notifications/notifications_screen.dart';
import '../profile/profile.dart';
import '../profile/profile_screen.dart';

Future<void> confirmAndSignOut(BuildContext context, WidgetRef ref) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Çıkış yap'),
      content: const Text('Hesabınızdan çıkmak istediğinize emin misiniz?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Çıkış yap'),
        ),
      ],
    ),
  );
  if (ok == true) await ref.read(authRepositoryProvider).signOut();
}

class ComingModule {
  const ComingModule(this.title, this.icon, {this.onTap});
  final String title;
  final IconData icon;

  /// Verilirse kart çalışır durumdadır; verilmezse "Yakında" olarak devre dışıdır.
  final VoidCallback? onTap;
}

/// Rol ana ekranları için ortak iskelet: başlık, karşılama, yakında gelecek modüller.
class RoleHomeScaffold extends ConsumerWidget {
  const RoleHomeScaffold({
    super.key,
    required this.profile,
    required this.modules,
  });

  final Profile profile;
  final List<ComingModule> modules;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(profile.role.label),
        actions: [
          IconButton(
            tooltip: 'Bildirimler',
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Profilim',
            icon: const Icon(Icons.person_outline),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
          ),
          IconButton(
            tooltip: 'Çıkış yap',
            icon: const Icon(Icons.logout),
            onPressed: () => confirmAndSignOut(context, ref),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Merhaba, ${profile.fullName}',
              style: t.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text('Modüller', style: t.textTheme.bodyMedium),
            const SizedBox(height: 16),
            for (final m in modules)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Opacity(
                  opacity: m.onTap == null ? 0.5 : 1,
                  child: Card(
                    child: ListTile(
                      enabled: m.onTap != null,
                      onTap: m.onTap,
                      leading: Icon(m.icon),
                      title: Text(m.title),
                      trailing: m.onTap == null
                          ? const Text('Yakında')
                          : const Icon(Icons.chevron_right),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => confirmAndSignOut(context, ref),
              icon: const Icon(Icons.logout),
              label: const Text('Çıkış yap'),
            ),
          ],
        ),
      ),
    );
  }
}
