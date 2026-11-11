import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/utils/error_messages.dart';
import '../../core/widgets/async_value_view.dart' show isNetworkError;
import '../../core/widgets/empty_view.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/loading_view.dart';
import '../../core/widgets/offline_view.dart';
import '../admin/presentation/admin_home_screen.dart';
import '../auth/auth_providers.dart';
import '../auth/presentation/login_screen.dart';
import '../auth/presentation/update_password_screen.dart';
import '../member/presentation/member_home_screen.dart';
import '../profile/profile.dart';
import '../profile/profile_providers.dart';
import '../trainer/presentation/trainer_home_screen.dart';
import 'role_home_scaffold.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<AuthState>>(authStateProvider, (_, next) {
      final state = next.value;
      if (state == null) return;
      if (state.event == AuthChangeEvent.passwordRecovery) {
        ref.read(passwordRecoveryProvider.notifier).set(true);
        Navigator.of(context).popUntil((r) => r.isFirst);
      } else if (state.event == AuthChangeEvent.signedOut) {
        ref.read(passwordRecoveryProvider.notifier).set(false);
      }
    });

    final recovery = ref.watch(passwordRecoveryProvider);
    final uid = ref.watch(currentUserIdProvider);

    if (uid == null) return const LoginScreen();
    if (recovery) return const UpdatePasswordScreen();

    final profileAsync = ref.watch(currentProfileProvider);
    return profileAsync.when(
      loading: () => const Scaffold(body: LoadingView()),
      error: (e, _) => Scaffold(
        body: isNetworkError(e)
            ? OfflineView(
                onRetry: () => ref.invalidate(currentProfileProvider),
                extra: _LogoutButton(ref: ref),
              )
            : ErrorView(
                message: friendlyError(e),
                onRetry: () => ref.invalidate(currentProfileProvider),
                extra: _LogoutButton(ref: ref),
              ),
      ),
      data: (profile) {
        if (profile == null) {
          return Scaffold(
            body: ErrorView(
              title: 'Profil bulunamadı',
              message: 'Hesabınıza ait profil kaydı bulunamadı. Lütfen tekrar deneyin veya stüdyo yönetimiyle iletişime geçin.',
              onRetry: () => ref.invalidate(currentProfileProvider),
              extra: _LogoutButton(ref: ref),
            ),
          );
        }
        if (!profile.isActive) {
          return Scaffold(
            body: EmptyView(
              icon: Icons.block,
              title: 'Hesabınız pasif',
              message: 'Hesabınız şu anda pasif durumda. Lütfen stüdyo yönetimiyle iletişime geçin.',
              action: _LogoutButton(ref: ref),
            ),
          );
        }
        return switch (profile.role) {
          UserRole.member => MemberHomeScreen(profile: profile),
          UserRole.trainer => TrainerHomeScreen(profile: profile),
          UserRole.admin => AdminHomeScreen(profile: profile),
        };
      },
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: () => confirmAndSignOut(context, ref),
    child: const Text('Çıkış yap'),
  );
}
