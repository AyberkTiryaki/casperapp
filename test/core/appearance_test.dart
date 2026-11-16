import 'package:caspertrainingstudio/core/theme/app_colors.dart';
import 'package:caspertrainingstudio/core/theme/app_theme.dart';
import 'package:caspertrainingstudio/core/theme/theme_mode.dart';
import 'package:caspertrainingstudio/features/home/role_home_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('saate göre karşılama', () {
    expect(greetingFor(DateTime(2026, 11, 16, 7)), 'Günaydın');
    expect(greetingFor(DateTime(2026, 11, 16, 13)), 'İyi günler');
    expect(greetingFor(DateTime(2026, 11, 16, 19)), 'İyi akşamlar');
    expect(greetingFor(DateTime(2026, 11, 16, 23)), 'İyi geceler');
    expect(greetingFor(DateTime(2026, 11, 16, 3)), 'İyi geceler');
  });

  test('tema adı çözümleme, varsayılan açık', () {
    expect(themeModeFromName(null), ThemeMode.light);
    expect(themeModeFromName('dark'), ThemeMode.dark);
    expect(themeModeFromName('system'), ThemeMode.system);
    expect(themeModeFromName('saçma'), ThemeMode.light);
  });

  test('tema tercihi kaydedilir ve geri okunur', () async {
    SharedPreferences.setMockInitialValues({});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(themeModeProvider), ThemeMode.light);
    await c.read(themeModeProvider.notifier).set(ThemeMode.dark);
    expect(c.read(themeModeProvider), ThemeMode.dark);
    expect(await loadThemeMode(), ThemeMode.dark);
  });

  testWidgets('palet temaya göre değişir', (tester) async {
    late AppPalette light;
    late AppPalette dark;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (c) {
            light = c.palette;
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Builder(
          builder: (c) {
            dark = c.palette;
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpAndSettle(); // tema geçiş animasyonu
    expect(light.card, AppColors.surfaceLight);
    expect(light.cardShadow, isNotNull);
    expect(dark.card, AppColors.nightCard);
    expect(dark.cardShadow, isNull);
  });
}
