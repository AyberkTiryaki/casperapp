import 'package:caspertrainingstudio/features/auth/session_timeout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 18, 12);

  test('kayıt yoksa oturum eskimiş sayılır', () {
    expect(isSessionExpired(null, now), isTrue);
  });

  test('süre içinde oturum açık kalır, aşılınca kapanır', () {
    expect(isSessionExpired(now.subtract(const Duration(minutes: 119)), now), isFalse);
    expect(isSessionExpired(now.subtract(sessionIdleTimeout), now), isFalse);
    expect(isSessionExpired(now.subtract(const Duration(minutes: 121)), now), isTrue);
  });
}
