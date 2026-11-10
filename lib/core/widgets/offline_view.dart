import 'package:flutter/material.dart';

import 'empty_view.dart';

class OfflineView extends StatelessWidget {
  const OfflineView({super.key, this.onRetry, this.extra});

  final VoidCallback? onRetry;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    return EmptyView(
      icon: Icons.wifi_off_rounded,
      title: 'Bağlantı yok',
      message: 'İnternet bağlantınızı kontrol edip tekrar deneyin.',
      action: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onRetry != null)
            FilledButton(onPressed: onRetry, child: const Text('Tekrar dene')),
          if (extra != null) ...[const SizedBox(height: 12), extra!],
        ],
      ),
    );
  }
}
