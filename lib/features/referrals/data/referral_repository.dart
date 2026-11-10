import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/supabase.dart';
import '../domain/referral_models.dart';

abstract class ReferralRepository {
  /// [userId] null ise oturum sahibinin özeti.
  Future<ReferralSummary> summary({String? userId});
  Future<List<MyReferral>> myReferrals();

  /// [status] null ise tümü.
  Future<List<AdminReferral>> adminList({String? status});
  Future<void> decide(
      {required String referralId, required bool approve, String? note});
}

class SupabaseReferralRepository implements ReferralRepository {
  @override
  Future<ReferralSummary> summary({String? userId}) async {
    final r = await supabase
        .rpc('referral_summary', params: {'p_user_id': userId});
    final map = r is List ? r.first : r;
    return ReferralSummary.fromJson(Map<String, dynamic>.from(map as Map));
  }

  @override
  Future<List<MyReferral>> myReferrals() async {
    final r = await supabase.rpc('my_referrals');
    return (r as List)
        .map((e) => MyReferral.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  @override
  Future<List<AdminReferral>> adminList({String? status}) async {
    final r = await supabase
        .rpc('admin_list_referrals', params: {'p_status': status});
    return (r as List)
        .map((e) => AdminReferral.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  @override
  Future<void> decide(
      {required String referralId, required bool approve, String? note}) async {
    await supabase.rpc('admin_decide_referral', params: {
      'p_referral_id': referralId,
      'p_approve': approve,
      'p_note': (note == null || note.trim().isEmpty) ? null : note.trim(),
    });
  }
}

final referralRepositoryProvider =
    Provider<ReferralRepository>((ref) => SupabaseReferralRepository());

/// Kayıtta girilen referans kodu (kullanıcı metadata); testlerde override edilir.
final signupReferralCodeProvider = Provider<String?>(
    (ref) => supabase.auth.currentUser?.userMetadata?['referral_code'] as String?);

/// family argümanı null ise oturum sahibi.
final referralSummaryProvider =
    FutureProvider.family<ReferralSummary, String?>(
  (ref, userId) =>
      ref.watch(referralRepositoryProvider).summary(userId: userId),
  retry: (_, _) => null,
);

final myReferralsProvider = FutureProvider<List<MyReferral>>(
  (ref) => ref.watch(referralRepositoryProvider).myReferrals(),
  retry: (_, _) => null,
);

/// family argümanı: 'pending' | 'approved' | 'rejected' | null (tümü).
final adminReferralsProvider =
    FutureProvider.family<List<AdminReferral>, String?>(
  (ref, status) =>
      ref.watch(referralRepositoryProvider).adminList(status: status),
  retry: (_, _) => null,
);
