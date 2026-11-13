import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/error_messages.dart';
import '../../auth/validators.dart';
import '../../profile/profile.dart';
import '../data/admin_repository.dart';

/// Karışması kolay karakterler (0/O, 1/l/I) olmadan 10 karakterlik geçici şifre.
String generateTempPassword([Random? rng]) {
  const chars = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKMNPQRSTUVWXYZ23456789';
  final r = rng ?? Random.secure();
  return List.generate(10, (_) => chars[r.nextInt(chars.length)]).join();
}

/// Yöneticinin yeni üye/eğitmen hesabı açtığı pencere.
/// Başarılı olursa yeni kullanıcının id'sini döndürür.
Future<String?> showCreateUserDialog(
  BuildContext context, {
  bool allowTrainer = true,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _CreateUserDialog(allowTrainer: allowTrainer),
  );
}

class _CreateUserDialog extends ConsumerStatefulWidget {
  const _CreateUserDialog({required this.allowTrainer});
  final bool allowTrainer;

  @override
  ConsumerState<_CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends ConsumerState<_CreateUserDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController(text: generateTempPassword());
  UserRole _role = UserRole.member;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final id = await ref
          .read(adminRepositoryProvider)
          .createUser(
            email: _email.text,
            password: _password.text,
            fullName: _name.text,
            role: _role,
          );
      if (!mounted) return;
      await _showCredentials();
      if (mounted) Navigator.of(context).pop(id);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showCredentials() {
    final text =
        'Casper Training Studio giriş bilgileriniz\nE-posta: ${_email.text.trim()}\nGeçici şifre: ${_password.text}\nİlk girişten sonra şifrenizi değiştirmenizi öneririz.';
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hesap açıldı'),
        content: SelectableText(text),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: text));
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Bilgiler kopyalandı.')),
                );
              }
            },
            child: const Text('Kopyala'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.allowTrainer ? 'Kullanıcı ekle' : 'Üye ekle'),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                enabled: !_busy,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Ad soyad'),
                validator: validateFullName,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                enabled: !_busy,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'E-posta'),
                validator: validateEmail,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                enabled: !_busy,
                decoration: InputDecoration(
                  labelText: 'Geçici şifre',
                  helperText:
                      'Kişiye iletin; giriş yaptıktan sonra değiştirebilir.',
                  suffixIcon: IconButton(
                    tooltip: 'Yeni şifre üret',
                    icon: const Icon(Icons.refresh),
                    onPressed: _busy
                        ? null
                        : () => setState(
                            () => _password.text = generateTempPassword(),
                          ),
                  ),
                ),
                validator: validateAdminPassword,
              ),
              if (widget.allowTrainer) ...[
                const SizedBox(height: 16),
                SegmentedButton<UserRole>(
                  segments: const [
                    ButtonSegment(value: UserRole.member, label: Text('Üye')),
                    ButtonSegment(
                      value: UserRole.trainer,
                      label: Text('Eğitmen'),
                    ),
                  ],
                  selected: {_role},
                  onSelectionChanged: _busy
                      ? null
                      : (s) => setState(() => _role = s.first),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Hesap aç'),
        ),
      ],
    );
  }
}
