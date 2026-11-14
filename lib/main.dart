import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/env.dart';
import 'core/config/supabase.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/async_value_view.dart';
import 'features/home/auth_gate.dart';

const _locale = Locale('tr', 'TR');
const _delegates = <LocalizationsDelegate<dynamic>>[
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!Env.isConfigured) {
    runApp(const _MissingConfigApp());
    return;
  }
  await initSupabase();
  runApp(const ProviderScope(retry: _retry, child: CasperApp()));
}

/// Riverpod'un otomatik yeniden deneme kuralı. Varsayılan 10 deneme, sunucu hatasında
/// bile ekranda uzun süre yükleniyor çubuğu bırakıyordu. Yalnızca bağlantı hatalarını
/// en fazla 3 kez yeniden dene; sunucu ve yetki hatalarını hemen göster.
Duration? _retry(int retryCount, Object error) {
  if (retryCount >= 3 || !isNetworkError(error)) return null;
  return Duration(milliseconds: 500 * (1 << retryCount));
}

class CasperApp extends StatelessWidget {
  const CasperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Casper Training Studio',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const _AppScrollBehavior(),
      locale: _locale,
      supportedLocales: const [_locale],
      localizationsDelegates: _delegates,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // Marka kimliği koyu: gece mavisi zemin + elektrik mavisi
      themeMode: ThemeMode.dark,
      home: const AuthGate(),
    );
  }
}

class _MissingConfigApp extends StatelessWidget {
  const _MissingConfigApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Casper Training Studio',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const _AppScrollBehavior(),
      locale: _locale,
      supportedLocales: const [_locale],
      localizationsDelegates: _delegates,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // Marka kimliği koyu: gece mavisi zemin + elektrik mavisi
      themeMode: ThemeMode.dark,
      home: const Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.settings_suggest_outlined, size: 56),
                  SizedBox(height: 16),
                  Text(
                    'Yapılandırma eksik',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Supabase bilgileri bulunamadı. Uygulamayı şu komutla çalıştırın:',
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 12),
                  SelectableText(
                    'flutter run --dart-define-from-file=env/dev.json',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Masaüstünde (Windows) yatay listeler fareyle de sürüklenebilsin.
/// Telefonda dokunmatik kaydırma zaten varsayılan olarak açıktır.
class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}
