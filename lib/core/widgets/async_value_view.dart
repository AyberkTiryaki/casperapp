import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/error_messages.dart';
import 'error_view.dart';
import 'loading_view.dart';
import 'offline_view.dart';

/// Ağ hatası mı? dart:io'ya bağlanmamak için tür adı kontrolü de yapılır (web uyumu).
bool isNetworkError(Object e) {
  if (e is TimeoutException || e is AuthRetryableFetchException) return true;
  final t = e.runtimeType.toString();
  return t == 'SocketException' ||
      t == 'ClientException' ||
      t == '_ClientSocketException' ||
      t == 'HandshakeException';
}

class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    super.key,
    required this.value,
    required this.data,
    this.onRetry,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () => const LoadingView(),
      error: (e, _) => isNetworkError(e)
          ? OfflineView(onRetry: onRetry)
          : ErrorView(message: friendlyError(e), onRetry: onRetry),
      data: data,
    );
  }
}
