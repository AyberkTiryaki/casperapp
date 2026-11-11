import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import 'profile.dart';
import 'profile_repository.dart';

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(),
);

/// Giriş yapan kullanıcının profili; kullanıcı değişince yeniden çekilir.
final currentProfileProvider = FutureProvider<Profile?>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return null;
  return ref.watch(profileRepositoryProvider).fetchProfile(uid);
}, retry: (_, _) => null);
