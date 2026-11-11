import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/error_messages.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/empty_view.dart';
import '../../data/package_repository.dart';
import '../../domain/package_models.dart';

class DefinitionsScreen extends ConsumerWidget {
  const DefinitionsScreen({super.key});

  void _open(BuildContext context, PackageDefinition? d) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DefinitionFormScreen(definition: d)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(definitionsProvider);
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Paket tanımları')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(context, null),
        icon: const Icon(Icons.add),
        label: const Text('Paket tanımı ekle'),
      ),
      body: AsyncValueView<List<PackageDefinition>>(
        value: async,
        onRetry: () => ref.invalidate(definitionsProvider),
        data: (items) {
          final groups = <String, List<PackageDefinition>>{};
          for (final d in items) {
            groups
                .putIfAbsent(d.categoryName ?? 'Kategorisiz', () => [])
                .add(d);
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(definitionsProvider),
            child: items.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 120),
                      EmptyView(
                        title: 'Paket tanımı yok',
                        icon: Icons.inventory_2_outlined,
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      for (final e in groups.entries) ...[
                        Text(e.key, style: t.textTheme.titleLarge),
                        const SizedBox(height: 8),
                        for (final d in e.value)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Card(
                              child: ListTile(
                                title: Text(d.name),
                                subtitle: Text(
                                  '${d.sessionCount} ders - ${d.validityDays} gün - ${formatTl(d.price)} - ${d.isActive ? 'Aktif' : 'Pasif'}',
                                ),
                                trailing: const Icon(Icons.edit_outlined),
                                onTap: () => _open(context, d),
                              ),
                            ),
                          ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
          );
        },
      ),
    );
  }
}

class DefinitionFormScreen extends ConsumerStatefulWidget {
  const DefinitionFormScreen({super.key, this.definition});
  final PackageDefinition? definition;

  @override
  ConsumerState<DefinitionFormScreen> createState() =>
      _DefinitionFormScreenState();
}

class _DefinitionFormScreenState extends ConsumerState<DefinitionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.definition?.name ?? '');
  late final _price = TextEditingController(
    text: widget.definition == null
        ? ''
        : widget.definition!.price.toString().replaceAll('.', ','),
  );
  String? _categoryId;
  late int _sessionCount = widget.definition?.sessionCount ?? 8;
  late bool _active = widget.definition?.isActive ?? true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.definition?.categoryId;
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final repo = ref.read(packageRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      final d = widget.definition;
      final price = parseDecimal(_price.text)!;
      final validity = validityDaysFor(_sessionCount);
      if (d == null) {
        await repo.createDefinition(
          categoryId: _categoryId!,
          name: _name.text.trim(),
          sessionCount: _sessionCount,
          validityDays: validity,
          price: price,
          isActive: _active,
        );
      } else {
        await repo.updateDefinition(
          id: d.id,
          categoryId: _categoryId!,
          name: _name.text.trim(),
          sessionCount: _sessionCount,
          validityDays: validity,
          price: price,
          isActive: _active,
        );
      }
      ref.invalidate(definitionsProvider);
      messenger.showSnackBar(
        const SnackBar(content: Text('Paket tanımı kaydedildi.')),
      );
      nav.pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cats = ref.watch(categoriesProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.definition == null
              ? 'Paket tanımı ekle'
              : 'Paket tanımı düzenle',
        ),
      ),
      body: AsyncValueView<List<Category>>(
        value: cats,
        onRetry: () => ref.invalidate(categoriesProvider),
        data: (categories) {
          final options = categories
              .where((c) => c.isActive || c.id == _categoryId)
              .toList();
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _categoryId,
                    decoration: const InputDecoration(labelText: 'Kategori'),
                    items: [
                      for (final c in options)
                        DropdownMenuItem(value: c.id, child: Text(c.name)),
                    ],
                    onChanged: (v) => setState(() => _categoryId = v),
                    validator: (v) => v == null ? 'Kategori seçin.' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Ad'),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? 'Ad gerekli.' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    initialValue: _sessionCount,
                    decoration: const InputDecoration(labelText: 'Ders sayısı'),
                    items: [
                      for (final n in allowedSessionCounts)
                        DropdownMenuItem(value: n, child: Text('$n ders')),
                    ],
                    onChanged: (v) =>
                        setState(() => _sessionCount = v ?? _sessionCount),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Geçerlilik: ${validityDaysFor(_sessionCount)} gün (ders sayısına göre belirlenir)',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _price,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Fiyat (TL)',
                      helperText: 'Fiyat değişikliği, daha önce atanmış paketleri etkilemez.',
                      helperMaxLines: 2,
                    ),
                    validator: (v) {
                      final p = parseDecimal(v);
                      if ((v ?? '').trim().isEmpty) return 'Fiyat gerekli.';
                      if (p == null || p < 0) return 'Geçerli bir fiyat girin.';
                      return null;
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Aktif'),
                    value: _active,
                    onChanged: (v) => setState(() => _active = v),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: const Text('Kaydet'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
