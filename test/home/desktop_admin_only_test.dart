import 'package:caspertrainingstudio/features/home/desktop_admin_only.dart';
import 'package:caspertrainingstudio/features/profile/profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('masaüstünde yalnızca yönetici girer', () {
    for (final p in [
      TargetPlatform.windows,
      TargetPlatform.macOS,
      TargetPlatform.linux,
    ]) {
      expect(
        desktopBlocksRole(UserRole.admin, platform: p, isWeb: false),
        isFalse,
      );
      expect(
        desktopBlocksRole(UserRole.trainer, platform: p, isWeb: false),
        isTrue,
      );
      expect(
        desktopBlocksRole(UserRole.member, platform: p, isWeb: false),
        isTrue,
      );
    }
  });

  test('telefonda ve web\'de herkes girer', () {
    for (final r in UserRole.values) {
      expect(
        desktopBlocksRole(r, platform: TargetPlatform.android, isWeb: false),
        isFalse,
      );
      expect(
        desktopBlocksRole(r, platform: TargetPlatform.iOS, isWeb: false),
        isFalse,
      );
      expect(
        desktopBlocksRole(r, platform: TargetPlatform.windows, isWeb: true),
        isFalse,
      );
    }
  });

  testWidgets('bilgi ekranı ve çıkış düğmesi', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: DesktopAdminOnlyView(
          signOut: OutlinedButton(
            onPressed: () => tapped = true,
            child: const Text('Çıkış yap'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Masaüstü uygulaması yönetici içindir'), findsOneWidget);
    await tester.tap(find.text('Çıkış yap'));
    expect(tapped, isTrue);
  });
}
