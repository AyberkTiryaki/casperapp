import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/brand.dart';
import '../auth/auth_providers.dart';
import '../notifications/notifications_screen.dart';
import '../profile/profile.dart';
import '../profile/profile_screen.dart';

Future<void> confirmAndSignOut(BuildContext context, WidgetRef ref) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      actionsOverflowDirection: VerticalDirection.up,
      actionsOverflowButtonSpacing: 12,
      title: const Text('Çıkış yap'),
      content: const Text('Hesabınızdan çıkmak istediğinize emin misiniz?'),
      actions: [
        OutlinedButton(
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
  const ComingModule(this.title, this.icon, {this.onTap, this.subtitle});
  final String title;
  final IconData icon;

  /// Kartta başlığın altında gösterilen kısa bilgi (ör. güncel bakiye).
  final String? subtitle;

  /// Verilirse kart çalışır durumdadır; verilmezse "Yakında" olarak devre dışıdır.
  final VoidCallback? onTap;
}

/// Rol ana ekranları için ortak iskelet: logo, degrade karşılama, modül ızgarası.
class RoleHomeScaffold extends ConsumerWidget {
  const RoleHomeScaffold({
    super.key,
    required this.profile,
    required this.modules,
  });

  final Profile profile;
  final List<ComingModule> modules;

  static const _mottos = {
    UserRole.member: [
      'Bugün kendinin en güçlü hâli için bir adım daha.',
      'Disiplin, motivasyonun bittiği yerde başlar.',
      'Ter bugün, gurur yarın.',
      'Her tekrar seni hedefe yaklaştırır.',
      'Güçlü başla, güçlü bitir.',
      'Vücudun yapabilir. İkna etmen gereken zihnin.',
      'Dinlenmek de antrenmanın parçası. Yarın daha güçlü dön.',
    ],
    UserRole.trainer: [
      'Bugün kimin hayatına güç katacaksın?',
      'İyi bir antrenör, potansiyeli görünür kılar.',
      'Her ders, birinin dönüm noktası olabilir.',
      'Enerjin salona yayılır.',
      'Doğru form, güçlü sonuç.',
      'Üyelerin senin ritminle hareket ediyor.',
      'Haftayı güçlü kapat.',
    ],
    UserRole.admin: [
      'Stüdyonun nabzı burada atıyor.',
      'Düzenli bir salon, mutlu üyeler demek.',
      'Bugün de her şey kontrol altında.',
      'Güçlü bir topluluk, güçlü bir stüdyo.',
      'Rakamlar büyüyor, enerji yükseliyor.',
      'Her üye bir hikâye.',
      'Haftayı güçlü kapat.',
    ],
  };

  String _motto() {
    final list = _mottos[profile.role] ?? _mottos[UserRole.member]!;
    return list[(DateTime.now().weekday - 1) % list.length];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final first = profile.fullName.trim().split(RegExp(r'\s+')).first;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            const BrandLogo(size: 34),
            const SizedBox(width: 10),
            Text(
              'CASPER',
              style: TextStyle(
                fontFamily: AppFonts.display,
                fontWeight: FontWeight.w800,
                fontStyle: FontStyle.italic,
                fontSize: 24,
                letterSpacing: 3,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Bildirimler',
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Profilim',
            icon: const Icon(Icons.person_outline_rounded),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
          ),
          IconButton(
            tooltip: 'Çıkış yap',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => confirmAndSignOut(context, ref),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            HeroHeader(
              eyebrow: profile.role.label,
              title: first.isEmpty ? 'Hoş geldin' : 'Merhaba,\n$first',
              subtitle: _motto(),
            ),
            const SizedBox(height: 28),
            const SectionLabel('Hızlı erişim'),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, c) {
                final cols = c.maxWidth >= 900
                    ? 4
                    : c.maxWidth >= 600
                    ? 3
                    : 2;
                return GridView.count(
                  crossAxisCount: cols,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.05,
                  children: [
                    for (final m in modules)
                      ModuleTile(
                        title: m.title,
                        icon: m.icon,
                        subtitle: m.subtitle,
                        onTap: m.onTap,
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => confirmAndSignOut(context, ref),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('ÇIKIŞ YAP'),
            ),
          ],
        ),
      ),
    );
  }
}
