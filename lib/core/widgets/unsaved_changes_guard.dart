import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// [dirty] iken geri/çıkış girişimini engeller ve onay diyaloğu gösterir.
/// Kaydetme sonrası `Navigator.pop` doğrudan çağrıldığı için korumaya takılmaz.
class UnsavedChangesGuard extends StatelessWidget {
  const UnsavedChangesGuard({
    super.key,
    required this.dirty,
    required this.child,
  });

  final bool dirty;
  final Widget child;

  Future<void> _confirm(BuildContext context) async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        actionsOverflowDirection: VerticalDirection.up,
        actionsOverflowButtonSpacing: 12,
        title: const Text('Değişiklikler kaydedilmedi'),
        content: const Text(
          'Girdiğiniz bilgiler kaybolacak. Çıkmak istiyor musunuz?',
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Çık'),
          ),
        ],
      ),
    );
    if (leave == true && context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _confirm(context);
      },
      child: child,
    );
  }
}
