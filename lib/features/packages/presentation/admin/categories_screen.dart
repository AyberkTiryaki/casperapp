import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/error_messages.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/empty_view.dart';
import '../../../../core/widgets/text_controller_scope.dart';
import '../../data/package_repository.dart';
import '../../domain/package_models.dart';
import '../../../../core/widgets/home_button.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  Future<void> _edit(BuildContext context, WidgetRef ref, Category? c) async {
    var active = c?.isActive ?? true;
    final formKey = GlobalKey<FormState>();
    // Kaydet: girilen ad döner; Vazgeç / dışarı dokunma: null
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => TextControllerScope(
        initialText: c?.name ?? '',
        builder: (ctx, name) => StatefulBuilder(
          builder: (ctx, setS) => AlertDialog(
            actionsOverflowDirection: VerticalDirection.up,
            actionsOverflowButtonSpacing: 12,
            title: Text(c == null ? 'Kategori ekle' : 'Kategori düzenle'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Ad'),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? 'Ad gerekli.' : null,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Aktif'),
                    value: active,
                    onChanged: (v) => setS(() => active = v),
                  ),
                ],
              ),
            ),
            actions: [
              OutlinedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Vazgeç'),
              ),
              FilledButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.of(ctx).pop(name.text.trim());
                  }
                },
                child: const Text('Kaydet'),
              ),
            ],
          ),
        ),
      ),
    );
    if (text == null || !context.mounted) return;
    final repo = ref.read(packageRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (c == null) {
        await repo.createCategory(name: text, isActive: active);
      } else {
        await repo.updateCategory(id: c.id, name: text, isActive: active);
      }
      ref.invalidate(categoriesProvider);
      messenger.showSnackBar(
        const SnackBar(content: Text('Kategori kaydedildi.')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(categoriesProvider);
    return Scaffold(
      appBar: AppBar(
        actions: const [HomeButton()],
        title: const Text('Kategoriler'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, ref, null),
        icon: const Icon(Icons.add),
        label: const Text('Kategori ekle'),
      ),
      body: AsyncValueView<List<Category>>(
        value: async,
        onRetry: () => ref.invalidate(categoriesProvider),
        data: (items) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(categoriesProvider),
          child: items.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 120),
                    EmptyView(
                      title: 'Kategori yok',
                      message: 'İlk kategoriyi eklemek için aşağıdaki düğmeyi kullanın.',
                      icon: Icons.category_outlined,
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final c = items[i];
                    return Card(
                      child: ListTile(
                        title: Text(c.name),
                        subtitle: Text(c.isActive ? 'Aktif' : 'Pasif'),
                        trailing: const Icon(Icons.edit_outlined),
                        onTap: () => _edit(context, ref, c),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
