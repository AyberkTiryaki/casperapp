import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/error_messages.dart';
import '../../../core/widgets/brand.dart';
import '../../protocols/presentation/price_list_screen.dart';
import '../auth_providers.dart';
import '../remembered_email.dart';
import '../session_timeout.dart';
import '../validators.dart';
import 'forgot_password_screen.dart';
import 'sign_up_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;
  String? _info;

  /// Hatırlanan e-posta: doluysa yalnızca e-posta gösterilir, şifre istenir.
  String? _remembered;
  bool _rememberMe = true;

  @override
  void initState() {
    super.initState();
    if (sessionExpiredNotice) {
      sessionExpiredNotice = false;
      _info = 'Güvenliğiniz için oturumunuz kapatıldı. Lütfen şifrenizi girin.';
    }
    loadRememberedEmail().then((email) {
      if (!mounted || email == null) return;
      setState(() {
        _remembered = email;
        _email.text = email;
      });
    });
  }

  void _useOtherAccount() {
    saveRememberedEmail(null);
    setState(() {
      _remembered = null;
      _email.clear();
      _password.clear();
      _info = null;
      _error = null;
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final email = _email.text.trim();
      await ref.read(authRepositoryProvider).signIn(email, _password.text);
      await saveRememberedEmail(_rememberMe ? email : null);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      body: BrandBackdrop(
        child: SafeArea(
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
                      const Center(child: BrandLogo(size: 136, glow: true)),
                      const SizedBox(height: 28),
                      const BrandWordmark(size: 48),
                      const SizedBox(height: 14),
                      Text(
                        'Güçlü başla. Hesabına giriş yap.',
                        style: t.textTheme.bodyMedium?.copyWith(
                          color: t.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      if (_info != null) ...[
                        Text(
                          _info!,
                          style: TextStyle(color: t.colorScheme.primary),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (_remembered != null)
                        _RememberedAccount(
                          email: _remembered!,
                          onChange: _loading ? null : _useOtherAccount,
                        )
                      else
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'E-posta',
                          ),
                          validator: validateEmail,
                        ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _password,
                        autofocus: _remembered != null,
                        obscureText: _obscure,
                        autofillHints: const [AutofillHints.password],
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'Şifre',
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) =>
                            (v ?? '').isEmpty ? 'Şifre gerekli.' : null,
                      ),
                      if (_remembered == null)
                        CheckboxListTile(
                          value: _rememberMe,
                          onChanged: _loading
                              ? null
                              : (v) => setState(() => _rememberMe = v ?? true),
                          title: const Text('Beni hatırla'),
                          subtitle: const Text(
                            'Yalnızca e-posta hatırlanır, şifre her girişte istenir.',
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: TextStyle(color: t.colorScheme.error),
                        ),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _loading ? null : _submit,
                        child: _loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Giriş yap'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _loading
                            ? null
                            : () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const ForgotPasswordScreen(),
                                ),
                              ),
                        child: const Text('Şifremi unuttum'),
                      ),
                      TextButton(
                        onPressed: _loading
                            ? null
                            : () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const SignUpScreen(),
                                ),
                              ),
                        child: const Text('Hesabın yok mu? Kayıt ol'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const PriceListScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.sell_outlined),
                        label: const Text('Paketleri keşfet'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RememberedAccount extends StatelessWidget {
  const _RememberedAccount({required this.email, required this.onChange});

  final String email;
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      decoration: BoxDecoration(
        color: t.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.account_circle_outlined, color: t.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              email,
              style: t.textTheme.bodyLarge,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(onPressed: onChange, child: const Text('Farklı hesap')),
        ],
      ),
    );
  }
}
