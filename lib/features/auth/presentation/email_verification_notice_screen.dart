import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/error_messages.dart';
import '../auth_providers.dart';

class EmailVerificationNoticeScreen extends ConsumerStatefulWidget {
  const EmailVerificationNoticeScreen({super.key, required this.email});

  final String email;

  @override
  ConsumerState<EmailVerificationNoticeScreen> createState() =>
      _EmailVerificationNoticeScreenState();
}

class _EmailVerificationNoticeScreenState
    extends ConsumerState<EmailVerificationNoticeScreen> {
  bool _sending = false;

  Future<void> _resend() async {
    setState(() => _sending = true);
    String msg;
    try {
      await ref.read(authRepositoryProvider).resendSignup(widget.email);
      msg = 'Doğrulama e-postası tekrar gönderildi.';
    } catch (e) {
      msg = friendlyError(e);
    }
    if (!mounted) return;
    setState(() => _sending = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.mark_email_unread_outlined,
                    size: 64,
                    color: t.colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'E-postanızı doğrulayın',
                    style: t.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${widget.email} adresine bir doğrulama bağlantısı gönderdik. Gelen kutunuzu (ve gerekirse spam klasörünü) kontrol edip bağlantıya dokunun.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: _sending ? null : _resend,
                    child: const Text('Tekrar gönder'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () =>
                        Navigator.of(context).popUntil((r) => r.isFirst),
                    child: const Text('Giriş ekranına dön'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
