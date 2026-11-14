import 'package:flutter/material.dart';

/// Başlık çubuğunda "Ana sayfa" düğmesi: tüm iç ekranları kapatıp rolün ana
/// sayfasına döner. Geri gidilecek ekran yoksa (zaten ana sayfa) görünmez.
///
/// Kaydedilmemiş veri içeren form ekranlarına (program düzenleme, ders açma)
/// bilerek konmaz; orada çıkış yalnızca geri tuşuyla yapılır.
class HomeButton extends StatelessWidget {
  const HomeButton({super.key});

  @override
  Widget build(BuildContext context) {
    final nav = Navigator.of(context);
    if (!nav.canPop()) return const SizedBox.shrink();
    return IconButton(
      tooltip: 'Ana sayfa',
      icon: const Icon(Icons.home_rounded),
      onPressed: () => nav.popUntil((route) => route.isFirst),
    );
  }
}
