import 'dart:async';

import 'package:caspertrainingstudio/features/schedule/domain/schedule_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('canMemberCancel: 2 saat sınırı dahil', () {
    final start = DateTime(2026, 1, 1, 12);
    expect(canMemberCancel(start, DateTime(2026, 1, 1, 10)), isTrue);
    expect(canMemberCancel(start, DateTime(2026, 1, 1, 10, 1)), isFalse);
  });

  test('BookingKeyHolder: ağ hatasında anahtar korunur, başarıda yenilenir', () async {
    var n = 0;
    final h = BookingKeyHolder(() => 'k${n++}');
    final keys = <String>[];
    await expectLater(
        h.run('c', (k) async {
          keys.add(k);
          throw TimeoutException('x');
        }),
        throwsA(anything));
    await h.run('c', (k) async => keys.add(k));
    await h.run('c', (k) async => keys.add(k));
    expect(keys, ['k0', 'k0', 'k1']);
  });
}

