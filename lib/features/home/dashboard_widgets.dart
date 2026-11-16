import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/error_messages.dart';

/// Ana sayfa bilgi kartı: gece mavisi zemin, 18 px yarıçap.
class DashCard extends StatelessWidget {
  const DashCard({
    super.key,
    required this.child,
    this.onTap,
    this.borderColor,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color? borderColor;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(color: borderColor ?? context.palette.outline),
    );
    final material = Material(
      color: context.palette.card,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: shape,
        child: Padding(padding: padding, child: child),
      ),
    );
    final shadow = context.palette.cardShadow;
    if (shadow == null) return material;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: shadow,
      ),
      child: material,
    );
  }
}

/// Yükleniyor göstergesi (kart içinde küçük ilerleme halkası).
class DashLoading extends StatelessWidget {
  const DashLoading({super.key, this.height = 96});
  final double height;

  @override
  Widget build(BuildContext context) => DashCard(
    child: SizedBox(
      height: height - 32,
      child: const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
    ),
  );
}

/// Kısa hata iletisi + yeniden dene.
class DashError extends StatelessWidget {
  const DashError({super.key, required this.error, this.onRetry});
  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => DashCard(
    child: Row(
      children: [
        const Icon(Icons.error_outline_rounded, color: AppColors.danger),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            friendlyError(error),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (onRetry != null)
          IconButton(
            tooltip: 'Yeniden dene',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: onRetry,
          ),
      ],
    ),
  );
}

TextStyle dashTitleStyle() => const TextStyle(
  fontFamily: AppFonts.display,
  fontWeight: FontWeight.w700,
  fontSize: 20,
  height: 1.1,
);

TextStyle dashNumberStyle({double size = 28, Color? color}) => TextStyle(
  fontFamily: AppFonts.display,
  fontWeight: FontWeight.w800,
  fontSize: size,
  color: color ?? AppColors.cyan,
);

/// Dış bağlantı açar; başarısız olursa SnackBar gösterir.
Future<void> openExternal(BuildContext context, String url) async {
  final messenger = ScaffoldMessenger.of(context);
  var ok = false;
  try {
    ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {
    ok = false;
  }
  if (!ok) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Bağlantı açılamadı. Lütfen tekrar deneyin.'),
      ),
    );
  }
}
