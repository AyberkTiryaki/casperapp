import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/widgets/brand.dart';
import '../profile/profile.dart';

/// Masaüstü (Windows/macOS/Linux) uygulaması yalnızca yönetici içindir (16.11.2026 kararı).
/// Üye ve eğitmenler telefon uygulamasını kullanır.
bool desktopBlocksRole(UserRole role, {TargetPlatform? platform, bool? isWeb}) {
  if (isWeb ?? kIsWeb) return false;
  final p = platform ?? defaultTargetPlatform;
  final desktop =
      p == TargetPlatform.windows ||
      p == TargetPlatform.macOS ||
      p == TargetPlatform.linux;
  return desktop && role != UserRole.admin;
}

/// Masaüstünde yönetici olmayan hesapla giriş yapıldığında gösterilir.
class DesktopAdminOnlyView extends StatelessWidget {
  const DesktopAdminOnlyView({super.key, required this.signOut});

  final Widget signOut;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      body: BrandBackdrop(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const BrandLogo(size: 96, glow: true),
                    const SizedBox(height: 28),
                    Text(
                      'Masaüstü uygulaması yönetici içindir',
                      style: t.textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Üye ve eğitmen hesapları için Casper Training Studio telefon uygulamasını kullanın. '
                      'Ders takvimi, rezervasyonlar ve paketleriniz telefonda sizi bekliyor.',
                      style: t.textTheme.bodyLarge?.copyWith(
                        color: t.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    signOut,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
