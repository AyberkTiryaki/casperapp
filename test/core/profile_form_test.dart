import 'package:caspertrainingstudio/features/auth/validators.dart';
import 'package:caspertrainingstudio/features/notifications/notifications_screen.dart';
import 'package:caspertrainingstudio/features/profile/deletion_request.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profil alan doğrulamaları', () {
    expect(validateFullName('Al'), isNotNull);
    expect(validateHeight('99'), isNotNull);
    expect(validateHeight('170'), isNull);
    expect(validateWeight('62,5'), isNull);
    expect(validateWeight('10'), isNotNull);
  });

  test('isteğe bağlı doğum tarihi', () {
    final now = DateTime(2026, 11, 12);
    expect(validateOptionalBirthDate(null, now: now), isNull);
    expect(validateOptionalBirthDate(DateTime(2027), now: now), isNotNull);
    expect(validateOptionalBirthDate(DateTime(1990), now: now), isNull);
  });

  test('silme durumu ve bildirim ikonu', () {
    expect(DeletionStatus.fromString('processed'), DeletionStatus.processed);
    expect(DeletionStatus.fromString('rejected'), DeletionStatus.rejected);
    expect(DeletionStatus.fromString(null), DeletionStatus.pending);
    expect(notificationIcon('xyz'), Icons.notifications_outlined);
  });
}
