import 'package:caspertrainingstudio/features/packages/data/package_repository.dart';
import 'package:caspertrainingstudio/features/packages/domain/package_models.dart';
import 'package:caspertrainingstudio/features/schedule/data/schedule_repository.dart';
import 'package:caspertrainingstudio/features/schedule/domain/schedule_models.dart';
import 'package:caspertrainingstudio/features/schedule/presentation/shared/create_class_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoriesProvider.overrideWith(
            (ref) async => const [
              Category(
                id: 'c1',
                name: 'Özel Ders',
                isActive: true,
                classType: ClassType.individual,
              ),
              Category(
                id: 'c2',
                name: 'Atletik Performans Grup',
                isActive: true,
                classType: ClassType.group,
              ),
            ],
          ),
          trainersProvider.overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(home: CreateClassScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pick(WidgetTester tester, String name) async {
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(name).last);
    await tester.pumpAndSettle();
  }

  testWidgets('no type selector; info derived from category', (tester) async {
    await pump(tester);
    expect(find.byType(SegmentedButton<ClassType>), findsNothing);
    expect(find.textContaining('Bu kategoride dersler'), findsNothing);

    await pick(tester, 'Özel Ders');
    expect(
      find.text('Bu kategoride dersler: Özel ders (1 kişi)'),
      findsOneWidget,
    );

    await pick(tester, 'Atletik Performans Grup');
    expect(
      find.text('Bu kategoride dersler: Grup dersi (6 kişi)'),
      findsOneWidget,
    );
  });
}
