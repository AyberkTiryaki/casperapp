import 'package:flutter/material.dart';

import 'empty_view.dart';

class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.message,
    this.onRetry,
    this.extra,
    this.title = 'Bir sorun oluştu',
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    return EmptyView(
      icon: Icons.error_outline,
      title: title,
      message: message,
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
