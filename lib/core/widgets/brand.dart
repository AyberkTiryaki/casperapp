import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

const _logoAsset = 'assets/branding/logo.png';

/// Türkçe büyük harf: i → İ, ı → I (Dart'ın toUpperCase'i i'yi I yapar).
String trUpper(String s) =>
    s.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();

/// Yuvarlak logo; isteğe bağlı mavi ışıltıyla.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 40, this.glow = false});

  final double size;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: glow
            ? [
                BoxShadow(
                  color: AppColors.electricBlue.withValues(alpha: 0.55),
                  blurRadius: size * 0.45,
                  spreadRadius: size * 0.02,
                ),
              ]
            : null,
      ),
      child: ClipOval(
        child: Image.asset(
          _logoAsset,
          width: size,
          height: size,
          fit: BoxFit.cover,
          cacheWidth: (size * 3).round(),
          semanticLabel: 'Casper Training Studio logosu',
        ),
      ),
    );
  }
}

/// "CASPER / TRAINING STUDIO" yazı markası.
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({super.key, this.size = 44, this.center = true});

  final double size;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Column(
      crossAxisAlignment: center
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'CASPER',
          style: TextStyle(
            fontFamily: AppFonts.display,
            fontWeight: FontWeight.w800,
            fontStyle: FontStyle.italic,
            fontSize: size,
            letterSpacing: size * 0.12,
            height: 1,
            color: onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'TRAINING STUDIO',
          style: TextStyle(
            fontFamily: AppFonts.display,
            fontWeight: FontWeight.w600,
            fontSize: size * 0.34,
            letterSpacing: size * 0.13,
            color: context.palette.link,
          ),
        ),
      ],
    );
  }
}

/// Üstten mavi ışıltılı koyu zemin (giriş ve kayıt ekranları).
class BrandBackdrop extends StatelessWidget {
  const BrandBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -1.1),
          radius: 1.25,
          colors: [
            AppColors.electricBlue.withValues(alpha: isDark ? 0.38 : 0.18),
            AppColors.brandBlue.withValues(alpha: isDark ? 0.12 : 0.05),
            Colors.transparent,
          ],
          stops: const [0, 0.45, 1],
        ),
      ),
      child: child,
    );
  }
}

/// Ana sayfanın degrade kahraman başlığı: rol etiketi, karşılama ve motivasyon cümlesi.
class HeroHeader extends StatelessWidget {
  const HeroHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
  });

  final String eyebrow;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: AppGradients.hero,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: AppColors.electricBlue.withValues(alpha: 0.35),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Sağ alttan taşan, soluk logo filigranı
          Positioned(
            right: -46,
            bottom: -56,
            child: Opacity(opacity: 0.22, child: const BrandLogo(size: 190)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    trUpper(eyebrow),
                    style: const TextStyle(
                      fontFamily: AppFonts.display,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      letterSpacing: 1.6,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.only(right: 90),
                  child: Text(
                    trUpper(title),
                    style: const TextStyle(
                      fontFamily: AppFonts.display,
                      fontWeight: FontWeight.w800,
                      fontStyle: FontStyle.italic,
                      fontSize: 34,
                      height: 1.02,
                      letterSpacing: 0.6,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.only(right: 90),
                    child: Text(
                      subtitle!,
                      style: TextStyle(
                        fontFamily: AppFonts.body,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Degrade zeminli ikon rozeti.
class GradientIconBadge extends StatelessWidget {
  const GradientIconBadge(
    this.icon, {
    super.key,
    this.size = 46,
    this.muted = false,
  });

  final IconData icon;
  final double size;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: muted ? null : AppGradients.brand,
        color: muted
            ? Theme.of(context).colorScheme.surfaceContainerHigh
            : null,
        borderRadius: BorderRadius.circular(size * 0.32),
        boxShadow: muted
            ? null
            : [
                BoxShadow(
                  color: AppColors.electricBlue.withValues(alpha: 0.4),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.5),
    );
  }
}

/// Ana sayfa modül kartı (ızgara hücresi).
class ModuleTile extends StatelessWidget {
  const ModuleTile({
    super.key,
    required this.title,
    required this.icon,
    this.subtitle,
    this.onTap,
  });

  final String title;
  final IconData icon;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: AppColors.electricBlue.withValues(alpha: 0.18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GradientIconBadge(icon, muted: !enabled),
                    const Spacer(),
                    if (enabled)
                      Icon(
                        Icons.arrow_outward_rounded,
                        size: 20,
                        color: t.colorScheme.onSurfaceVariant,
                      )
                    else
                      Text(
                        'YAKINDA',
                        style: t.textTheme.labelSmall?.copyWith(
                          letterSpacing: 1.2,
                          color: t.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppFonts.display,
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    height: 1.1,
                    letterSpacing: 0.3,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppFonts.body,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: context.palette.accent,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bölüm başlığı: kısa mavi çizgi + büyük harf.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 18,
          height: 3,
          decoration: BoxDecoration(
            gradient: AppGradients.brand,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          trUpper(text),
          style: TextStyle(
            fontFamily: AppFonts.display,
            fontWeight: FontWeight.w700,
            fontSize: 15,
            letterSpacing: 2,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
