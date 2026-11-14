import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Rol kabuğunda seçili alt gezinme sekmesi (0 = Ana sayfa).
class HomeTabNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void set(int index) => state = index;
}

final homeTabProvider = NotifierProvider<HomeTabNotifier, int>(
  HomeTabNotifier.new,
);

/// Sekme indeksleri (tüm rollerde aynı sıra).
class HomeTabs {
  static const home = 0;
  static const second = 1;
  static const third = 2;
  static const profile = 3;
}
