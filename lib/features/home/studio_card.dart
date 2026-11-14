import 'package:flutter/material.dart';

import '../../core/config/studio.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/brand.dart';
import 'dashboard_widgets.dart';

/// Stüdyo adresi, yol tarifi ve iletişim bağlantıları.
class StudioCard extends StatelessWidget {
  const StudioCard({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const BrandLogo(size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    Studio.name,
                    style: const TextStyle(
                      fontFamily: AppFonts.display,
                      fontWeight: FontWeight.w700,
                      fontSize: 22,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.place_outlined,
                  size: 20,
                  color: t.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SelectableText(
                    Studio.address,
                    style: t.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.phone_outlined,
                  size: 20,
                  color: t.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                SelectableText(
                  Studio.phoneDisplay,
                  style: t.textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => openExternal(context, Studio.mapsUrl),
              icon: const Icon(Icons.directions_rounded),
              label: const Text('YOL TARİFİ AL'),
            ),
            const SizedBox(height: 12),
            _ButtonPair(
              left: OutlinedButton.icon(
                onPressed: () => openExternal(context, Studio.whatsappUrl),
                icon: const Icon(Icons.chat_outlined),
                label: const Text('WhatsApp'),
              ),
              right: OutlinedButton.icon(
                onPressed: () => openExternal(context, Studio.phoneUrl),
                icon: const Icon(Icons.call_outlined),
                label: const Text('Ara'),
              ),
            ),
            const SizedBox(height: 12),
            _ButtonPair(
              left: OutlinedButton.icon(
                onPressed: () => openExternal(context, Studio.instagramUrl),
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Instagram'),
              ),
              right: OutlinedButton.icon(
                onPressed: () => openExternal(context, Studio.emailUrl),
                icon: const Icon(Icons.mail_outline_rounded),
                label: const Text('E-posta'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Yan yana iki buton; dar ekranda (ör. büyük yazı) alt alta geçer.
class _ButtonPair extends StatelessWidget {
  const _ButtonPair({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) => c.maxWidth < 300
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [left, const SizedBox(height: 12), right],
            )
          : Row(
              children: [
                Expanded(child: left),
                const SizedBox(width: 12),
                Expanded(child: right),
              ],
            ),
    );
  }
}

/// Profil gibi ekranlarda başlıklı kullanım.
class StudioSection extends StatelessWidget {
  const StudioSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [SectionLabel('Stüdyo'), SizedBox(height: 12), StudioCard()],
    );
  }
}
