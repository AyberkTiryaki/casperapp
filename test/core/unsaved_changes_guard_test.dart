import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:caspertrainingstudio/core/widgets/unsaved_changes_guard.dart';

Future<void> _open(WidgetTester tester, {required bool dirty}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => UnsavedChangesGuard(
                  dirty: dirty,
                  child: const Scaffold(body: Text('FORM')),
                ),
              ),
            ),
            child: const Text('AC'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('AC'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('dirty: dialog gosterilir, Vazgec ekranda tutar', (t) async {
    await _open(t, dirty: true);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.text('Değişiklikler kaydedilmedi'), findsOneWidget);
    await t.tap(find.text('Vazgeç'));
    await t.pumpAndSettle();
    expect(find.text('FORM'), findsOneWidget);
    expect(find.text('Değişiklikler kaydedilmedi'), findsNothing);
  });

  testWidgets('dirty: Cik ekrani kapatir', (t) async {
    await _open(t, dirty: true);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    await t.tap(find.text('Çık'));
    await t.pumpAndSettle();
    expect(find.text('FORM'), findsNothing);
    expect(find.text('AC'), findsOneWidget);
  });

  testWidgets('clean: diyalog olmadan kapanir', (t) async {
    await _open(t, dirty: false);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.text('Değişiklikler kaydedilmedi'), findsNothing);
    expect(find.text('FORM'), findsNothing);
  });
}
