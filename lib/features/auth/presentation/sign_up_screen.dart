import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/legal.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/widgets/warning_box.dart';
import '../auth_providers.dart';
import '../data/auth_repository.dart';
import '../validators.dart';
import 'email_verification_notice_screen.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _password2 = TextEditingController();
  final _birth = TextEditingController();
  final _height = TextEditingController();
  final _weight = TextEditingController();
  final _referral = TextEditingController();
  DateTime? _birthDate;
  bool _kvkk = false;
  bool _health = false;
  bool _kvkkTouched = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [
      _name,
      _email,
      _password,
      _password2,
      _birth,
      _height,
      _weight,
      _referral,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(1920),
      lastDate: now.subtract(const Duration(days: 1)),
      helpText: 'Doğum tarihi',
      cancelText: 'Vazgeç',
      confirmText: 'Tamam',
    );
    if (picked != null) {
      setState(() {
        _birthDate = picked;
        _birth.text = _fmt(picked);
      });
    }
  }

  void _showText(String title, String version, String body) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          children: [
            Text(
              title,
              style: Theme.of(ctx).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Sürüm: $version',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Text(body),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Kapat'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _kvkkTouched = true);
    if (!_formKey.currentState!.validate() || !_kvkk) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final email = _email.text.trim();
    try {
      final res = await ref
          .read(authRepositoryProvider)
          .signUp(
            SignUpData(
              email: email,
              password: _password.text,
              fullName: _name.text.trim(),
              birthDate: _birthDate!,
              heightCm: parseHeight(_height.text)!,
              weightKg: parseWeight(_weight.text)!,
              referralCode: normalizeReferralCode(_referral.text),
              healthConsent: _health,
            ),
          );
      if (!mounted) return;
      if (res.session == null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => EmailVerificationNoticeScreen(email: email),
          ),
        );
      } else {
        // Oturum açıldı; AuthGate kökte yönlendirir.
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    const gap = SizedBox(height: 16);
    return Scaffold(
      appBar: AppBar(title: const Text('Kayıt ol')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Ad soyad'),
                      validator: validateFullName,
                    ),
                    gap,
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'E-posta'),
                      validator: validateEmail,
                    ),
                    gap,
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Şifre',
                        helperText: 'En az 8 karakter',
                      ),
                      validator: validatePassword,
                    ),
                    gap,
                    TextFormField(
                      controller: _password2,
                      obscureText: true,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Şifre tekrar',
                      ),
                      validator: (v) =>
                          validatePasswordConfirm(v, _password.text),
                    ),
                    gap,
                    TextFormField(
                      controller: _birth,
                      readOnly: true,
                      onTap: _pickDate,
                      decoration: const InputDecoration(
                        labelText: 'Doğum tarihi',
                        suffixIcon: Icon(Icons.calendar_today_outlined),
                      ),
                      validator: (_) => validateBirthDate(_birthDate),
                    ),
                    gap,
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _height,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Boy (cm)',
                            ),
                            validator: validateHeight,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _weight,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            textInputAction: TextInputAction.done,
                            decoration: const InputDecoration(
                              labelText: 'Kilo (kg)',
                            ),
                            validator: validateWeight,
                          ),
                        ),
                      ],
                    ),
                    gap,
                    TextFormField(
                      controller: _referral,
                      textCapitalization: TextCapitalization.characters,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Referans kodu (isteğe bağlı)',
                        helperText: 'Kod geçersizse kaydınız yine tamamlanır, ancak referans oluşmaz.',
                        helperMaxLines: 2,
                      ),
                      validator: validateReferralCode,
                    ),
                    gap,
                    CheckboxListTile(
                      value: _kvkk,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (v) => setState(() {
                        _kvkk = v ?? false;
                        _kvkkTouched = true;
                      }),
                      title: const Text(
                        'KVKK aydınlatma metnini okudum, kabul ediyorum.',
                      ),
                      subtitle: Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 32),
                          ),
                          onPressed: () => _showText(
                            'KVKK Aydınlatma Metni',
                            kvkkTextVersion,
                            kvkkText,
                          ),
                          child: const Text('Metni oku'),
                        ),
                      ),
                    ),
                    if (_kvkkTouched && !_kvkk)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Devam etmek için KVKK metnini kabul etmelisiniz.',
                          style: TextStyle(color: t.colorScheme.error),
                        ),
                      ),
                    CheckboxListTile(
                      value: _health,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (v) => setState(() => _health = v ?? false),
                      title: const Text(
                        'Sağlık verilerimin (vücut ölçümleri) işlenmesine açık rıza veriyorum (isteğe bağlı)',
                      ),
                      subtitle: Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 32),
                          ),
                          onPressed: () => _showText(
                            'Sağlık Verisi Açık Rıza Metni',
                            healthConsentTextVersion,
                            healthConsentText,
                          ),
                          child: const Text('Metni oku'),
                        ),
                      ),
                    ),
                    if (!_health)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: WarningBox(
                          text:
                              'Onay vermezseniz eğitmeniniz vücut ölçümlerinizi kaydedemez ve gelişiminizi ölçümlerle takip edemez. Üyeliğiniz ve ders rezervasyonlarınız etkilenmez. Onayı daha sonra Profil ekranından verebilirsiniz.',
                        ),
                      ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          _error!,
                          style: TextStyle(color: t.colorScheme.error),
                        ),
                      ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Kayıt ol'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
