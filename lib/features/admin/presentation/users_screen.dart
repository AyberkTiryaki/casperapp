import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/error_messages.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_view.dart';
import '../../auth/auth_providers.dart';
import '../../profile/profile.dart';
import '../../wallet/presentation/shared/wallet_widgets.dart'
    show confirmDialog;
import '../data/admin_repository.dart';
import '../domain/admin_models.dart';
import 'create_user_dialog.dart';
import '../../../core/widgets/home_button.dart';

class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  AsyncValue<List<ManagedUser>> _result = const AsyncLoading();
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    final seq = ++_seq;
    setState(() => _result = const AsyncLoading());
    try {
      final r = await ref.read(adminRepositoryProvider).searchUsers(q);
      if (mounted && seq == _seq) setState(() => _result = AsyncData(r));
    } catch (e, st) {
      if (mounted && seq == _seq) setState(() => _result = AsyncError(e, st));
    }
  }

  Future<void> _run(Future<void> Function() action, String ok) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(ok)));
      await _search(_controller.text);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  Future<void> _changeRole(ManagedUser u) async {
    final picked = await showDialog<UserRole>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('${u.fullName}: yeni rol'),
        children: [
          for (final r in UserRole.values)
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(r),
              child: Text(r == u.role ? '${r.label} (mevcut)' : r.label),
            ),
        ],
      ),
    );
    if (picked == null || picked == u.role || !mounted) return;
    final go = await confirmDialog(
      context,
      'Rol değişikliği',
      '${u.fullName} kullanıcısının rolü "${u.role.label}" yerine "${picked.label}" olacak. Emin misiniz?',
    );
    if (!go || !mounted) return;
    await _run(
      () => ref.read(adminRepositoryProvider).setRole(u.id, picked),
      'Rol güncellendi.',
    );
  }

  Future<void> _toggleActive(ManagedUser u) async {
    final next = !u.isActive;
    final go = await confirmDialog(
      context,
      next ? 'Hesabı aktif yap' : 'Hesabı pasif yap',
      next
          ? '${u.fullName} tekrar aktif olacak.'
          : '${u.fullName} artık giriş yapıp işlem yapamayacak. Emin misiniz?',
    );
    if (!go || !mounted) return;
    await _run(
      () => ref.read(adminRepositoryProvider).setActive(u.id, next),
      next ? 'Hesap aktif edildi.' : 'Hesap pasif yapıldı.',
    );
  }

  Future<void> _resetPassword(ManagedUser u) async {
    final password = await showDialog<String>(
      context: context,
      builder: (_) => _ResetPasswordDialog(name: u.fullName),
    );
    if (password == null || !mounted) return;
    await _run(
      () => ref.read(adminRepositoryProvider).resetPassword(u.id, password),
      '${u.fullName} için yeni şifre kaydedildi. Şifreyi kendisine iletin.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserIdProvider);
    return Scaffold(
      appBar: AppBar(
        actions: const [HomeButton()],
        title: const Text('Kullanıcı ve rol yönetimi'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () async {
          final id = await showCreateUserDialog(context);
          if (id != null && mounted) await _search(_controller.text);
        },
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Kullanıcı ekle'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              onChanged: (v) {
                _debounce?.cancel();
                _debounce = Timer(
                  const Duration(milliseconds: 400),
                  () => _search(v),
                );
              },
              decoration: const InputDecoration(
                labelText: 'Ad veya e-posta ile ara',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: AsyncValueView<List<ManagedUser>>(
              value: _result,
              onRetry: () => _search(_controller.text),
              data: (items) => items.isEmpty
                  ? const EmptyView(
                      title: 'Kullanıcı bulunamadı',
                      icon: Icons.person_search,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final u = items[i];
                        final self = u.id == me;
                        return Card(
                          child: ListTile(
                            leading: Icon(
                              u.isActive
                                  ? Icons.person_outline
                                  : Icons.person_off_outlined,
                            ),
                            title: Text(
                              self ? '${u.fullName} (siz)' : u.fullName,
                            ),
                            isThreeLine: u.bodyInfo().isNotEmpty,
                            subtitle: Text(
                              [
                                if (u.email != null) u.email!,
                                [
                                  u.role.label,
                                  u.isActive ? 'Aktif' : 'Pasif',
                                  if (u.role == UserRole.member &&
                                      u.walletBalance != null)
                                    'Bakiye: ${formatTl(u.walletBalance!)}',
                                ].join('  •  '),
                                if (u.bodyInfo().isNotEmpty) u.bodyInfo(),
                              ].join('\n'),
                            ),
                            trailing: self
                                ? null
                                : PopupMenuButton<String>(
                                    onSelected: (v) => switch (v) {
                                      'role' => _changeRole(u),
                                      'password' => _resetPassword(u),
                                      _ => _toggleActive(u),
                                    },
                                    itemBuilder: (_) => [
                                      const PopupMenuItem(
                                        value: 'role',
                                        child: Text('Rolü değiştir'),
                                      ),
                                      // Yöneticiler şifresini e-postayla sıfırlar (Y-11)
                                      if (u.role != UserRole.admin)
                                        const PopupMenuItem(
                                          value: 'password',
                                          child: Text('Şifreyi sıfırla'),
                                        ),
                                      PopupMenuItem(
                                        value: 'active',
                                        child: Text(
                                          u.isActive
                                              ? 'Pasif yap'
                                              : 'Aktif yap',
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Yeni geçici şifreyi alır; Vazgeç'te null döner.
class _ResetPasswordDialog extends StatefulWidget {
  const _ResetPasswordDialog({required this.name});
  final String name;

  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (_form.currentState!.validate()) {
      Navigator.of(context).pop(_password.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      actionsOverflowDirection: VerticalDirection.up,
      actionsOverflowButtonSpacing: 12,
      title: const Text('Şifreyi sıfırla'),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.name} için yeni bir geçici şifre belirleyin. '
              'Açık oturumları kapanır; yeni şifreyle giriş yapıp Profil '
              'ekranından değiştirebilir.',
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _password,
              autofocus: true,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Yeni şifre',
                helperText: 'En az 4 karakter (ör. 1234)',
                suffixIcon: IconButton(
                  tooltip: _obscure ? 'Şifreyi göster' : 'Şifreyi gizle',
                  icon: Icon(
                    _obscure ? Icons.visibility_outlined : Icons.visibility_off,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) {
                final s = v ?? '';
                if (s.length < 4) {
                  return 'Şifre en az 4 karakter olmalı.';
                }
                if (s.length > 72) {
                  return 'Şifre en fazla 72 karakter olabilir.';
                }
                return null;
              },
              onFieldSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Vazgeç'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Kaydet')),
      ],
    );
  }
}
