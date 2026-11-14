import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/home/home_tab.dart';

/// Başlık çubuğunda "Ana sayfa" düğmesi: tüm iç ekranları kapatıp rolün ana
/// sayfasına (ilk sekme) döner. Geri gidilecek ekran yoksa (sekmelerde) görünmez.
///
/// Kaydedilmemiş veri içeren form ekranlarına (program düzenleme, ders açma)
/// bilerek konmaz; orada çıkış yalnızca geri tuşuyla yapılır.
class HomeButton extends ConsumerWidget {
  const HomeButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nav = Navigator.of(context);
    if (!nav.canPop()) return const SizedBox.shrink();
    return IconButton(
      tooltip: 'Ana sayfa',
      icon: const Icon(Icons.home_rounded),
      onPressed: () {
        nav.popUntil((route) => route.isFirst);
        ref.read(homeTabProvider.notifier).set(HomeTabs.home);
      },
    );
  }
}
