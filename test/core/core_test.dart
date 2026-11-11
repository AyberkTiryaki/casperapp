import 'package:caspertrainingstudio/core/utils/error_messages.dart';
import 'package:caspertrainingstudio/features/auth/validators.dart';
import 'package:caspertrainingstudio/features/profile/profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('UserRole.fromString', () {
    expect(UserRole.fromString('admin'), UserRole.admin);
    expect(UserRole.fromString('trainer'), UserRole.trainer);
    expect(UserRole.fromString('member'), UserRole.member);
    expect(UserRole.fromString('x'), UserRole.member);
    expect(UserRole.fromString(null), UserRole.member);
  });

  test('Profile.fromJson', () {
    final p = Profile.fromJson({
      'id': 'u1',
      'full_name': 'Ayşe Yılmaz',
      'birth_date': '1990-05-17',
      'height_cm': 170,
      'weight_kg': 62.5,
      'role': 'trainer',
      'is_active': false,
    });
    expect(p.fullName, 'Ayşe Yılmaz');
    expect(p.birthDate, DateTime(1990, 5, 17));
    expect(p.weightKg, 62.5);
    expect(p.role, UserRole.trainer);
    expect(p.isActive, false);
    final q = Profile.fromJson({'id': 'u2', 'role': 'weird'});
    expect(q.role, UserRole.member);
    expect(q.fullName, '');
  });

  test('validators', () {
    expect(validateEmail('a@b.co'), isNull);
    expect(validateEmail('abc'), isNotNull);
    expect(validatePassword('1234567'), isNotNull);
    expect(validatePassword('12345678'), isNull);
    expect(validatePasswordConfirm('x', 'y'), isNotNull);
    expect(validatePasswordConfirm('y', 'y'), isNull);
    final now = DateTime(2026, 11, 10);
    expect(validateBirthDate(null), isNotNull);
    expect(validateBirthDate(DateTime(2026, 11, 10), now: now), isNotNull);
    expect(validateBirthDate(DateTime(2000, 1, 1), now: now), isNull);
    expect(validateHeight('99'), isNotNull);
    expect(validateHeight('251'), isNotNull);
    expect(validateHeight('175'), isNull);
    expect(validateHeight('17.5'), isNotNull);
    expect(validateWeight('29'), isNotNull);
    expect(validateWeight('301'), isNotNull);
    expect(validateWeight('70,5'), isNull);
    expect(parseWeight('70,5'), 70.5);
    expect(validateWeight('70.5'), isNull);
    expect(validateWeight('abc'), isNotNull);
  });

  test('friendlyError', () {
    expect(
      friendlyError(
        const AuthException(
          'Invalid login credentials',
          code: 'invalid_credentials',
        ),
      ),
      'E-posta veya şifre hatalı.',
    );
    expect(
      friendlyError(const AuthException('x', code: 'email_not_confirmed')),
      contains('doğrulanmamış'),
    );
    expect(
      friendlyError(const AuthException('User already registered')),
      contains('zaten'),
    );
    expect(
      friendlyError(const AuthException('x', code: 'weak_password')),
      contains('zayıf'),
    );
    expect(
      friendlyError(const AuthException('x', code: 'over_request_rate_limit')),
      contains('Çok fazla'),
    );
    expect(
      friendlyError(AuthRetryableFetchException(message: 'x')),
      contains('İnternet'),
    );
    expect(
      friendlyError(const PostgrestException(message: 'x')),
      contains('Sunucu'),
    );
    expect(friendlyError(Exception('?')), contains('Beklenmeyen'));
  });
}
