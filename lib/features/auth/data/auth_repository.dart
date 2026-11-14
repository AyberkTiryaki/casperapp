import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/legal.dart';
import '../../../core/config/supabase.dart';
import '../validators.dart';

class SignUpData {
  const SignUpData({
    required this.email,
    required this.password,
    required this.fullName,
    required this.birthDate,
    required this.heightCm,
    required this.weightKg,
    this.referralCode,
    this.healthConsent = false,
  });

  final String email;
  final String password;
  final String fullName;
  final DateTime birthDate;
  final int heightCm;
  final double weightKg;
  final String? referralCode;
  final bool healthConsent;
}

/// signUp `data` (kullanıcı metadata) haritası; referans kodu boşsa eklenmez.
Map<String, Object?> buildSignUpMetadata(SignUpData d) {
  final b = d.birthDate;
  final birth =
      '${b.year.toString().padLeft(4, '0')}-${b.month.toString().padLeft(2, '0')}-${b.day.toString().padLeft(2, '0')}';
  final ref = normalizeReferralCode(d.referralCode);
  return {
    'full_name': d.fullName,
    'birth_date': birth,
    'height_cm': d.heightCm,
    'weight_kg': d.weightKg,
    'kvkk_accepted': true,
    'kvkk_version': kvkkTextVersion,
    if (d.healthConsent) 'health_consent': true,
    if (d.healthConsent) 'health_version': healthConsentTextVersion,
    if (ref.isNotEmpty) 'referral_code': ref,
  };
}

class AuthRepository {
  GoTrueClient get _auth => supabase.auth;

  Future<void> signIn(String email, String password) =>
      _auth.signInWithPassword(email: email, password: password);

  Future<AuthResponse> signUp(SignUpData d) => _auth.signUp(
    email: d.email,
    password: d.password,
    emailRedirectTo: authRedirectUrl,
    data: buildSignUpMetadata(d),
  );

  Future<void> resendSignup(String email) =>
      _auth.resend(type: OtpType.signup, email: email);

  Future<void> sendPasswordReset(String email) =>
      _auth.resetPasswordForEmail(email, redirectTo: authRedirectUrl);

  Future<void> updatePassword(String newPassword) =>
      _auth.updateUser(UserAttributes(password: newPassword));

  Future<void> signOut() => _auth.signOut();
}
