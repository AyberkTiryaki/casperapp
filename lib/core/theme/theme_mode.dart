import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'theme_mode';

/// Varsayılan görünüm: açık (ferah). Kullanıcı Profil > Görünüm'den değiştirir.
const defaultThemeMode = ThemeMode.light;

ThemeMode themeModeFromName(String? name) => switch (name) {
  'dark' => ThemeMode.dark,
  'system' => ThemeMode.system,
  'light' => ThemeMode.light,
  _ => defaultThemeMode,
};

/// Açılışta kayıtlı tercihi okur (ekran ilk karede doğru temayla çizilsin diye main'de çağrılır).
Future<ThemeMode> loadThemeMode() async {
  try {
    final p = await SharedPreferences.getInstance();
    return themeModeFromName(p.getString(_prefsKey));
  } catch (_) {
    return defaultThemeMode;
  }
}

class ThemeModeController extends Notifier<ThemeMode> {
  ThemeModeController([this._initial = defaultThemeMode]);
  final ThemeMode _initial;

  @override
  ThemeMode build() => _initial;

  Future<void> set(ThemeMode mode) async {
    state = mode;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_prefsKey, mode.name);
    } catch (_) {}
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);
