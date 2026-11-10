import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/demo_data.dart';
import 'data/studio_store.dart';
import 'screens/home_shell.dart';

void main() {
  runApp(CasperApp(store: buildDemoStore()));
}

class CasperApp extends StatelessWidget {
  const CasperApp({super.key, required this.store});

  final StudioStore store;

  static const _seed = Color(0xFF5B4BDB);

  @override
  Widget build(BuildContext context) {
    return StoreScope(
      store: store,
      child: MaterialApp(
        title: 'Casper Training Studio',
        debugShowCheckedModeBanner: false,
        locale: const Locale('tr', 'TR'),
        supportedLocales: const [Locale('tr', 'TR'), Locale('en', 'US')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: _seed),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: _seed,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: const HomeShell(),
      ),
    );
  }
}
