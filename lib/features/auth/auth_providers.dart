import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase.dart';
import 'data/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(),
);

final authStateProvider = StreamProvider<AuthState>(
  (ref) => supabase.auth.onAuthStateChange,
);

/// Oturum açmış kullanıcının id'si; kullanıcı değişince yeniden hesaplanır.
final currentUserIdProvider = Provider<String?>((ref) {
  ref.watch(authStateProvider);
  return supabase.auth.currentUser?.id;
});

class PasswordRecoveryNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

/// `passwordRecovery` olayı geldiğinde true olur.
final passwordRecoveryProvider =
    NotifierProvider<PasswordRecoveryNotifier, bool>(
      PasswordRecoveryNotifier.new,
    );
