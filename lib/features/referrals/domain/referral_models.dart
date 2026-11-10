enum ReferralStatus {
  pending('Beklemede'),
  approved('Onaylandı'),
  rejected('Reddedildi');

  const ReferralStatus(this.label);
  final String label;

  static ReferralStatus fromString(String? v) => switch (v) {
        'approved' => ReferralStatus.approved,
        'rejected' => ReferralStatus.rejected,
        _ => ReferralStatus.pending,
      };

  String get apiValue => name;
}

DateTime? _dt(dynamic v) =>
    v == null ? null : DateTime.tryParse(v as String)?.toLocal();

class ReferralSummary {
  const ReferralSummary({
    required this.userId,
    required this.referralCode,
    required this.activeCount,
    required this.discountPercent,
    required this.approvedCount,
    required this.pendingCount,
    required this.wasReferred,
  });
  final String userId;
  final String? referralCode;
  final int activeCount;
  final int discountPercent;
  final int approvedCount;
  final int pendingCount;
  final bool wasReferred;

  factory ReferralSummary.fromJson(Map<String, dynamic> j) => ReferralSummary(
        userId: (j['user_id'] as String?) ?? '',
        referralCode: j['referral_code'] as String?,
        activeCount: (j['active_count'] as num?)?.toInt() ?? 0,
        discountPercent: (j['discount_percent'] as num?)?.toInt() ?? 0,
        approvedCount: (j['approved_count'] as num?)?.toInt() ?? 0,
        pendingCount: (j['pending_count'] as num?)?.toInt() ?? 0,
        wasReferred: (j['was_referred'] as bool?) ?? false,
      );
}

class MyReferral {
  const MyReferral({
    required this.referralId,
    required this.displayName,
    required this.status,
    required this.countsNow,
    this.createdAt,
  });
  final String referralId;
  final String displayName;
  final ReferralStatus status;
  final bool countsNow;
  final DateTime? createdAt;

  factory MyReferral.fromJson(Map<String, dynamic> j) => MyReferral(
        referralId: j['referral_id'].toString(),
        displayName: (j['display_name'] as String?) ?? '',
        status: ReferralStatus.fromString(j['status'] as String?),
        countsNow: (j['counts_now'] as bool?) ?? false,
        createdAt: _dt(j['created_at']),
      );
}

class AdminReferral {
  const AdminReferral({
    required this.id,
    required this.referrerId,
    required this.referrerName,
    required this.referrerCode,
    required this.referrerDiscountPercent,
    required this.referredId,
    required this.referredName,
    required this.referredHasActivePackage,
    required this.status,
    this.createdAt,
    this.decidedAt,
    this.decisionNote,
  });
  final String id;
  final String referrerId;
  final String referrerName;
  final String? referrerCode;
  final int referrerDiscountPercent;
  final String referredId;
  final String referredName;
  final bool referredHasActivePackage;
  final ReferralStatus status;
  final DateTime? createdAt;
  final DateTime? decidedAt;
  final String? decisionNote;

  factory AdminReferral.fromJson(Map<String, dynamic> j) => AdminReferral(
        id: j['id'].toString(),
        referrerId: (j['referrer_id'] as String?) ?? '',
        referrerName: (j['referrer_name'] as String?) ?? '',
        referrerCode: j['referrer_code'] as String?,
        referrerDiscountPercent:
            (j['referrer_discount_percent'] as num?)?.toInt() ?? 0,
        referredId: (j['referred_id'] as String?) ?? '',
        referredName: (j['referred_name'] as String?) ?? '',
        referredHasActivePackage:
            (j['referred_has_active_package'] as bool?) ?? false,
        status: ReferralStatus.fromString(j['status'] as String?),
        createdAt: _dt(j['created_at']),
        decidedAt: _dt(j['decided_at']),
        decisionNote: j['decision_note'] as String?,
      );
}

/// Kayıtta girilen referans kodu var ama kullanıcı hiçbir referansla eşleşmediyse uyarı gösterilir.
bool shouldShowInvalidReferralWarning({
  required String? signupCode,
  required bool wasReferred,
}) =>
    (signupCode ?? '').trim().isNotEmpty && !wasReferred;

const invalidReferralWarningText =
    'Kayıt sırasında girdiğiniz referans kodu geçerli değildi; referans oluşturulmadı. Düzeltme için stüdyo yönetimine başvurun.';
