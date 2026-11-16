import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/error_messages.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/home_button.dart';
import '../data/protocol_repository.dart';
import '../domain/protocol_models.dart';

/// Yönetici: kurum protokolleri (sendika, dernek vb.) listesi ve düzenleme.
class AdminProtocolsScreen extends ConsumerWidget {
  const AdminProtocolsScreen({super.key});

  Future<void> _edit(BuildContext context, WidgetRef ref, Protocol? p) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => ProtocolFormDialog(protocol: p),
    );
    if (saved == true && context.mounted) {
      ref.invalidate(protocolsProvider);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Protokol kaydedildi.')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(protocolsProvider);
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(
        actions: const [HomeButton()],
        title: const Text('Protokoller'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => _edit(context, ref, null),
        icon: const Icon(Icons.add),
        label: const Text('Protokol ekle'),
      ),
      body: AsyncValueView<List<Protocol>>(
        value: async,
        onRetry: () => ref.invalidate(protocolsProvider),
        data: (items) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(protocolsProvider),
          child: items.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 120),
                    EmptyView(
                      title: 'Protokol yok',
                      message: 'Sendika veya kurumlarla yapılan indirim anlaşmalarını buraya ekleyin.',
                      icon: Icons.handshake_outlined,
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final p = items[i];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.handshake_outlined),
                        title: Text(p.name),
                        subtitle: Text(protocolStatusText(p, now)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Chip(
                              label: Text('%${p.discountPercent}'),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.edit_outlined),
                          ],
                        ),
                        onTap: () => _edit(context, ref, p),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

/// "Aktif · 31.12.2026'ya kadar" / "Süresi doldu" / "Pasif".
String protocolStatusText(Protocol p, DateTime now) {
  if (!p.isActive) return 'Pasif';
  if (!p.isValidOn(now)) return 'Süresi doldu (${formatDate(p.validUntil!)})';
  final until = p.validUntil == null
      ? 'Süresiz'
      : '${formatDate(p.validUntil!)} tarihine kadar';
  return 'Aktif · $until';
}

class ProtocolFormDialog extends ConsumerStatefulWidget {
  const ProtocolFormDialog({super.key, this.protocol});
  final Protocol? protocol;

  @override
  ConsumerState<ProtocolFormDialog> createState() => _ProtocolFormDialogState();
}

class _ProtocolFormDialogState extends ConsumerState<ProtocolFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.protocol?.name ?? '');
  late final _percent = TextEditingController(
    text: widget.protocol?.discountPercent.toString() ?? '',
  );
  late final _note = TextEditingController(text: widget.protocol?.note ?? '');
  late bool _active = widget.protocol?.isActive ?? true;
  late DateTime? _validUntil = widget.protocol?.validUntil;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _percent.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _validUntil ?? DateTime(now.year, 12, 31),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
      helpText: 'Son geçerlilik günü',
    );
    if (d != null) setState(() => _validUntil = d);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(protocolRepositoryProvider)
          .save(
            id: widget.protocol?.id,
            name: _name.text,
            discountPercent: int.parse(_percent.text.trim()),
            isActive: _active,
            validUntil: _validUntil,
            note: _note.text,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = friendlyError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      actionsOverflowDirection: VerticalDirection.up,
      actionsOverflowButtonSpacing: 12,
      title: Text(
        widget.protocol == null ? 'Protokol ekle' : 'Protokol düzenle',
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _name,
                maxLength: 80,
                decoration: const InputDecoration(
                  labelText: 'Kurum adı',
                  hintText: 'Örn. X Sendikası',
                ),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Ad gerekli.' : null,
              ),
              TextFormField(
                controller: _percent,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'İndirim oranı (%)',
                  helperText: 'Paket fiyatına uygulanır (1-50).',
                ),
                validator: validateProtocolPercent,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _validUntil == null
                          ? 'Son geçerlilik: süresiz'
                          : 'Son geçerlilik: ${formatDate(_validUntil!)}',
                    ),
                  ),
                  TextButton(
                    onPressed: _pickDate,
                    child: const Text('Tarih seç'),
                  ),
                  if (_validUntil != null)
                    IconButton(
                      tooltip: 'Süresiz yap',
                      onPressed: () => setState(() => _validUntil = null),
                      icon: const Icon(Icons.close),
                    ),
                ],
              ),
              TextFormField(
                controller: _note,
                maxLength: 300,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Not (isteğe bağlı)',
                  helperText: 'Yalnızca yöneticiler görür.',
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Aktif'),
                subtitle: const Text(
                  'Pasif protokol yeni paketlerde uygulanmaz ve fiyat listesinde görünmez.',
                ),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('Kaydet'),
        ),
      ],
    );
  }
}

String? validateProtocolPercent(String? v) {
  final n = int.tryParse((v ?? '').trim());
  if (n == null || n < 1 || n > maxTotalDiscount) {
    return 'Oran 1 ile $maxTotalDiscount arasında bir tam sayı olmalı.';
  }
  return null;
}

/// Yönetici: üyeyi bir protokole bağlar veya bağlantıyı kaldırır.
Future<void> runSetMemberProtocolFlow(
  BuildContext context,
  WidgetRef ref, {
  required String memberId,
  required String memberName,
  Protocol? current,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  List<Protocol> all;
  try {
    all = await ref.read(protocolsProvider.future);
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    return;
  }
  if (!context.mounted) return;
  final now = DateTime.now();
  final valid = all.where((p) => p.isValidOn(now)).toList();
  if (valid.isEmpty && current == null) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Geçerli protokol yok. Önce Protokoller ekranından ekleyin.',
        ),
      ),
    );
    return;
  }
  // Seçim: protokol id'si; '' = bağlantıyı kaldır; null = vazgeç
  final picked = await showDialog<String>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text('$memberName için protokol'),
      children: [
        for (final p in valid)
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop(p.id),
            child: Row(
              children: [
                Icon(
                  p.id == current?.id
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(child: Text('${p.name} (%${p.discountPercent})')),
              ],
            ),
          ),
        if (current != null)
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop(''),
            child: const Text('Protokolü kaldır'),
          ),
      ],
    ),
  );
  if (picked == null || picked == (current?.id ?? '')) return;
  try {
    await ref
        .read(protocolRepositoryProvider)
        .setMemberProtocol(memberId, picked.isEmpty ? null : picked);
    ref.invalidate(memberProtocolProvider(memberId));
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          picked.isEmpty ? 'Protokol kaldırıldı.' : 'Üye protokole bağlandı.',
        ),
      ),
    );
  } catch (e) {
    ref.invalidate(protocolsProvider);
    messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
  }
}
