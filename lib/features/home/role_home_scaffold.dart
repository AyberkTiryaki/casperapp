import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import '../profile/profile.dart';

Future<void> confirmAndSignOut(BuildContext context, WidgetRef ref) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Çıkış yap'),
      content: const Text('Hesabınızdan çıkmak istediğinize emin misiniz?'),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Vazgeç')),
        FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Çıkış yap')),
      ],
    ),
  );
  if (ok == true) await ref.read(authRepositoryProvider).signOut();
}

class ComingModule {
  const ComingModule(this.title, this.icon);
  final String title;
  final IconData icon;
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
            Text('Merhaba, ${profile.fullName}',
                style: t.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('Yakında gelecek modüller', style: t.textTheme.bodyMedium),
            const SizedBox(height: 16),
            for (final m in modules)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Opacity(
                  opacity: 0.5,
                  child: Card(
                    child: ListTile(
                      enabled: false,
                      leading: Icon(m.icon),
                      title: Text(m.title),
                      trailing: const Text('Yakında'),
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
