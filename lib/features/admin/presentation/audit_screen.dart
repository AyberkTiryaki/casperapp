import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/error_messages.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../data/admin_repository.dart';
import '../domain/admin_models.dart';

const _pageSize = 50;

class AuditScreen extends ConsumerStatefulWidget {
  const AuditScreen({super.key});

  @override
  ConsumerState<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends ConsumerState<AuditScreen> {
  final _items = <AuditEntry>[];
  final _names = <String, String>{};
  String? _action;
  bool _loading = true;
  bool _hasMore = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      _items.clear();
      _hasMore = false;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(adminRepositoryProvider);
      final page = await repo.auditLog(
        offset: _items.length,
        limit: _pageSize,
        action: _action,
      );
      final missing = page
          .map((e) => e.actorId)
          .whereType<String>()
          .where((id) => !_names.containsKey(id));
      try {
        _names.addAll(await repo.names(missing));
      } catch (_) {
        // Ad çözümlenemezse kayıtlar yine gösterilir.
      }
      if (!mounted) return;
      setState(() {
        _items.addAll(page);
        _hasMore = page.length == _pageSize;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    Widget body;
    if (_items.isEmpty && _loading) {
      body = const LoadingView();
    } else if (_items.isEmpty && _error != null) {
      body = ErrorView(
        message: friendlyError(_error!),
        onRetry: () => _load(reset: true),
      );
    } else if (_items.isEmpty) {
      body = const EmptyView(
        title: 'Kayıt yok',
        icon: Icons.history_toggle_off_outlined,
      );
    } else {
      body = RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: _items.length + 1,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            if (i == _items.length) {
              if (_error != null) {
                return TextButton(
                  onPressed: _load,
                  child: Text(friendlyError(_error!)),
                );
              }
              if (_loading) return const LoadingView();
              return _hasMore
                  ? TextButton(
                      onPressed: _load,
                      child: const Text('Daha fazla yükle'),
                    )
                  : const SizedBox.shrink();
            }
            final e = _items[i];
            final actor = e.actorId == null
                ? 'Sistem'
                : (_names[e.actorId] ?? 'Bilinmeyen kullanıcı');
            final summary = summarizeAuditDetails(e.action, e.details);
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      auditActionLabel(e.action),
                      style: t.textTheme.titleMedium,
                    ),
                    Text(
                      '$actor  •  ${e.entity}'
                      '${e.entityId != null ? ' #${_short(e.entityId!)}' : ''}',
                    ),
                    if (summary.isNotEmpty) Text(summary),
                    Text(
                      '${formatDate(e.createdAt)} ${formatTime(e.createdAt)}',
                      style: t.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('İşlem geçmişi'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'İşleme göre filtrele',
            icon: Icon(_action == null ? Icons.filter_list : Icons.filter_alt),
            onSelected: (v) {
              _action = v.isEmpty ? null : v;
              _load(reset: true);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: '', child: Text('Tümü')),
              for (final a in auditActionLabels.entries)
                PopupMenuItem(value: a.key, child: Text(a.value)),
            ],
          ),
        ],
      ),
      body: body,
    );
  }
}

String _short(String id) => id.length > 8 ? id.substring(0, 8) : id;
