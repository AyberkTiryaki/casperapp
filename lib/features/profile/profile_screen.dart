import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/supabase.dart';
import '../../core/utils/error_messages.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/async_value_view.dart';
import '../../core/widgets/text_controller_scope.dart';
import '../auth/validators.dart';
import 'deletion_request.dart';
import 'profile.dart';
import 'profile_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Profilim')),
      body: SafeArea(
        child: AsyncValueView<Profile?>(
          value: profile,
          onRetry: () => ref.invalidate(currentProfileProvider),
          data: (p) => p == null
              ? const Center(child: Text('Profil bulunamadı.'))
              : _ProfileForm(profile: p),
        ),
      ),
    );
  }
}

class _ProfileForm extends ConsumerStatefulWidget {
  const _ProfileForm({required this.profile});
  final Profile profile;

  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.profile.fullName);
  late final _height = TextEditingController(
    text: widget.profile.heightCm?.toString() ?? '',
  );
  late final _weight = TextEditingController(
    text: widget.profile.weightKg?.toString().replaceAll('.', ',') ?? '',
  );
  late DateTime? _birth = widget.profile.birthDate;
  bool _saving = false;
  String? _birthError;

  @override
  void dispose() {
    _name.dispose();
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _pickBirth() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _birth ?? DateTime(now.year - 25),
      firstDate: DateTime(1901),
      lastDate: now,
    );
    if (d != null) setState(() => _birth = d);
  }

  Future<void> _save() async {
    final birthErr = validateOptionalBirthDate(_birth);
    setState(() => _birthError = birthErr);
    if (!_formKey.currentState!.validate() || birthErr != null) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(profileRepositoryProvider)
          .updateProfile(
            widget.profile.id,
            fullName: _name.text,
            birthDate: _birth,
            heightCm: parseHeight(_height.text),
            weightKg: parseWeight(_weight.text),
          );
      ref.invalidate(currentProfileProvider);
      if (mounted) _snack('Profiliniz güncellendi.');
    } catch (e) {
      if (mounted) _snack(friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _optional(String? v, String? Function(String?) validator) =>
      (v ?? '').trim().isEmpty ? null : validator(v);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final email = supabase.auth.currentUser?.email ?? '-';
    final consent = ref.watch(kvkkConsentProvider);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                initialValue: email,
                readOnly: true,
                decoration: const InputDecoration(labelText: 'E-posta'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Ad soyad'),
                validator: validateFullName,
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickBirth,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Doğum tarihi',
                    errorText: _birthError,
                    suffixIcon: const Icon(Icons.calendar_today_outlined),
                  ),
                  child: Text(
                    _birth == null ? 'Seçilmedi' : formatDate(_birth!),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _height,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Boy (cm)'),
                validator: (v) => _optional(v, validateHeight),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _weight,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Güncel kilo (kg)',
                  helperText: 'Yalnızca güncel kilonuz saklanır.',
                ),
                validator: (v) => _optional(v, validateWeight),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Kaydet'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        consent.maybeWhen(
          data: (c) => c == null
              ? const SizedBox.shrink()
              : Text(
                  'KVKK onayı: ${formatDate(c.acceptedAt)} (metin sürümü ${c.version})',
                  style: t.textTheme.bodySmall,
                ),
          orElse: () => const SizedBox.shrink(),
        ),
        const Divider(height: 48),
        const _DeletionSection(),
      ],
    );
  }
}

class _DeletionSection extends ConsumerStatefulWidget {
  const _DeletionSection();

  @override
  ConsumerState<_DeletionSection> createState() => _DeletionSectionState();
}

class _DeletionSectionState extends ConsumerState<_DeletionSection> {
  bool _busy = false;

  Future<void> _request() async {
    // Talep gönder: not metni döner; Vazgeç: null
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => TextControllerScope(
        builder: (ctx, noteCtrl) => AlertDialog(
          title: const Text('Hesabımı sil'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Talebiniz stüdyo yöneticisine iletilir. Onaylandığında kişisel '
                'verileriniz KVKK kapsamında silinir veya anonimleştirilir. '
                'Mali ve yasal olarak saklanması gereken kayıtlar muhafaza edilebilir.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                maxLines: 3,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Not (isteğe bağlı)',
                ),
              ),
            ],
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(noteCtrl.text),
              child: const Text('Talep gönder'),
            ),
          ],
        ),
      ),
    );
    if (note == null) return;
    final uid = ref.read(currentProfileProvider).value?.id;
    if (uid == null) return;
    setState(() => _busy = true);
    var msg = 'Hesap silme talebiniz iletildi.';
    try {
      await ref
          .read(profileRepositoryProvider)
          .requestDeletion(uid, note: note);
    } catch (e) {
      msg = isPendingDuplicate(e)
          ? 'Zaten bekleyen bir silme talebiniz var.'
          : friendlyError(e);
    }
    ref.invalidate(pendingDeletionProvider);
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final pending = ref.watch(pendingDeletionProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Hesabımı sil', style: t.textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text(
          'Silme talebiniz stüdyo yöneticisine iletilir. Kişisel verileriniz '
          'KVKK kapsamında silinir veya anonimleştirilir; mali ve yasal '
          'kayıtlar gerektiği süre boyunca saklanabilir.',
        ),
        const SizedBox(height: 12),
        pending.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text(friendlyError(e)),
          data: (r) => r != null
              ? Card(
                  child: ListTile(
                    leading: const Icon(Icons.hourglass_top),
                    title: const Text('Silme talebiniz inceleniyor'),
                    subtitle: Text(
                      'Talep tarihi: ${formatDate(r.requestedAt)}',
                    ),
                  ),
                )
              : OutlinedButton.icon(
                  onPressed: _busy ? null : _request,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Hesabımı sil'),
                ),
        ),
      ],
    );
  }
}
